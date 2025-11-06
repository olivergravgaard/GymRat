import Foundation
import Combine

actor ExerciseProvider {
    private let repo: ExerciseRepository

    private var byId: [UUID: ExerciseDTO] = [:]
    private var sortedList: [ExerciseDTO] = []

    private var listSubscribers: [UUID: AsyncStream<[ExerciseDTO]>.Continuation] = [:]
    private var mapSubscribers:  [UUID: AsyncStream<[UUID: ExerciseDTO]>.Continuation] = [:]
    private var diffSubscribers: [UUID: AsyncStream<EntityDiff<UUID>>.Continuation] = [:]

    private var pumpTask: Task<Void, Never>?
    private var booted = false
    
    private var readyWaiters: [CheckedContinuation<Void, Never>] = []

    init(
        repo: ExerciseRepository
    ) {
        self.repo = repo
    }

    func boot() async {
        guard pumpTask == nil else { return }
        pumpTask = Task { [weak self] in
            await self?.pump()
        }
        
        await waitUntilReady()
    }
    
    private func waitUntilReady () async {
        if booted { return }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            readyWaiters.append(cont)
        }
    }
    
    private func signalReadyIfNeeded () {
        guard booted else { return }
        let waiters = readyWaiters
        readyWaiters.removeAll()
        
        for waiter in waiters {
            waiter.resume()
        }
    }
    
    func stop()  {
        pumpTask?.cancel()
        pumpTask = nil
        finishAll()
    }
    
    func snapshot() async -> [ExerciseDTO] {
        sortedList
    }
    
    func nameMapSnapshot () async -> [UUID: String] {
        let list = await snapshot()
        return Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0.name) })
    }

    func streamAll() -> AsyncStream<[ExerciseDTO]> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { c in
            Task { [weak self] in
                guard let self else { return }
                let id = UUID()
                await self.registerListSubscriber(id: id, c)
                await self.boot()
                c.yield(await self.sortedList)
                c.onTermination = { [weak self] _ in
                    Task {
                        await self?.unregisterListSubscriber(id: id)
                    }
                }
            }
        }
    }

    func byIdMapStream() -> AsyncStream<[UUID: ExerciseDTO]> {
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
    
    func diffStream () -> AsyncStream<EntityDiff<UUID>> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { c in
            Task { [weak self] in
                guard let self else { return }
                let id = UUID()
                await self.registerDiffSubscriber(id: id, c)
                await self.boot()
                c.onTermination = { [weak self] _ in
                    Task {
                        await self?.unregisterDiffSubscriber(id: id)
                    }
                }
            }
        }
    }
    
    func create(name: String, muscleGroupID: UUID) async throws {
        try await repo.create(name: name, muscleGroupID: muscleGroupID)
    }

    func rename(id: UUID, to newName: String) async throws {
        try await repo.rename(id: id, to: newName)
    }

    func changeMuscleGroup(id: UUID, to muscleGroupID: UUID) async throws {
        try await repo.changeMuscleGroup(id: id, to: muscleGroupID)
    }
    
    func delete (id: UUID) async throws {
        try await repo.delete(id: id)
    }
    
    func dto (for id: UUID) -> ExerciseDTO? {
        return byId[id]
    }

    private func pump() async {
        try? await repo.boot()
        
        let inital = await repo.snapshotDTOs()
        byId = Dictionary(uniqueKeysWithValues: inital.map { ($0.id, $0) })
        rebuildAndFanout()
        booted = true
        signalReadyIfNeeded()
        
        for await d in await repo.streamDiffs() {
            if Task.isCancelled { break }
            
            for id in d.deleted {
                byId[id] = nil
            }
            
            let need = Array(Set(d.inserted).union(d.updated))
            if !need.isEmpty, let fetched = try? await repo.fetchDTOs(ids: need) {
                for dto in fetched {
                    byId[dto.id] = dto
                }
            }
            
            rebuildAndFanout()
            
            for c in diffSubscribers.values {
                c.yield(d)
            }
        }
    }

    private func rebuildAndFanout() {
        let newList = byId.values.sorted {
            let c = $0.name.localizedCaseInsensitiveCompare($1.name)
            return c == .orderedSame ? $0.id.uuidString < $1.id.uuidString : c == .orderedAscending
        }
        
        sortedList = newList
        
        for c in listSubscribers.values {
            c.yield(sortedList)
        }
        
        for c in mapSubscribers.values {
            c.yield(byId)
        }
    }

    private func finishAll() {
        for c in listSubscribers.values {
            c.finish()
        }
        
        for c in mapSubscribers.values {
            c.finish()
        }
        
        for c in diffSubscribers.values {
            c.finish()
        }
        
        listSubscribers.removeAll()
        mapSubscribers.removeAll()
        diffSubscribers.removeAll()
    }

    private func registerListSubscriber(id: UUID, _ c: AsyncStream<[ExerciseDTO]>.Continuation) {
        listSubscribers[id] = c
    }

    private func unregisterListSubscriber(id: UUID) {
        listSubscribers[id] = nil
    }

    private func registerMapSubscriber(id: UUID, _ c: AsyncStream<[UUID: ExerciseDTO]>.Continuation) {
        mapSubscribers[id] = c
    }

    private func unregisterMapSubscriber(id: UUID) {
        mapSubscribers[id] = nil
    }
    
    private func registerDiffSubscriber (id: UUID, _ c: AsyncStream<EntityDiff<UUID>>.Continuation) {
        diffSubscribers[id] = c
    }
    
    private func unregisterDiffSubscriber (id: UUID) {
        diffSubscribers[id] = nil
    }
}
