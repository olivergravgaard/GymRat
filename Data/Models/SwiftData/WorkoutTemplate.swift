import SwiftData
import Foundation

@Model
final class WorkoutTemplate: Equatable, Identifiable {
    var id: UUID
    @Attribute(.unique) var name: String
    @Relationship var muscleGroups: [MuscleGroup]
    @Relationship(deleteRule: .cascade, inverse: \ExerciseTemplate.workoutTemplate) var exerciseTemplates: [ExerciseTemplate] = []
    
    var ownerId: String?
    var updatedAt: Date
    var needsSync: Bool
    var isDeletedRemotely: Bool
    
    init (
        name: String,
        muscleGroups: [MuscleGroup],
        ownerId: String?
    ) {
        self.id = UUID()
        self.name = name
        self.muscleGroups = muscleGroups
        
        self.ownerId = ownerId
        self.updatedAt = Date()
        self.needsSync = true
        self.isDeletedRemotely = false
    }
}
