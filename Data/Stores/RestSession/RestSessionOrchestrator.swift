import Foundation

struct RestTick: Sendable {
    let activeSetId: UUID?
    let remaining: Int
    let progress: Double
}

actor RestSessionOrchestrator {
    private let getRest: @Sendable (_ setId: UUID) async -> RestSession?
    private let ensureRestExists: @Sendable (_ setId: UUID) async -> Void
    private let setRest: @Sendable (_ setId: UUID, _ new: RestSession) async -> Void
    private let markDirty: @Sendable () async -> Void
    private let findFirstRunningId: @Sendable () async -> UUID?
    
    private var activeSetId: UUID?
    private var tickTask: Task<Void, Never>?
    
    init(
        getRest: @Sendable @escaping (_: UUID) async -> RestSession?,
        ensureRestExists: @Sendable @escaping (_: UUID) async -> Void,
        setRest: @Sendable @escaping (_: UUID, _: RestSession) async -> Void,
        markDirty: @Sendable @escaping () async -> Void,
        findFirstRunningId: @Sendable @escaping () async -> UUID?,
        activeSetId: UUID? = nil,
        tickTask: Task<Void, Never>? = nil)
    {
        self.getRest = getRest
        self.ensureRestExists = ensureRestExists
        self.setRest = setRest
        self.markDirty = markDirty
        self.findFirstRunningId = findFirstRunningId
        self.activeSetId = activeSetId
        self.tickTask = tickTask
    }
    
    func start (for setId: UUID, duration: Int) async {
        if let cur = activeSetId, cur != setId {
            await forceComplete(cur)
        }
        
        activeSetId = setId
        
        await ensureRestExists(setId)
        
        var r = await getRest(setId) ?? RestSession(duration: 0, startedAt: nil, endedAt: nil, restState: .idle)
        r.duration = max(0, duration)
        r.startedAt = Date()
        r.endedAt = nil
        r.restState = .running
        await setRest(setId, r)
        await markDirty()
        await startTickerIfNeeded()
    }
    
    func completeActive (endAtNow: Bool = true) async {
        guard let id = activeSetId else { return }
        await completeIfRunning(id, endAtNow: endAtNow)
        activeSetId = nil
        cancelTicker()
    }
    
    func restore () async {
        guard let id = await findFirstRunningId() else {
            activeSetId = nil
            cancelTicker()
            return
        }
        
        activeSetId = id
        await ensureCompletionIfExpired(for: id)
        await startTickerIfNeeded()
    }
    
    func snapshot () async -> RestTick {
        guard let id = activeSetId, let s = await getRest(id) else {
            return .init(activeSetId: nil, remaining: 0, progress: 0)
        }
        
        let rem = remaining(s)
        let prog = s.duration == 0 ? 1 : min(1, max(0, 1 - Double(rem) / Double(s.duration)))
        return .init(activeSetId: id, remaining: rem, progress: prog)
    }
    
    private func startTickerIfNeeded () async {
        cancelTicker()
        guard let id = activeSetId, let s = await getRest(id), s.restState == .running else { return }
        tickTask = Task { [weak self] in
            while !(Task.isCancelled) {
                try? await Task.sleep(for: .seconds(1))
                await self?.onTick()
            }
        }
    }
    
    private func onTick () async {
        guard let id = activeSetId, let s = await getRest(id), s.restState == .running else { return }
        if remaining(s) <= 0 {
            var rr = s
            
            if let startedAt = rr.startedAt {
                rr.endedAt = startedAt.addingTimeInterval(TimeInterval(rr.duration))
                rr.restState = .completed
                await setRest(id, rr)
                await markDirty()
            }
            
            activeSetId = nil
            cancelTicker()
        }
    }
    
    private func ensureCompletionIfExpired (for setId: UUID) async {
        guard let s = await getRest(setId), s.restState == .running else { return }
        if remaining(s) <= 0 {
            var rr = s
            if let startedAt = rr.startedAt {
                rr.endedAt = startedAt.addingTimeInterval(TimeInterval(rr.duration))
                rr.restState = .completed
                await setRest(setId, rr)
                await markDirty()
            }
            
            activeSetId = nil
            cancelTicker()
        }
    }
    
    private func completeIfRunning (_ setId: UUID, endAtNow: Bool) async {
        guard let s = await getRest(setId), s.restState == .running else { return }
        var rr = s
        if let startedAt = rr.startedAt {
            let elapsed = Int(Date().timeIntervalSince(startedAt))
            rr.endedAt = (elapsed >= rr.duration || !endAtNow) ? startedAt.addingTimeInterval(TimeInterval(rr.duration)) : Date()
        }else {
            rr.endedAt = Date()
        }
        
        rr.restState = .completed
        await setRest(setId, rr)
        await markDirty()
    }
    
    private func forceComplete (_ setId: UUID) async {
        await completeIfRunning(setId, endAtNow: false)
    }
    
    private func remaining (_ s: RestSession) -> Int {
        guard s.restState == .running, let startedAt = s.startedAt else { return 0 }
        return max(0, s.duration - Int(Date().timeIntervalSince(startedAt)))
    }
    
    private func cancelTicker () {
        tickTask?.cancel()
        tickTask = nil
    }
}
