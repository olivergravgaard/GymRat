import SwiftData
import Foundation

@MainActor
final class ExerciseRepository {
    typealias DTO = ExerciseDTO

    private let context: ModelContext

    private var modelById: [UUID: Exercise] = [:]
    private var dtoById: [UUID: DTO] = [:]
    
    private var booted = false

    private var diffSubscribers: [UUID: AsyncStream<EntityDiff<UUID>>.Continuation] = [:]
    private var pendingDiffSubscribers: [UUID: AsyncStream<EntityDiff<UUID>>.Continuation] = [:]

    init(context: ModelContext) {
        self.context = context
    }
    
    func boot () async throws {
        guard !booted else { return }
        
        let all = try context.fetch(FetchDescriptor<Exercise>())
        modelById = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0 )})
        dtoById = Dictionary(uniqueKeysWithValues: all.map { ($0.id, toDTO($0)) })
        
        booted = true
        
        if !pendingDiffSubscribers.isEmpty {
            for (k, v) in pendingDiffSubscribers {
                diffSubscribers[k] = v
            }
            
            pendingDiffSubscribers.removeAll()
        }
    }

    func snapshotDTOs() async -> [DTO] {
        Array(dtoById.values)
    }

    func streamDiffs() -> AsyncStream<EntityDiff<UUID>> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { c in
            let token = UUID()
            Task { @MainActor in
                if booted {
                    diffSubscribers[token] = c
                }else {
                    pendingDiffSubscribers[token] = c
                }
            }
            c.onTermination = { _ in
                Task { @MainActor in
                    self.diffSubscribers[token] = nil
                    self.pendingDiffSubscribers[token] = nil
                }
            }
        }
    }

    private func fanout (diff: EntityDiff<UUID>) {
        guard booted else { return }
        let targets = Array(diffSubscribers.values)
        for cont in targets {
            cont.yield(diff)
        }
    }

    func fetchDTOs(ids: [UUID]) async throws -> [DTO] {
        guard !ids.isEmpty else { return [] }

        var result: [DTO] = []
        var missing = Set<UUID>()

        for id in ids {
            if let dto = dtoById[id] {
                result.append(dto)
            } else {
                missing.insert(id)
            }
        }

        if !missing.isEmpty {
            let idsArray = Array(missing)
            let pred = #Predicate<Exercise> { idsArray.contains($0.id) }
            let fetched = try context.fetch(FetchDescriptor<Exercise>(predicate: pred))
            for e in fetched {
                modelById[e.id] = e
                let dto = toDTO(e)
                dtoById[e.id] = dto
                result.append(dto)
            }
        }
        
        return result
    }

    func fetchDTOByName(_ name: String) async throws -> DTO? {
        if let hit = dtoById.values.first(where: { $0.name == name }) { return hit }
        
        let pred = #Predicate<Exercise> { $0.name == name }
        if let m = try context.fetch(FetchDescriptor<Exercise>(predicate: pred)).first {
            modelById[m.id] = m
            let dto = toDTO(m)
            dtoById[m.id] = dto
            return dto
        }
        
        return nil
    }

    func create(name: String, muscleGroupID: UUID, isPredefined: Bool = false) async throws {
        if let _ = try await fetchDTOByName(name) {
            throw NSError(domain: "ExerciseRepository", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Name already exists"])
        }
        let mg = try resolveMuscleGroup(id: muscleGroupID)

        let ex = Exercise(name: name, muscleGoup: mg, isPredefined: isPredefined)
        context.insert(ex)
        try context.save()

        modelById[ex.id] = ex
        let dto = toDTO(ex)
        dtoById[ex.id] = dto

        fanout(diff: .init(inserted: [ex.id]))
    }

    func create(dto incoming: ExerciseDTO) async throws {
        let mg = try resolveMuscleGroup(id: incoming.muscleGroupID)
        let ex = Exercise(name: incoming.name, muscleGoup: mg, isPredefined: false)
        context.insert(ex)
        try context.save()

        let dto = toDTO(ex)
        modelById[ex.id] = ex
        dtoById[ex.id]   = dto
        
        fanout(diff: .init(inserted: [ex.id]))
    }

    func rename(id: UUID, to newName: String) async throws {
        guard let ex = modelById[id], ex.name != newName else { return }

        if let existing = try await fetchDTOByName(newName), existing.id != id {
            throw NSError(domain: "ExerciseRepository", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Name already exists"])
        }

        ex.name = newName
        try context.save()

        dtoById[id] = toDTO(ex)
        fanout(diff: .init(updated: [id]))
    }

    func changeMuscleGroup(id: UUID, to muscleGroupID: UUID) async throws {
        guard let ex = modelById[id], ex.muscleGroup.id != muscleGroupID else { return }

        let mg = try resolveMuscleGroup(id: muscleGroupID)
        ex.muscleGroup = mg
        try context.save()

        dtoById[id] = toDTO(ex)
        fanout(diff: .init(updated: [id]))
    }

    func delete(id: UUID) async throws {
        guard let ex = modelById[id] else { return }
        context.delete(ex)
        try context.save()

        modelById[id] = nil
        dtoById[id] = nil

        fanout(diff: .init(deleted: [id]))
    }

    private func toDTO(_ model: Exercise) -> DTO {
        DTO(
            id: model.id,
            version: dtoFingerprint(name: model.name, muscleGroupID: model.muscleGroup.id),
            name: model.name,
            muscleGroupID: model.muscleGroup.id
        )
    }

    private func dtoFingerprint(name: String, muscleGroupID: UUID) -> Int {
        var hasher = Hasher()
        hasher.combine(name)
        hasher.combine(muscleGroupID)
        return hasher.finalize()
    }

    private func resolveMuscleGroup(id: UUID) throws -> MuscleGroup {
        let pred = #Predicate<MuscleGroup> { $0.id == id }
        if let mg = try context.fetch(FetchDescriptor<MuscleGroup>(predicate: pred)).first {
            return mg
        }
        throw NSError(domain: "ExerciseRepository", code: 3,
                      userInfo: [NSLocalizedDescriptionKey: "MuscleGroup not found"])
    }
}
