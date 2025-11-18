import Foundation

struct ExerciseSessionDTO: ExerciseChildDTO, Codable {
    var id: UUID
    var exerciseId: UUID
    var order: Int
    var settings: ExerciseSettings
    var sets: [SetSessionDTO]
    var notes: [Note]
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}
