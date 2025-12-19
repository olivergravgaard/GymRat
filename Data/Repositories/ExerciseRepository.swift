import SwiftData
import Foundation

@MainActor
final class ExerciseRepository {
    private let context: ModelContext

    private var modelById: [UUID: Exercise] = [:]
    private var dtoById: [UUID: ExerciseDTO] = [:]
    
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

    func getDTOs () async -> [ExerciseDTO] {
        Array(dtoById.values)
    }

    
    //
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
                    print("Stream terminated")
                    self.diffSubscribers[token] = nil
                    self.pendingDiffSubscribers[token] = nil
                }
            }
        }
    }

    func fetchDTOs(ids: [UUID]) async throws -> [ExerciseDTO] {
        guard !ids.isEmpty else { return [] }

        var result: [ExerciseDTO] = []
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

    func fetchDTOByName(_ name: String) async throws -> ExerciseDTO? {
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

    func create(
        id: UUID,
        name: String,
        muscleGroupID: UUID,
        origin: ExerciseOrigin,
        ownerId: String?
    ) async throws {
        if let _ = try await fetchDTOByName(name) {
            throw NSError(domain: "ExerciseRepository", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "ExercieRepository: Name already exists \(name)"])
        }
        
        let muscleGroup = try resolveMuscleGroup(id: muscleGroupID)

        let exercise = Exercise(
            id: id,
            name: name,
            muscleGoup: muscleGroup,
            origin: origin,
            ownerId: ownerId
        )
        
        context.insert(exercise)
        try context.save()

        modelById[exercise.id] = exercise
        let dto = toDTO(exercise)
        dtoById[exercise.id] = dto

        broadcast(diff: .init(inserted: [exercise.id]))
    }

    func create(
        dto incoming: ExerciseDTO,
        ownerId: String?
    ) async throws {
        print("EXERCISEREPOSITORY: Creating from remote")
        let muscleGroup = try resolveMuscleGroup(id: incoming.muscleGroupID)
        
        let exercise = Exercise(
            id: incoming.id,
            name: incoming.name,
            muscleGoup: muscleGroup,
            origin: incoming.origin,
            ownerId: ownerId
        )
        
        context.insert(exercise)
        try context.save()

        modelById[exercise.id] = exercise
        let dto = toDTO(exercise)
        dtoById[exercise.id] = dto
        
        broadcast(diff: .init(inserted: [exercise.id]))
    }

    func rename(id: UUID, to newName: String) async throws {
        guard let ex = modelById[id], ex.name != newName else { return }

        if let existing = try await fetchDTOByName(newName), existing.id != id {
            throw NSError(domain: "ExerciseRepository", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Name already exists"])
        }

        ex.name = newName
        ex.updatedAt = Date()
        ex.needsSync = ex.origin.isSyncable
        
        try context.save()

        dtoById[id] = toDTO(ex)
        broadcast(diff: .init(updated: [id]))
    }

    func changeMuscleGroup(id: UUID, to muscleGroupID: UUID) async throws {
        guard let exercise = modelById[id], exercise.muscleGroup.id != muscleGroupID else { return }

        let mg = try resolveMuscleGroup(id: muscleGroupID)
        
        exercise.muscleGroup = mg
        exercise.updatedAt = Date()
        exercise.needsSync = exercise.origin.isSyncable
        
        try context.save()

        dtoById[id] = toDTO(exercise)
        broadcast(diff: .init(updated: [id]))
    }

    func delete(id: UUID) async throws {
        guard let exercise = modelById[id] else { return }
        context.delete(exercise)
        try context.save()

        modelById[id] = nil
        dtoById[id] = nil

        broadcast(diff: .init(deleted: [id]))
    }

    func pendingCustomExercises (for ownerId: String) async -> [Exercise] {
        modelById.values.filter {
            $0.origin == .custom &&
            $0.ownerId == ownerId &&
            $0.needsSync &&
            !$0.isDeletedRemotely
        }
    }
    
    func upsertFromRemote (
        remote: RemoteExerciseDTO,
        muscleGroupId: UUID,
        ownerId: String
    ) throws {
        guard let uuid = UUID(uuidString: remote.id) else { return }
        
        if let existing = modelById[uuid] {
            existing.name = remote.name
            existing.muscleGroup = try resolveMuscleGroup(id: muscleGroupId)
            existing.origin = .custom
            existing.ownerId = ownerId
            existing.updatedAt = remote.updatedAt
            existing.needsSync = false
            existing.isDeletedRemotely = remote.isDeleted
            
            if remote.isDeleted {
                context.delete(existing)
                modelById[uuid] = nil
                dtoById[uuid] = nil
                
                try context.save()
                
                return
            }else {
                dtoById[uuid] = toDTO(existing)
            }
        }else {
            let muscleGroup = try resolveMuscleGroup(id: muscleGroupId)
            let ex = Exercise(
                id: uuid,
                name: remote.name,
                muscleGoup: muscleGroup,
                origin: .custom,
                ownerId: ownerId
            )
            
            ex.id = uuid
            ex.updatedAt = remote.updatedAt
            ex.needsSync = false
            ex.isDeletedRemotely = remote.isDeleted
            
            if remote.isDeleted {
                return
            }
            
            context.insert(ex)
            modelById[ex.id] = ex
            dtoById[ex.id] = toDTO(ex)
        }
    }
    
    func markSynced (_ exercise: Exercise) throws {
        exercise.needsSync = false
        exercise.updatedAt = Date()
        try context.save()
        dtoById[exercise.id] = toDTO(exercise)
        broadcast(diff: .init(updated: [exercise.id]))
    }
    
    func reset () {
        if booted {
            let allIDs = Array(modelById.keys)
            
            if !allIDs.isEmpty {
                broadcast(diff: .init(deleted: allIDs))
            }
        }
        
        modelById.removeAll()
        dtoById.removeAll()
        booted = false
    }
    
    private func broadcast (diff: EntityDiff<UUID>) {
        guard booted else { return }
        
        let targets = Array(diffSubscribers.values)
        
        for cont in targets {
            cont.yield(diff)
        }
    }
    
    private func toDTO(_ model: Exercise) -> ExerciseDTO {
        ExerciseDTO(
            id: model.id,
            version: dtoFingerprint(
                name: model.name,
                muscleGroupID: model.muscleGroup.id,
                origin: model.origin
            ),
            name: model.name,
            muscleGroupID: model.muscleGroup.id,
            origin: model.origin
        )
    }

    private func dtoFingerprint(
        name: String,
        muscleGroupID: UUID,
        origin: ExerciseOrigin
    ) -> Int {
        var hasher = Hasher()
        hasher.combine(name)
        hasher.combine(muscleGroupID)
        hasher.combine(origin)
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
