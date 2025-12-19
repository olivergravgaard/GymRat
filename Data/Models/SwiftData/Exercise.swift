import SwiftData
import Foundation

enum ExerciseOrigin: String, Codable {
    case builtin
    case custom
    
    var isSyncable: Bool {
        switch self {
        case .builtin:
            return false
        case .custom:
            return true
        }
    }
}

@Model
final class Exercise: Equatable & Identifiable {
    var id: UUID
    @Attribute(.unique) var name: String
    @Relationship var muscleGroup: MuscleGroup
    @Relationship(deleteRule: .cascade, inverse: \ExerciseTemplate.exercise) var exerciseTemplates: [ExerciseTemplate] = []
    @Relationship(deleteRule: .cascade, inverse: \ExerciseSession.exercise) var exerciseessions: [ExerciseSession] = []
    
    private var originRaw: String
    var origin: ExerciseOrigin {
        get { ExerciseOrigin(rawValue: originRaw) ?? .custom }
        set { originRaw = newValue.rawValue }
    }
    
    var ownerId: String?
    var updatedAt: Date
    var needsSync: Bool
    var isDeletedRemotely: Bool
    
    var isBuiltin: Bool { origin == .builtin }
    var isCustom: Bool { origin == .custom }
    
    init (
        id: UUID,
        name: String,
        muscleGoup: MuscleGroup,
        origin: ExerciseOrigin,
        ownerId: String?
    ) {
        self.id = id
        self.name = name
        self.muscleGroup = muscleGoup
        
        self.originRaw = origin.rawValue
        
        self.ownerId = ownerId
        self.updatedAt = Date()
        self.needsSync = origin.isSyncable
        self.isDeletedRemotely = false
    }
}
