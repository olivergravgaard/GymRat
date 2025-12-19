import SwiftData
import Foundation

@Model
final class MuscleGroup: Equatable, Identifiable {
    var id: UUID
    @Attribute(.unique) var name: String
    var isBuiltin: Bool
    @Relationship(deleteRule: .cascade, inverse: \Exercise.muscleGroup) var exercises: [Exercise] = []
    @Relationship(deleteRule: .nullify, inverse: \WorkoutTemplate.muscleGroups) var workoutTemplates: [WorkoutTemplate] = []
    
    init (
        id: UUID,
        name: String,
        isBuiltin: Bool
    ) {
        self.id = id
        self.name = name
        self.isBuiltin = isBuiltin
    }
}

