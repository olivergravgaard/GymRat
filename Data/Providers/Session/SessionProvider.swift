import Foundation

actor SessionProvider {
    private let repo: SessionRepository

    // Let index (hele listen kan evt. være “meta” hvis du splitter DTO senere)
    private var byId: [UUID: WorkoutSessionDTO] = [:]
    private var sortedList: [WorkoutSessionDTO] = []

    private var listSubscribers: [UUID: AsyncStream<[WorkoutSessionDTO]>.Continuation] = [:]
    private var mapSubscribers:  [UUID: AsyncStream<[UUID: WorkoutSessionDTO]>.Continuation] = [:]
    private var diffSubscribers: [UUID: AsyncStream<EntityDiff<UUID>>.Continuation] = [:]

    private var pumpTask: Task<Void, Never>?
    private var booted = false
    private var readyWaiters: [CheckedContinuation<Void, Never>] = []

    init(repo: SessionRepository) {
        self.repo = repo
    }

    // MARK: Public API

    func boot() async {
        guard pumpTask == nil else { return }
        pumpTask = Task { [weak self] in
            await self?.pump()
        }
        await waitUntilReady()
    }

    func stop() {
        pumpTask?.cancel()
        pumpTask = nil
        finishAll()
    }

    func snapshot() async -> [WorkoutSessionDTO] { sortedList }

    /// Brugt af Profile: giver en stream med de N seneste
    func recent(_ limit: Int) -> AsyncStream<[WorkoutSessionDTO]> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { c in
            Task { [weak self] in
                guard let self else { return }
                let base = await self.streamAll()
                Task.detached {
                    for await list in base {
                        c.yield(Array(list.prefix(limit)))
                    }
                }
            }
        }
    }

    /// Hvis du senere vil separere tung “detail”, kan denne hente fra repo/LRU.
    func detail(id: UUID) async throws -> WorkoutSessionDTO? {
        if let hit = byId[id] { return hit }
        let fetched = try await repo.fetchDTOs(ids: [id])
        if let dto = fetched.first {
            byId[dto.id] = dto
            rebuildAndFanout()
            return dto
        }
        return nil
    }

    // MARK: Streams (samme mønster som ExerciseProvider)

    func streamAll() -> AsyncStream<[WorkoutSessionDTO]> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { c in
            Task { [weak self] in
                guard let self else { return }
                let id = UUID()
                await self.registerListSubscriber(id: id, c)
                await self.boot()
                c.yield(await self.sortedList)
                c.onTermination = { [weak self] _ in
                    Task { await self?.unregisterListSubscriber(id: id) }
                }
            }
        }
    }

    func byIdMapStream() -> AsyncStream<[UUID: WorkoutSessionDTO]> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { c in
            Task { [weak self] in
                guard let self else { return }
                let id = UUID()
                await self.registerMapSubscriber(id: id, c)
                await self.boot()
                c.yield(await self.byId)
                c.onTermination = { [weak self] _ in
                    Task { await self?.unregisterMapSubscriber(id: id) }
                }
            }
        }
    }

    func diffStream() -> AsyncStream<EntityDiff<UUID>> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { c in
            Task { [weak self] in
                guard let self else { return }
                let id = UUID()
                await self.registerDiffSubscriber(id: id, c)
                await self.boot()
                c.onTermination = { [weak self] _ in
                    Task { await self?.unregisterDiffSubscriber(id: id) }
                }
            }
        }
    }

    // MARK: Intern pump

    private func pump() async {
        try? await repo.boot()

        let initial = await repo.snapshotSortedByEndDate()
        byId = Dictionary(uniqueKeysWithValues: initial.map { ($0.id, $0) })
        rebuildAndFanout()
        booted = true
        signalReadyIfNeeded()

        for await d in await repo.streamDiffs() {
            if Task.isCancelled { break }

            // delete
            for id in d.deleted { byId[id] = nil }

            // insert/update
            let need = Array(Set(d.inserted).union(d.updated))
            if !need.isEmpty, let fetched = try? await repo.fetchDTOs(ids: need) {
                for dto in fetched { byId[dto.id] = dto }
            }

            rebuildAndFanout()

            for c in diffSubscribers.values { c.yield(d) }
        }
    }

    // MARK: Helpers (samme struktur som ExerciseProvider)

    private func rebuildAndFanout() {
        sortedList = byId.values.sorted {
            let a = $0.endedAt ?? $0.startedAt
            let b = $1.endedAt ?? $1.startedAt
            return a > b  // seneste først
        }
        for c in listSubscribers.values { c.yield(sortedList) }
        for c in mapSubscribers.values  { c.yield(byId) }
    }

    private func waitUntilReady() async {
        if booted { return }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            readyWaiters.append(cont)
        }
    }

    private func signalReadyIfNeeded() {
        guard booted else { return }
        let waiters = readyWaiters
        readyWaiters.removeAll()
        for w in waiters { w.resume() }
    }

    private func finishAll() {
        for c in listSubscribers.values { c.finish() }
        for c in mapSubscribers.values  { c.finish() }
        for c in diffSubscribers.values { c.finish() }
        listSubscribers.removeAll()
        mapSubscribers.removeAll()
        diffSubscribers.removeAll()
    }

    private func registerListSubscriber(id: UUID, _ c: AsyncStream<[WorkoutSessionDTO]>.Continuation) {
        listSubscribers[id] = c
    }
    private func unregisterListSubscriber(id: UUID) { listSubscribers[id] = nil }

    private func registerMapSubscriber(id: UUID, _ c: AsyncStream<[UUID: WorkoutSessionDTO]>.Continuation) {
        mapSubscribers[id] = c
    }
    private func unregisterMapSubscriber(id: UUID) { mapSubscribers[id] = nil }

    private func registerDiffSubscriber(id: UUID, _ c: AsyncStream<EntityDiff<UUID>>.Continuation) {
        diffSubscribers[id] = c
    }
    private func unregisterDiffSubscriber(id: UUID) { diffSubscribers[id] = nil }
}
