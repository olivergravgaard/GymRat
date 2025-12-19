import SwiftData
import Foundation

@MainActor
final class SessionRepository {
    private let context: ModelContext
    private var booted: Bool = false
    
    private var modelById: [UUID: WorkoutSession] = [:]
    private var dtoById: [UUID: WorkoutSessionDTO] = [:]
    
    private var diffSubscribers: [UUID: AsyncStream<EntityDiff<UUID>>.Continuation] = [:]
    private var pendingSubscribers: [UUID: AsyncStream<EntityDiff<UUID>>.Continuation] = [:]
    
    init (context: ModelContext) {
        self.context = context
    }
    
    func boot () async throws {
        guard !booted else { return }
        
        let all = try context.fetch(FetchDescriptor<WorkoutSession>())
        modelById = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0 )})
        dtoById = Dictionary(uniqueKeysWithValues: all.map { ($0.id, toDTO($0) ) })
        
        booted = true
        
        if !pendingSubscribers.isEmpty {
            for (k, v) in pendingSubscribers { diffSubscribers[k] = v }
            pendingSubscribers.removeAll()
        }
    }
    
    func snapshotDTOs () async -> [WorkoutSessionDTO] {
        Array(dtoById.values)
    }
    
    func snapshotSortedByEndDate () async -> [WorkoutSessionDTO] {
        Array(dtoById.values).sorted { (a, b) in
            let ae = a.endedAt ?? a.startedAt
            let be = b.endedAt ?? b.startedAt
            return ae > be
        }
    }
    
    func streamDiffs () -> AsyncStream<EntityDiff<UUID>> {
        let token = UUID()
        return AsyncStream { c in
            Task { @MainActor in
                if self.booted {
                    self.diffSubscribers[token] = c
                }else {
                    self.pendingSubscribers[token] = c
                }
            }
            
            c.onTermination = { _ in
                Task { @MainActor in
                    self.diffSubscribers[token] = nil
                    self.pendingSubscribers[token] = nil
                }
            }
        }
    }
    
    func persistAndFinishSession (from dto: WorkoutSessionDTO) throws {
        let muscleGroupsById = try resolveMuscleGroups(ids: dto.muscleGroupIDs)
        let exercisesById = try resolveExercises(ids: dto.exercises.map(\.exerciseId))
        
        let workoutSession = WorkoutSession()
        workoutSession.name = dto.name
        workoutSession.muscleGroups = dto.muscleGroupIDs.compactMap { muscleGroupsById[$0] }
        workoutSession.startedAt = dto.startedAt
        workoutSession.endedAt = .now
        
        var exerciseSessions: [ExerciseSession] = []
        exerciseSessions.reserveCapacity(dto.exercises.count)
        
        for exerciseSessionDTO in dto.exercises.sorted(by: { $0.order < $1.order }) {
            guard let exercise = exercisesById[exerciseSessionDTO.exerciseId] else { continue }
            let exerciseSession = ExerciseSession(exercise: exercise, workoutSession: workoutSession, order: exerciseSessionDTO.order)
            exerciseSession.settings = exerciseSessionDTO.settings
            
            var setSessions: [SetSession] = []
            setSessions.reserveCapacity(exerciseSessionDTO.sets.count)
            
            for setSessionDTO in exerciseSessionDTO.sets.sorted(by: { $0.order < $1.order }) {
                let setSession = SetSession(exerciseSession: exerciseSession, order: setSessionDTO.order)
                setSession.weightTarget = setSessionDTO.weightTarget
                setSession.minReps = setSessionDTO.minReps
                setSession.maxReps = setSessionDTO.maxReps
                setSession.weight = setSessionDTO.weight
                setSession.reps = setSessionDTO.reps
                setSession.setType = setSessionDTO.setType
                setSession.performed = setSessionDTO.performed
                setSession.restSession = setSessionDTO.restSession
                
                setSessions.append(setSession)
            }
            
            exerciseSession.setSessions = setSessions
            exerciseSessions.append(exerciseSession)
        }
        
        workoutSession.exerciseSessions = exerciseSessions
        
        try context.transaction {
            context.insert(workoutSession)
            try context.save()
            
            modelById[workoutSession.id] = workoutSession
            let newDTO = toDTO(workoutSession)
            dtoById[workoutSession.id] = newDTO
            broadcast(diff: .init(inserted: [workoutSession.id]))
        }
    }
    
    func fetchDTOs (ids: [UUID]) async throws -> [WorkoutSessionDTO] {
        guard !ids.isEmpty else { return [] }
        
        var result: [WorkoutSessionDTO] = []
        var missing: [UUID] = []
        
        for id in ids {
            if let dto = dtoById[id] { result.append(dto) }
            else { missing.append(id)}
        }
        
        if !missing.isEmpty {
            let fd = FetchDescriptor<WorkoutSession>(predicate: #Predicate { missing.contains($0.id) })
            let rows = try context.fetch(fd)
            
            for m in rows {
                modelById[m.id] = m
                let dto = toDTO(m)
                dtoById[m.id] = dto
                result.append(dto)
            }
        }
        
        return result
    }
    
    func lastPerformedExerciseSessionDTO (for exerciseId: UUID) -> ExerciseSessionDTO? {
        let pred = #Predicate<ExerciseSession> { es in
            es.exercise.id == exerciseId
        }
        
        var desc = FetchDescriptor<ExerciseSession>(
            predicate: pred,
            sortBy: [SortDescriptor(\.workoutSession.startedAt, order: .reverse)]
        )
        
        desc.fetchLimit = 1
        
        guard let model = try? context.fetch(desc).first else { return nil }
        return model.toDTO()
    }
    
    func delete (id: UUID) throws {
        try context.transaction {
            let model: WorkoutSession
            
            if let cached = modelById[id] {
                model = cached
            }else {
                let pred = #Predicate<WorkoutSession> { $0.id == id}
                let fd = FetchDescriptor<WorkoutSession>(predicate: pred)
                guard let fetched = try context.fetch(fd).first else {
                    return
                }
                
                model = fetched
            }
            
            context.delete(model)
            try context.save()
            
            modelById[id] = nil
            dtoById[id] = nil
            
            broadcast(diff: .init(deleted: [id]))
        }
    }
    
    func reset () {
        modelById.removeAll()
        dtoById.removeAll()
        booted = false
        
        
        let deletedIDs = Array(dtoById.keys)
        
        modelById.removeAll()
        dtoById.removeAll()
        booted = false
        
        if !deletedIDs.isEmpty {
            broadcast(diff: .init(deleted: deletedIDs))
        }
    }
    
    private func broadcast (diff: EntityDiff<UUID>) {
        guard booted else { return }
        for cont in diffSubscribers.values {
            cont.yield(diff)
        }
    }
    
    private func toDTO(_ m: WorkoutSession) -> WorkoutSessionDTO {
        let dto = WorkoutSessionDTO(
            id: m.id,
            name: m.name,
            startedAt: m.startedAt,
            endedAt: m.endedAt,
            muscleGroupIDs: m.muscleGroups.map(\.id),
            exercises: m.exerciseSessions.map {
                ExerciseSessionDTO(
                    id: $0.id,
                    exerciseId: $0.exercise.id,
                    order: $0.order,
                    settings: $0.settings,
                    sets: $0.setSessions.map {
                        SetSessionDTO(
                            id: $0.id,
                            order: $0.order,
                            weight: $0.weight,
                            reps: $0.reps,
                            setType: $0.setType,
                            performed: $0.performed
                        )
                    },
                    notes: $0.notes
                )
            },
            version: 0
        )
        
        return dto
    }
    
    private func resolveExercises(ids: [UUID]) throws -> [UUID: Exercise] {
        guard !ids.isEmpty else { return [:] }
        let pred = #Predicate<Exercise> { ids.contains($0.id) }
        let fetched = try context.fetch(FetchDescriptor<Exercise>(predicate: pred))
        return Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
    }

    private func resolveMuscleGroups(ids: [UUID]) throws -> [UUID: MuscleGroup] {
        guard !ids.isEmpty else { return [:] }
        let pred = #Predicate<MuscleGroup> { ids.contains($0.id) }
        let fetched = try context.fetch(FetchDescriptor<MuscleGroup>(predicate: pred))
        return Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
    }
}
