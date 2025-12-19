import SwiftData
import Foundation

@MainActor
final class TemplateRepository {
    private let context: ModelContext

    private var modelById: [UUID: WorkoutTemplate] = [:]
    private var dtoById: [UUID: WorkoutTemplateDTO] = [:]
    private var booted = false

    private var diffContinuations: [UUID: AsyncStream<EntityDiff<UUID>>.Continuation] = [:]

    init(context: ModelContext) {
        self.context = context
    }
    
    func boot() async throws {
        guard !booted else { return }
        let all = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        modelById = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        dtoById = Dictionary(uniqueKeysWithValues: all.map { ($0.id, toDTO($0)) })
        booted = true
    }

    func snapshotDTOs() async -> [WorkoutTemplateDTO] {
        Array(dtoById.values)
    }
    
    func streamDiffs() -> AsyncStream<EntityDiff<UUID>> {
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

    func fetchDTOs(ids: [UUID]) async throws -> [WorkoutTemplateDTO] {
        guard !ids.isEmpty else { return [] }

        var result: [WorkoutTemplateDTO] = []
        var missing = Set<UUID>()
        for id in ids {
            if let dto = dtoById[id] { result.append(dto) } else { missing.insert(id) }
        }

        if !missing.isEmpty {
            let idsArray = Array(missing)
            let pred = #Predicate<WorkoutTemplate> { idsArray.contains($0.id) }
            let fetched = try context.fetch(FetchDescriptor<WorkoutTemplate>(predicate: pred))
            for wt in fetched {
                modelById[wt.id] = wt
                let dto = toDTO(wt)
                dtoById[wt.id] = dto
                result.append(dto)
            }
        }
        return result
    }

    func fetchDTOByName(_ name: String) async throws -> WorkoutTemplateDTO? {
        if let hit = dtoById.values.first(where: { $0.name == name }) { return hit }
        let pred = #Predicate<WorkoutTemplate> { $0.name == name }
        if let wt = try context.fetch(FetchDescriptor<WorkoutTemplate>(predicate: pred)).first {
            modelById[wt.id] = wt
            let dto = toDTO(wt)
            dtoById[wt.id] = dto
            return dto
        }
        return nil
    }
    
    func restoreTemplate(from dto: WorkoutTemplateDTO) throws {
        guard let model = modelById[dto.id] else { return }

        if model.name != dto.name {
            model.name = dto.name
        }

        let desiredMuscleGroups = Set(dto.muscleGroupsIDs)
        if desiredMuscleGroups != Set(model.muscleGroups.map(\.id)) {
            let muscleGroupsById = try resolveMuscleGroups(ids: Array(desiredMuscleGroups))
            model.muscleGroups = dto.muscleGroupsIDs.compactMap { muscleGroupsById[$0] }
        }

        // exercises: delete missing
        let currentETById = Dictionary(uniqueKeysWithValues: model.exerciseTemplates.map { ($0.id, $0) })
        let desiredETIDs  = Set(dto.exerciseTemplates.map(\.id))
        if !currentETById.isEmpty {
            for (etId, et) in currentETById where !desiredETIDs.contains(etId) {
                context.delete(et)
            }
        }

        // ensure referenced exercises exist
        let desiredExerciseIDs = Set(dto.exerciseTemplates.map(\.exerciseId))
        let exerciseById = try resolveExercises(ids: Array(desiredExerciseIDs))

        // upsert exercises + sets
        var finalETs: [ExerciseTemplate] = []
        finalETs.reserveCapacity(dto.exerciseTemplates.count)

        for etDTO in dto.exerciseTemplates {
            let et: ExerciseTemplate
            if let existing = currentETById[etDTO.id] {
                et = existing
            } else {
                guard let exercise = exerciseById[etDTO.exerciseId] else { continue }
                et = ExerciseTemplate(exercise: exercise, workoutTemplate: model, order: etDTO.order)
                context.insert(et)
            }

            et.order = etDTO.order
            if let ex = exerciseById[etDTO.exerciseId], et.exercise.id != ex.id {
                et.exercise = ex
            }
            et.settings = etDTO.settings
            et.notes = etDTO.notes

            let currentSTById = Dictionary(uniqueKeysWithValues: et.setTemplates.map { ($0.id, $0) })
            let desiredSTIDs  = Set(etDTO.sets.map(\.id))
            if !currentSTById.isEmpty {
                for (stId, st) in currentSTById where !desiredSTIDs.contains(stId) {
                    context.delete(st)
                }
            }

            var finalSTs: [SetTemplate] = []
            finalSTs.reserveCapacity(etDTO.sets.count)

            for stDTO in etDTO.sets {
                let st: SetTemplate
                if let existing = currentSTById[stDTO.id] {
                    st = existing
                } else {
                    st = SetTemplate(exerciseTemplate: et, order: stDTO.order)
                    context.insert(st)
                }
                st.order = stDTO.order
                st.weightTarget = stDTO.weightTarget
                st.minReps = stDTO.minReps
                st.maxReps = stDTO.maxReps
                st.setType = stDTO.setType
                st.restTemplate = stDTO.restTemplate

                finalSTs.append(st)
            }

            finalSTs.sort { $0.order < $1.order }
            et.setTemplates = finalSTs
            finalETs.append(et)
        }

        finalETs.sort { $0.order < $1.order }
        
        model.exerciseTemplates = finalETs
        model.needsSync = true
        model.updatedAt = Date()
        
        try context.save()

        let updatedDTO = toDTO(model)
        dtoById[model.id] = updatedDTO
        broadcast(diff: .init(updated: [model.id]))
    }

    func create(
        name: String,
        muscleGroupIDs: [UUID],
        ownerId: String?
    ) async throws -> WorkoutTemplateDTO {
        if let _ = try await fetchDTOByName(name) {
            throw NSError(domain: "TemplateRepository", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Name already exists"])
        }
        
        let muscleGroups = try muscleGroupIDs.map { try resolveMuscleGroup(id: $0) }
        
        let workoutTemplate = WorkoutTemplate(
            name: name,
            muscleGroups: muscleGroups,
            ownerId: ownerId
        )
        
        context.insert(workoutTemplate)
        try context.save()

        modelById[workoutTemplate.id] = workoutTemplate
        let dto = toDTO(workoutTemplate)
        dtoById[workoutTemplate.id]   = dto

        broadcast(diff: .init(inserted: [workoutTemplate.id]))
        return dto
    }

    func create(dto: WorkoutTemplateDTO, ownerId: String?) async throws {
        let muscleGroups = try dto.muscleGroupsIDs.map { try resolveMuscleGroup(id: $0) }
        
        let workoutTemplate = WorkoutTemplate(
            name: dto.name,
            muscleGroups: muscleGroups,
            ownerId: ownerId
        )
        
        workoutTemplate.exerciseTemplates = try dto.exerciseTemplates.map { try dtoToExerciseTemplate(dto: $0, workoutTemplate: workoutTemplate) }

        context.insert(workoutTemplate)
        try context.save()

        dtoById[workoutTemplate.id] = dto
        let dto = toDTO(workoutTemplate)
        modelById[workoutTemplate.id] = workoutTemplate

        broadcast(diff: .init(inserted: [workoutTemplate.id]))
    }

    func rename(id: UUID, to newName: String) async throws {
        guard let workoutTemplate = modelById[id] else { return }
        guard workoutTemplate.name != newName else { return }

        if let existing = try await fetchDTOByName(newName), existing.id != id {
            throw NSError(domain: "TemplateRepository", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Name already exists"])
        }

        workoutTemplate.name = newName
        workoutTemplate.updatedAt = Date()
        workoutTemplate.needsSync = true
        
        try context.save()

        dtoById[id] = toDTO(workoutTemplate)
        broadcast(diff: .init(updated: [id]))
    }

    func changeMuscleGroups(id: UUID, to muscleGroupIDs: [UUID]) async throws {
        guard let workoutTemplate = modelById[id] else { return }

        let newMuscleGroupIDs = Set(muscleGroupIDs)
        let currentMuscleGroupIDs = Set(workoutTemplate.muscleGroups.map(\.id))
        
        guard newMuscleGroupIDs != currentMuscleGroupIDs else { return }

        let muscleGroups = try muscleGroupIDs.map { try resolveMuscleGroup(id: $0) }
        
        workoutTemplate.muscleGroups = muscleGroups
        workoutTemplate.updatedAt = Date()
        workoutTemplate.needsSync = true
        
        try context.save()

        dtoById[id] = toDTO(workoutTemplate)
        broadcast(diff: .init(updated: [id]))
    }

    func delete(id: UUID) async throws {
        guard let workoutTemplate = modelById[id] else { return }
        context.delete(workoutTemplate)
        try context.save()

        modelById[id] = nil
        dtoById[id] = nil

        broadcast(diff: .init(deleted: [id]))
    }
    
    func pendingTemplates (for ownerId: String) async -> [WorkoutTemplateDTO] {
        dtoById.values.compactMap { dto in
            guard let model = modelById[dto.id] else { return nil }
            guard model.ownerId == ownerId else { return nil }
            guard model.needsSync && !model.isDeletedRemotely else { return nil }
            return dto
        }
    }
    
    func upsertFromRemote (
        remote: RemoteWorkoutTemplateDTO,
        ownerId: String
    ) throws {
        let dto = remote.workoutTemplate
        let templateId = dto.id
        
        if remote.isDeleted {
            if let existing = modelById[templateId] {
                context.delete(existing)
                modelById[templateId] = nil
                dtoById[templateId] = nil
                try context.save()
                broadcast(diff: .init(deleted: [templateId]))
            }
            
            return
        }
        
        if let existing = modelById[templateId] {
            try restoreTemplate(from: dto)
            existing.ownerId = ownerId
            existing.needsSync = false
            existing.isDeletedRemotely = false
            existing.updatedAt = remote.updatedAt
        }else {
            print("Creating from remote")
            try createFromRemote(dto: dto, ownerId: ownerId, updateAt: remote.updatedAt)
        }
    }
    
    func markSynced (_ dto: WorkoutTemplateDTO) throws {
        guard let model = modelById[dto.id] else { return }
        
        
        model.needsSync = false
        model.updatedAt = Date()
        
        try context.save()
        
        dtoById[model.id] = toDTO(model)
        
        broadcast(diff: .init(updated: [model.id]))
    }
    
    func reset () {
        modelById.removeAll()
        dtoById.removeAll()
        booted = false
    }
    
    private func createFromRemote (dto: WorkoutTemplateDTO, ownerId: String, updateAt: Date) throws {
        let muscleGroups = try resolveMuscleGroups(ids: dto.muscleGroupsIDs).map { (_, muscleGroup) in
            muscleGroup
        }
        
        let workoutTemplate = WorkoutTemplate(
            name: dto.name,
            muscleGroups: muscleGroups,
            ownerId: ownerId
        )
        
        workoutTemplate.exerciseTemplates = try dto.exerciseTemplates.map {
            try dtoToExerciseTemplate(dto: $0, workoutTemplate: workoutTemplate)
        }
        
        workoutTemplate.updatedAt = updateAt
        workoutTemplate.needsSync = false
        workoutTemplate.isDeletedRemotely = false
        
        context.insert(workoutTemplate)
        try context.save()
        
        modelById[workoutTemplate.id] = workoutTemplate
        let dto = toDTO(workoutTemplate)
        dtoById[workoutTemplate.id] = dto
        
        broadcast(diff: .init(inserted: [workoutTemplate.id]))
    }
    
    private func broadcast(diff: EntityDiff<UUID>) {
        guard booted else { return }
        
        let targets = Array(diffContinuations.values)
        
        for cont in targets {
            cont.yield(diff)
        }
    }
    
    private func dtoToExerciseTemplate(dto: ExerciseTemplateDTO, workoutTemplate: WorkoutTemplate) throws -> ExerciseTemplate {
        let exercise = try resolveExercise(id: dto.exerciseId)
        let et = ExerciseTemplate(exercise: exercise, workoutTemplate: workoutTemplate, order: dto.order)
        et.settings = dto.settings
        et.setTemplates = dto.sets.map { dtoToSetTemplate(dto: $0, exerciseTemplate: et) }
        return et
    }

    private func dtoToSetTemplate(dto: SetTemplateDTO, exerciseTemplate: ExerciseTemplate) -> SetTemplate {
        let st = SetTemplate(exerciseTemplate: exerciseTemplate, order: dto.order)
        st.weightTarget = dto.weightTarget
        st.minReps = dto.minReps
        st.maxReps = dto.maxReps
        st.setType = dto.setType
        st.restTemplate = dto.restTemplate
        return st
    }

    private func toDTO(_ model: WorkoutTemplate) -> WorkoutTemplateDTO {
        WorkoutTemplateDTO(
            id: model.id,
            version: dtoFingerprint(
                name: model.name,
                muscleGroupsIDs: model.muscleGroups.map(\.id),
                exerciseTemplates: model.exerciseTemplates
            ),
            name: model.name,
            muscleGroupsIDs: model.muscleGroups.map(\.id),
            exerciseTemplates: model.exerciseTemplates.map {
                ExerciseTemplateDTO(
                    id: $0.id,
                    exerciseId: $0.exercise.id,
                    order: $0.order,
                    sets: $0.setTemplates.map {
                        SetTemplateDTO(
                            id: $0.id,
                            order: $0.order,
                            weightTarget: $0.weightTarget,
                            minReps: $0.minReps,
                            maxReps: $0.maxReps,
                            setType: $0.setType,
                            restTemplate: $0.restTemplate
                        )
                    },
                    settings: $0.settings,
                    notes: $0.notes
                )
            }
        )
    }

    private func dtoFingerprint(
        name: String,
        muscleGroupsIDs: [UUID],
        exerciseTemplates: [ExerciseTemplate]
    ) -> Int {
        var hasher = Hasher()
        hasher.combine(name)
        for id in muscleGroupsIDs {
            hasher.combine(id)
        }
        for exerciseTemplate in exerciseTemplates.sorted(by: { $0.order < $1.order }) {
            hasher.combine(exerciseTemplate.id)
            hasher.combine(exerciseTemplate.exercise.id)
            hasher.combine(exerciseTemplate.order)
            for setTemplate in exerciseTemplate.setTemplates.sorted(by: { $0.order < $1.order }) {
                hasher.combine(setTemplate.id)
                hasher.combine(setTemplate.order)
                hasher.combine(setTemplate.weightTarget)
                hasher.combine(setTemplate.minReps)
                hasher.combine(setTemplate.maxReps)
                hasher.combine(setTemplate.setType.rawValue)
                hasher.combine(setTemplate.restTemplate?.encoded())
            }
            
            hasher.combine(exerciseTemplate.settings.metricType.rawValue)
            hasher.combine(exerciseTemplate.settings.useRestTimer)
            hasher.combine(exerciseTemplate.settings.setRestDuration)
            hasher.combine(exerciseTemplate.settings.useWarmupRestTimer)
            hasher.combine(exerciseTemplate.settings.warmupRestDuration)
        }
        return hasher.finalize()
    }

    private func resolveMuscleGroup(id: UUID) throws -> MuscleGroup {
        let pred = #Predicate<MuscleGroup> { $0.id == id }
        if let mg = try context.fetch(FetchDescriptor<MuscleGroup>(predicate: pred)).first { return mg }
        throw NSError(domain: "TemplateRepository", code: 3,
                      userInfo: [NSLocalizedDescriptionKey: "MuscleGroup not found"])
    }

    private func resolveMuscleGroups(ids: [UUID]) throws -> [UUID: MuscleGroup] {
        guard !ids.isEmpty else { return [:] }
        
        let pred = #Predicate<MuscleGroup> { ids.contains($0.id) }
        let fetched = try context.fetch(FetchDescriptor<MuscleGroup>(predicate: pred))
        return Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
    }
    
    private func resolveExercise(id: UUID) throws -> Exercise {
        let pred = #Predicate<Exercise> { $0.id == id }
        if let ex = try context.fetch(FetchDescriptor<Exercise>(predicate: pred)).first { return ex }
        throw NSError(domain: "TemplateRepository", code: 4,
                      userInfo: [NSLocalizedDescriptionKey: "Exercise not found"])
    }

    private func resolveExercises(ids: [UUID]) throws -> [UUID: Exercise] {
        guard !ids.isEmpty else { return [:] }
        let pred = #Predicate<Exercise> { ids.contains($0.id) }
        let fetched = try context.fetch(FetchDescriptor<Exercise>(predicate: pred))
        return Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
    }
}
