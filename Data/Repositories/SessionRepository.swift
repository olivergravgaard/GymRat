import SwiftData
import Foundation

actor SessionRepository {
    private let context: ModelContext
    private var booted: Bool = false
    
    init (context: ModelContext) {
        self.context = context
    }
    
    func boot () async throws {
        guard !booted else { return }
        booted = true
    }
    
    func persistAndFinishSession (from dto: WorkoutSessionDTO) async throws {
        let endedAt: Date = .now
        
        try await boot()
        
        let muscleGroupsById = try resolveMuscleGroups(ids: dto.muscleGroupIDs)
        let exercisesById = try resolveExercises(ids: dto.exercises.map(\.exerciseId))
        
        let workoutSession = WorkoutSession()
        workoutSession.name = dto.name
        workoutSession.muscleGroups = dto.muscleGroupIDs.compactMap { muscleGroupsById[$0] }
        workoutSession.startedAt = dto.startedAt
        workoutSession.endedAt = endedAt
        
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
        }
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
