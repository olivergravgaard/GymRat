import SwiftData
import Foundation

@Model
final class SetSession: Equatable, Identifiable {
    var id: UUID
    @Relationship var exerciseSession: ExerciseSession
    var order: Int
    var weightTarget: Double?
    var minReps: Int?
    var maxReps: Int?
    var weight: Double
    var reps: Int
    var setType: SetType
    var performed: Bool
    
    @Attribute(.externalStorage) private var restSessionData: Data?
    var restSession: RestSession? {
        get {
            guard let restSessionData else { return nil}
            return RestSession.decode(from: restSessionData)
        } set {
            guard let newValue else {
                restSessionData = nil
                return
            }
            restSessionData = newValue.encoded()
        }
    }
    
    init (exerciseSession: ExerciseSession, order: Int) {
        self.id = UUID()
        self.exerciseSession = exerciseSession
        self.order = order
        self.weightTarget = nil
        self.minReps = nil
        self.maxReps = nil
        self.weight = 0.0
        self.reps = 0
        self.setType = .regular
        self.performed = false
        self.restSessionData = nil
    }
}
