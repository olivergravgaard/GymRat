import SwiftData
import Foundation

@Model
final class WorkoutTemplate: Equatable, Identifiable {
    var id: UUID
    @Attribute(.unique) var name: String
    @Relationship var muscleGroups: [MuscleGroup]
    @Relationship(deleteRule: .cascade, inverse: \ExerciseTemplate.workoutTemplate) var exerciseTemplates: [ExerciseTemplate] = []
    
    init (name: String, muscleGroups: [MuscleGroup]) {
        self.id = UUID()
        self.name = name
        self.muscleGroups = muscleGroups
    }
}
