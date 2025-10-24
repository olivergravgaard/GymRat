import SwiftData
import Foundation

@Model
final class MuscleGroup: Equatable, Identifiable {
    var id: UUID
    @Attribute(.unique) var name: String
    var isPredefined: Bool
    @Relationship(deleteRule: .cascade, inverse: \Exercise.muscleGroup) var exercises: [Exercise] = []
    @Relationship(deleteRule: .nullify, inverse: \WorkoutTemplate.muscleGroups) var workoutTemplates: [WorkoutTemplate] = []
    
    init (name: String, isPredefined: Bool) {
        self.id = UUID()
        self.name = name
        self.isPredefined = isPredefined
    }
}

