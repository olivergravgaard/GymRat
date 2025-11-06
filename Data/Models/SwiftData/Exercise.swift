import SwiftData
import Foundation

@Model
final class Exercise: Equatable & Identifiable {
    var id: UUID
    @Attribute(.unique) var name: String
    @Relationship var muscleGroup: MuscleGroup
    @Relationship(deleteRule: .cascade, inverse: \ExerciseTemplate.exercise) var exerciseTemplates: [ExerciseTemplate] = []
    @Relationship(deleteRule: .cascade, inverse: \ExerciseSession.exercise) var exerciseessions: [ExerciseSession] = []
    
    init (name: String, muscleGoup: MuscleGroup, isPredefined: Bool) {
        self.id = UUID()
        self.name = name
        self.muscleGroup = muscleGoup
    }
}
