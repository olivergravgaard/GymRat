import Foundation

struct ExerciseDTO: Identifiable & Sendable & Hashable {
    var id: UUID
    var version: Int
    var name: String
    var muscleGroupID: UUID
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(version)
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.version == rhs.version
    }
}
