import Foundation

public actor MuscleGroupProvider {
    
    private let repo: MuscleGroupRepository
    private var byId: [UUID: MuscleGroupDTO] = [:]
    private var listContinuations: [UUID: AsyncStream<[MuscleGroupDTO]>.Continuation] = [:]
    private var mapContinuations: [UUID: AsyncStream<[UUID: MuscleGroupDTO]>.Continuation] = [:]
    private var started = false
    
    private var pumpTask: Task<Void, Never>?
    
    init (repo: MuscleGroupRepository) {
        self.repo = repo
    }
    
    public func start () async {
        guard !started else { return }
        started = true
        pumpTask = Task {
            await pump()
        }
    }
    
    deinit  {
        pumpTask?.cancel()
    }
    
    private func startPump () async {
        self.pumpTask = Task {
            await self.pump()
        }
    }
    
    func snapshot() async -> [MuscleGroupDTO] {
        Array(byId.values).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending}
    }
    
    func streamAll() -> AsyncStream<[MuscleGroupDTO]> {
        AsyncStream { c in
            Task { [weak self] in
                guard let self else { return }
                let id = UUID()
                await self.registerListContinuation(id: id, c)
                c.yield(await self.snapshot())
                c.onTermination = { @Sendable _ in
                    Task { [weak self] in
                        await self?.unregisterListContinuation(id: id)
                    }
                }
            }
        }
    }
    
    func byIdMapStream() -> AsyncStream<[UUID : MuscleGroupDTO]> {
        AsyncStream { c in
            Task { [weak self] in
                guard let self else { return }
                let id = UUID()
                await self.registerMapContinuation(id: id, c)
                c.yield(await self.currentMap())
                c.onTermination = { @Sendable _ in
                    Task { [weak self] in
                        await self?.unregisterMapContinuation(id: id)
                    }
                }
            }
        }
    }
    
    func name(for id: UUID) async -> String? {
        byId[id]?.name
    }
    
    private func pump () async {
        let initial = await repo.snapshotDTOs()
        self.byId = Dictionary(uniqueKeysWithValues: initial.map { ($0.id, $0) })
        fanoutAll()
        
        let diffs = await repo.streamDiffs()
        
        for await diff in diffs {
            await apply(diff: diff)
            fanoutAll()
        }
    }
    
    private func apply (diff: EntityDiff<UUID>) async {
        if !diff.deleted.isEmpty {
            for id in diff.deleted {
                byId[id] = nil
            }
        }
        
        let need = diff.inserted + diff.updated
        if !need.isEmpty {
            if let fetched = try? await repo.fetchDTOs(ids: need) {
                for dto in fetched {
                    byId[dto.id] = dto
                }
            }
        }
    }
    
    private func fanoutAll () {
        let list = Array(byId.values).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending}
        for c in listContinuations.values {
            c.yield(list)
        }
        let map = byId
        for c in mapContinuations.values {
            c.yield(map)
        }
    }
    
    private func currentMap () -> [UUID: MuscleGroupDTO] {
        byId
    }
    
    private func registerListContinuation (id: UUID, _ c: AsyncStream<[MuscleGroupDTO]>.Continuation) {
        listContinuations[id] = c
    }
    
    private func unregisterListContinuation (id: UUID) {
        listContinuations[id] = nil
    }
    
    private func registerMapContinuation(id: UUID, _ c: AsyncStream<[UUID: MuscleGroupDTO]>.Continuation) {
        mapContinuations[id] = c
    }
    
    private func unregisterMapContinuation (id: UUID) {
        mapContinuations[id] = nil
    }
    
}
