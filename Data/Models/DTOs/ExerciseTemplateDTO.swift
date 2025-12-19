import Foundation

nonisolated protocol ExerciseChildDTO: Identifiable, Equatable, Sendable, Codable {
    associatedtype SetChild: SetChildDTO
    var id: UUID { get set }
    var exerciseId: UUID { get set }
    var order: Int { get set }
    var sets: [SetChild] { get set }
    var settings: ExerciseSettings { get set }
}

struct ExerciseTemplateDTO: ExerciseChildDTO {
    var id: UUID
    var exerciseId: UUID
    var order: Int
    var sets: [SetTemplateDTO]
    var settings: ExerciseSettings
    var notes: [Note]

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}
