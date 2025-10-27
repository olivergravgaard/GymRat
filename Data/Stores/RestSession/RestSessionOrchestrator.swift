import Foundation

public struct RestTick: Sendable, Equatable {
    public let setId: UUID
    public let total: Int
    public let remaining: Int
    public var progress: Double {
        guard total > 0 else { return 1 }
        return 1 - (Double(remaining) / Double(total))
    }
    public let isFinished: Bool
}

public struct RestCompletion: Sendable, Equatable {
    public let setId: UUID
    public let total: Int
    public let startedAt: Date
    public let endedAt: Date
}

public actor RestSessionOrchestrator {

    // Kaldes på MainActor når en pause udløber naturligt.
    public typealias OnFinish = @MainActor (_ completion: RestCompletion) -> Void

    private let onFinish: OnFinish?

    public init(onFinish: OnFinish? = nil) {
        self.onFinish = onFinish
    }

    private struct Active {
        let setId: UUID
        let total: Int
        let startedAt: Date
        var endsAt: Date { startedAt.addingTimeInterval(TimeInterval(total)) }
    }

    private var active: Active?
    private var tickingTask: Task<Void, Never>?
    // continuations[setId][token] = continuation
    private var continuations: [UUID: [UUID: AsyncStream<RestTick>.Continuation]] = [:]

    // MARK: Subscribe
    public func subscribe(setId: UUID) -> AsyncStream<RestTick> {
        AsyncStream { continuation in
            let token = UUID()
            print(token)
            if continuations[setId] == nil { continuations[setId] = [:] }
            continuations[setId]?[token] = continuation

            if let a = active, a.setId == setId {
                let rem = remainingSeconds(for: a)
                continuation.yield(.init(setId: a.setId, total: a.total, remaining: rem, isFinished: rem == 0))
            } else {
                continuation.yield(.init(setId: setId, total: 0, remaining: 0, isFinished: true))
            }

            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(setId: setId, token: token) }
            }
        }
    }

    public func start(setId: UUID, total: Int, startedAt: Date = Date()) {
        stopCurrent(sendFinal: false)
        active = Active(setId: setId, total: total, startedAt: startedAt)
        tickNow()
        startTicking()
    }

    public func resume(setId: UUID, total: Int, startedAt: Date) {
        start(setId: setId, total: total, startedAt: startedAt)
    }

    public func stopCurrent(sendFinal: Bool = true) {
        tickingTask?.cancel()
        tickingTask = nil
        guard let a = active else { return }
        if sendFinal {
            broadcast(.init(setId: a.setId, total: a.total, remaining: 0, isFinished: true))
        }
        active = nil
    }

    public func stopIfActive(setId: UUID, sendFinal: Bool = true) {
        guard active?.setId == setId else { return }
        stopCurrent(sendFinal: sendFinal)
    }

    public func adjust(by seconds: Int) {
        guard let a = active else { return }
        let newTotal = max(0, a.total + seconds)
        active = .init(setId: a.setId, total: newTotal, startedAt: a.startedAt)
        tickNow()
    }

    public func activeSetId() -> UUID? { active?.setId }

    // MARK: intern ticking
    private func startTicking() {
        tickingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let a = await self.active else { break }
                let rem = await self.remainingSeconds(for: a)
                await self.broadcast(.init(setId: a.setId, total: a.total, remaining: rem, isFinished: rem == 0))
                if rem == 0 {
                    let ended = a.endsAt
                    await self.stopCurrent(sendFinal: false)
                    if let onFinish = self.onFinish {
                        await MainActor.run { onFinish(.init(setId: a.setId, total: a.total, startedAt: a.startedAt, endedAt: ended)) }
                    }
                    break
                }
            }
        }
    }

    private func remainingSeconds(for a: Active) -> Int {
        max(0, Int(ceil(a.endsAt.timeIntervalSince(Date()))))
    }

    private func tickNow() {
        guard let a = active else { return }
        let rem = remainingSeconds(for: a)
        broadcast(.init(setId: a.setId, total: a.total, remaining: rem, isFinished: rem == 0))
    }

    private func broadcast(_ tick: RestTick) {
        continuations[tick.setId]?.values.forEach { $0.yield(tick) }
    }

    private func removeContinuation(setId: UUID, token: UUID) {
        continuations[setId]?[token] = nil
        if continuations[setId]?.isEmpty == true { continuations.removeValue(forKey: setId) }
    }
}
