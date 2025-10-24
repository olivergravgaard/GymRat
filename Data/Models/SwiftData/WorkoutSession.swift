import SwiftData
import Foundation

@Model
final class WorkoutSession: Equatable, Identifiable {
    var id: UUID
    var name: String
    var startedAt: Date
    var endedAt: Date?
    @Relationship var muscleGroups: [MuscleGroup]
    @Relationship(deleteRule: .cascade, inverse: \ExerciseSession.workoutSession) var exerciseSessions: [ExerciseSession] = []
    
    init () {
        self.id = UUID()
        self.name = ""
        self.muscleGroups = []
        self.exerciseSessions = []
        self.startedAt = .now
        self.endedAt = endedAt
    }
}
