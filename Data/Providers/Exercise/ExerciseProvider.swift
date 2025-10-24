import Foundation
import Combine

actor ExerciseProvider {
    private let repo: ExerciseRepository

    private var byId: [UUID: ExerciseDTO] = [:]
    private var sortedList: [ExerciseDTO] = []

    private var listSubs: [UUID: AsyncStream<[ExerciseDTO]>.Continuation] = [:]
    private var mapSubs:  [UUID: AsyncStream<[UUID: ExerciseDTO]>.Continuation] = [:]

    private var pumpTask: Task<Void, Never>?
    private var booted = false

    init(
        repo: ExerciseRepository
    ) {
        self.repo = repo
    }

    func start() {
        startIfNeeded()
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
                await self.startIfNeeded()
                c.yield(await self.sortedList)
                c.onTermination = { [weak self] _ in
                    Task { await self?.unregisterListSubscriber(id: id) }
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
                await self.startIfNeeded()
                c.yield(await self.byId)
                c.onTermination = { [weak self] _ in
                    Task { await self?.unregisterMapSubscriber(id: id) }
                }
            }
        }
    }
    
    func create(name: String, muscleGroupID: UUID) async throws -> ExerciseDTO {
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


    private func startIfNeeded() {
        guard pumpTask == nil else { return }
        pumpTask = Task { [weak self] in
            await self?.pump()
        }
    }

    private func pump() async {
        if !booted {
            try? await repo.boot()
            let inital = await repo.snapshotDTOs()
            byId = Dictionary(uniqueKeysWithValues: inital.map { ($0.id, $0) })
            rebuildAndFanout()
            booted = true
        }
        
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
        }
    }

    private func rebuildAndFanout() {
        let newList = byId.values.sorted {
            let c = $0.name.localizedCaseInsensitiveCompare($1.name)
            
            if c == .orderedSame {
                return $0.id.uuidString < $1.id.uuidString
            }
            
            return c == .orderedAscending
        }
        
        sortedList = newList
        
        for c in listSubs.values {
            c.yield(sortedList)
        }
        
        for c in mapSubs.values {
            c.yield(byId)
        }
    }

    private func finishAll() {
        for c in listSubs.values {
            c.finish()
        }
        
        for c in mapSubs.values  {
            c.finish()
        }
        
        listSubs.removeAll()
        mapSubs.removeAll()
    }

    private func registerListSubscriber(id: UUID, _ c: AsyncStream<[ExerciseDTO]>.Continuation) {
        listSubs[id] = c
    }

    private func unregisterListSubscriber(id: UUID) {
        listSubs[id] = nil
    }

    private func registerMapSubscriber(id: UUID, _ c: AsyncStream<[UUID: ExerciseDTO]>.Continuation) {
        mapSubs[id] = c
    }

    private func unregisterMapSubscriber(id: UUID) {
        mapSubs[id] = nil
    }
}
