import Foundation

nonisolated protocol SetChildDTO: Equatable, Identifiable, Sendable, Codable {
    var id: UUID { get }
    var order: Int { get }
    var weightTarget: Double? { get }
    var minReps: Int? { get }
    var maxReps: Int? { get }
    var setType: SetType { get }
}

struct SetSessionDTO: SetChildDTO {
    var id: UUID
    var order: Int
    var weightTarget: Double?
    var minReps: Int?
    var maxReps: Int?
    var weight: Double
    var reps: Int
    var setType: SetType
    var performed: Bool
    var restSession: RestSession?
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}
