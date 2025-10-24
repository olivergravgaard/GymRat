import Foundation

struct WorkoutTemplateDTO: Identifiable & Hashable & Sendable {
    var id: UUID
    var version: Int
    var name: String
    var muscleGroupsIDs: [UUID]
    var exerciseTemplates: [ExerciseTemplateDTO]
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(version)
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.version == rhs.version
    }
}
