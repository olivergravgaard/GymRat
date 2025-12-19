import Foundation
import FirebaseFirestore

struct ExerciseDTO: Identifiable & Sendable & Hashable {
    var id: UUID
    var version: Int
    var name: String
    var muscleGroupID: UUID
    
    var origin: ExerciseOrigin
    var catalogId: String?
    var isBuiltin: Bool { origin == .builtin}
    var isCustom: Bool { origin == .custom }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(version)
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.version == rhs.version
    }
}

struct RemoteExerciseDTO: Codable {
    @DocumentID var docId: String?
    
    var id: String
    var name: String
    var muscleGroupID: String
    var origin: String
    var updatedAt: Date
    var isDeleted: Bool
}
