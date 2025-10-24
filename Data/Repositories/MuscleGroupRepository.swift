import SwiftData
import Foundation

@MainActor
final class MuscleGroupRepository {
    typealias DTO = MuscleGroupDTO
    
    private let context: ModelContext
    
    private var modelById: [UUID: MuscleGroup] = [:]
    private var dtoById: [UUID: DTO] = [:]
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
    
    func snapshotDTOs () async -> [DTO] {
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
    
    func fetchDTOByName(_ name: String) async throws -> DTO? {
        if let hit = dtoById.values.first(where: { $0.name == name }) { return hit }
        let pred = #Predicate<MuscleGroup> { $0.name == name }
        if let mg = try context.fetch(FetchDescriptor<MuscleGroup>(predicate: pred)).first {
            modelById[mg.id] = mg
            let dto = toDTO(mg)
            dtoById[mg.id] = dto
            return dto
        }
        return nil
    }
    
    func create(name: String, isPredefined: Bool) async throws -> DTO {
        if let _ = try await fetchDTOByName(name) {
            throw NSError(domain: "MuscleGroupRepository", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Name already exists"])
        }
        let mg = MuscleGroup(name: name, isPredefined: isPredefined)
        context.insert(mg)
        try context.save()

        modelById[mg.id] = mg
        let dto = toDTO(mg)
        dtoById[mg.id] = dto

        broadcast(diff: .init(inserted: [mg.id]))
        return dto
    }

    func rename(id: UUID, to newName: String) async throws {
        guard let mg = modelById[id] else { return }
        guard mg.name != newName else { return }

        // Undgå navnekollision
        if let existing = try await fetchDTOByName(newName), existing.id != id {
            throw NSError(domain: "MuscleGroupRepository", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Name already exists"])
        }

        mg.name = newName
        try context.save()

        dtoById[id] = toDTO(mg)
        broadcast(diff: .init(updated: [id]))
    }

    func delete(id: UUID) async throws {
        guard let mg = modelById[id] else { return }
        context.delete(mg)
        try context.save()

        modelById[id] = nil
        dtoById[id] = nil

        broadcast(diff: .init(deleted: [id]))
    }

    private func toDTO(_ model: MuscleGroup) -> DTO {
        let dto = DTO(
            id: model.id,
            version: dtoFingerprint(name: model.name, isPredefined: model.isPredefined),
            name: model.name,
            isPredefined: model.isPredefined
        )
        return dto
    }

    private func dtoFingerprint(name: String, isPredefined: Bool) -> Int {
        var hasher = Hasher()
        hasher.combine(name)
        hasher.combine(isPredefined)
        return hasher.finalize()
    }

}
