import SwiftData
import Foundation

@MainActor
final class TemplateRepository {
    typealias DTO = WorkoutTemplateDTO

    private let context: ModelContext

    private var modelById: [UUID: WorkoutTemplate] = [:]
    private var dtoById:   [UUID: DTO]              = [:]
    private var booted = false

    private var diffContinuations: [UUID: AsyncStream<EntityDiff<UUID>>.Continuation] = [:]

    init(context: ModelContext) {
        self.context = context
    }
    
    func boot() async throws {
        guard !booted else { return }
        let all = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        modelById = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        dtoById   = Dictionary(uniqueKeysWithValues: all.map { ($0.id, toDTO($0)) })
        booted = true
    }

    func snapshotDTOs() async -> [DTO] {
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

    private func broadcast(diff: EntityDiff<UUID>) {
        let targets = Array(diffContinuations.values)
        Task.detached { for cont in targets { cont.yield(diff) } }
    }

    func fetchDTOs(ids: [UUID]) async throws -> [DTO] {
        guard !ids.isEmpty else { return [] }

        var result: [DTO] = []
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

    func fetchDTOByName(_ name: String) async throws -> DTO? {
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
    
    func restoreTemplate(from dto: DTO) async throws {
        guard let model = modelById[dto.id] else { return }

        // name
        if model.name != dto.name { model.name = dto.name }

        // muscle groups
        let desiredMGs = Set(dto.muscleGroupsIDs)
        if desiredMGs != Set(model.muscleGroups.map(\.id)) {
            let mgById = try resolveMuscleGroups(ids: Array(desiredMGs))
            model.muscleGroups = dto.muscleGroupsIDs.compactMap { mgById[$0] }
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
                st.order        = stDTO.order
                st.weightTarget = stDTO.weightTarget
                st.minReps      = stDTO.minReps
                st.maxReps      = stDTO.maxReps
                st.setType      = stDTO.setType
                st.restTemplate = stDTO.restTemplate

                finalSTs.append(st)
            }

            finalSTs.sort { $0.order < $1.order }
            et.setTemplates = finalSTs
            finalETs.append(et)
        }

        finalETs.sort { $0.order < $1.order }
        model.exerciseTemplates = finalETs

        try context.save()

        let updatedDTO = toDTO(model)
        dtoById[model.id] = updatedDTO
        broadcast(diff: .init(updated: [model.id]))
    }

    func create(name: String, muscleGroupIDs: [UUID]) async throws -> DTO {
        if let _ = try await fetchDTOByName(name) {
            throw NSError(domain: "TemplateRepository", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Name already exists"])
        }
        let mgs = try muscleGroupIDs.map { try resolveMuscleGroup(id: $0) }
        let wt = WorkoutTemplate(name: name, muscleGroups: mgs)
        context.insert(wt)
        try context.save()

        let dto = toDTO(wt)
        modelById[wt.id] = wt
        dtoById[wt.id]   = dto

        broadcast(diff: .init(inserted: [wt.id]))
        return dto
    }

    func create(dto: DTO) async throws {
        let mgs = try dto.muscleGroupsIDs.map { try resolveMuscleGroup(id: $0) }
        let wt = WorkoutTemplate(name: dto.name, muscleGroups: mgs)
        wt.exerciseTemplates = try dto.exerciseTemplates.map { try dtoToExerciseTemplate(dto: $0, workoutTemplate: wt) }

        context.insert(wt)
        try context.save()

        let dto = toDTO(wt)
        dtoById[wt.id]   = dto
        modelById[wt.id] = wt

        broadcast(diff: .init(inserted: [wt.id]))
    }

    func rename(id: UUID, to newName: String) async throws {
        guard let wt = modelById[id] else { return }
        guard wt.name != newName else { return }

        if let existing = try await fetchDTOByName(newName), existing.id != id {
            throw NSError(domain: "TemplateRepository", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Name already exists"])
        }

        wt.name = newName
        try context.save()

        dtoById[id] = toDTO(wt)
        broadcast(diff: .init(updated: [id]))
    }

    func changeMuscleGroup(id: UUID, to muscleGroupIDs: [UUID]) async throws {
        guard let wt = modelById[id] else { return }

        let newSet = Set(muscleGroupIDs)
        let currentSet = Set(wt.muscleGroups.map(\.id))
        guard newSet != currentSet else { return }

        let mgs = try muscleGroupIDs.map { try resolveMuscleGroup(id: $0) }
        wt.muscleGroups = mgs
        try context.save()

        dtoById[id] = toDTO(wt)
        broadcast(diff: .init(updated: [id]))
    }

    func delete(id: UUID) async throws {
        guard let wt = modelById[id] else { return }
        context.delete(wt)
        try context.save()

        modelById[id] = nil
        dtoById[id]   = nil

        broadcast(diff: .init(deleted: [id]))
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
        st.minReps      = dto.minReps
        st.maxReps      = dto.maxReps
        st.setType      = dto.setType
        st.restTemplate = dto.restTemplate
        return st
    }

    private func toDTO(_ m: WorkoutTemplate) -> DTO {
        let dto = DTO(
            id: m.id,
            version: dtoFingerprint(
                name: m.name,
                mgIDs: m.muscleGroups.map(\.id),
                ets: m.exerciseTemplates
            ),
            name: m.name,
            muscleGroupsIDs: m.muscleGroups.map(\.id),
            exerciseTemplates: m.exerciseTemplates.map {
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
                    settings: $0.settings
                )
            }
        )
        return dto
    }

    private func dtoFingerprint(name: String, mgIDs: [UUID], ets: [ExerciseTemplate]) -> Int {
        var hasher = Hasher()
        hasher.combine(name)
        for id in mgIDs { hasher.combine(id) }
        for et in ets.sorted(by: { $0.order < $1.order }) {
            hasher.combine(et.id)
            hasher.combine(et.exercise.id)
            hasher.combine(et.order)
            for st in et.setTemplates.sorted(by: { $0.order < $1.order }) {
                hasher.combine(st.id)
                hasher.combine(st.order)
                hasher.combine(st.weightTarget)
                hasher.combine(st.minReps)
                hasher.combine(st.maxReps)
                hasher.combine(st.setType.rawValue)
                hasher.combine(st.restTemplate?.encoded()) // Needs to be changed
            }
            // settings påvirker også fingerprint
            hasher.combine(et.settings.metricType.rawValue)
            hasher.combine(et.settings.useRestTimer)
            hasher.combine(et.settings.setRestDuration)
            hasher.combine(et.settings.useWarmupRestTimer)
            hasher.combine(et.settings.warmupRestDuration)
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
