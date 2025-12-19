import SwiftData
import Foundation

@MainActor
final class MuscleGroupRepository {
    private let context: ModelContext
    
    private var modelById: [UUID: MuscleGroup] = [:]
    private var dtoById: [UUID: MuscleGroupDTO] = [:]
    private var booted: Bool = false
    
    private var diffContinuations: [UUID: AsyncStream<EntityDiff<UUID>>.Continuation] = [:]
    
    init (context: ModelContext) {
        self.context = context
    }
    
    func boot () async throws {
        guard !booted else { return }
        let all = try context.fetch(FetchDescriptor<MuscleGroup>())
        modelById = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        dtoById = Dictionary(uniqueKeysWithValues: all.map { ($0.id, toDTO($0)) })
        booted = true
    }
    
    func snapshotDTOs () async -> [MuscleGroupDTO] {
        Array(dtoById.values)
    }

    
    func streamDiffs () -> AsyncStream<EntityDiff<UUID>> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { c in
            let id = UUID()
            
            Task { @MainActor in
                self.diffContinuations[id] = c
            }
            
            c.onTermination = { _ in
                Task { @MainActor in
                    self.diffContinuations[id] = nil
                }
            }
        }
    }
    
    private func broadcast (diff: EntityDiff<UUID>) {
        Task { @MainActor in
            let targets = Array(self.diffContinuations.values)
            
            Task.detached {
                for cont in targets {
                    cont.yield(diff)
                }
            }
        }
    }
    
    func fetchDTOs(ids: [UUID]) async throws -> [MuscleGroupDTO] {
        guard !ids.isEmpty else { return [] }

        var result: [MuscleGroupDTO] = []
        var missing = Set<UUID>()

        for id in ids {
            if let dto = dtoById[id] {
                result.append(dto)
            } else {
                missing.insert(id)
            }
        }

        if !missing.isEmpty {
            let arr = Array(missing)
            let pred = #Predicate<MuscleGroup> { arr.contains($0.id) }
            let fetched = try context.fetch(FetchDescriptor<MuscleGroup>(predicate: pred))
            for mg in fetched {
                modelById[mg.id] = mg
                let dto = toDTO(mg)
                dtoById[mg.id] = dto
                result.append(dto)
            }
        }
        return result
    }
    
    func fetchDTOByID(_ id: UUID) async throws -> MuscleGroupDTO? {
        if let hit = dtoById.values.first(where: { $0.id == id }) { return hit }
        let pred = #Predicate<MuscleGroup> { $0.id == id }
        
        if let muscleGroup = try context.fetch(FetchDescriptor<MuscleGroup>(predicate: pred)).first {
            modelById[muscleGroup.id] = muscleGroup
            let dto = toDTO(muscleGroup)
            dtoById[muscleGroup.id] = dto
            return dto
        }
        return nil
    }
    
    func fetchDTOByName (_ name: String) async throws -> MuscleGroupDTO? {
        if let hit = dtoById.values.first(where: { $0.name == name}) { return hit }
        
        let pred = #Predicate<MuscleGroup> { $0.name == name }
        if let muscleGroup = try context.fetch(FetchDescriptor<MuscleGroup>(predicate: pred)).first {
            modelById[muscleGroup.id] = muscleGroup
            let dto = toDTO(muscleGroup)
            dtoById[muscleGroup.id] = dto
            return dto
        }
        
        return nil
    }
    
    func create(
        id: UUID,
        name: String,
        isBuiltin: Bool
    ) async throws -> MuscleGroupDTO {
        if let _ = try await fetchDTOByID(id) {
            throw NSError(domain: "MuscleGroupRepository", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "This MuscleGroup already exists in the MuscleGroupCatalog."])
        }
        
        let muscleGroup = MuscleGroup(
            id: id,
            name: name,
            isBuiltin: isBuiltin
        )
        
        context.insert(muscleGroup)
        try context.save()
        
        modelById[muscleGroup.id] = muscleGroup
        let dto = toDTO(muscleGroup)
        dtoById[muscleGroup.id] = dto
        
        broadcast(diff: .init(inserted: [muscleGroup.id]))
        return dto
    }
    
    func reset () {
        modelById.removeAll()
        dtoById.removeAll()
        booted = false
    }

    private func toDTO(_ model: MuscleGroup) -> MuscleGroupDTO {
        MuscleGroupDTO(
            id: model.id,
            name: model.name,
            isBuiltin: model.isBuiltin
        )
    }
}
