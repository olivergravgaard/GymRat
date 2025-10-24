import SwiftData
import Foundation

@Model
final class ExerciseSession: Equatable, Identifiable {
    var id: UUID
    @Relationship var exercise: Exercise
    @Relationship var workoutSession: WorkoutSession
    var order: Int
    @Relationship(deleteRule: .cascade, inverse: \SetSession.exerciseSession) var setSessions: [SetSession]
    
    @Attribute(.externalStorage) private var settingsData: Data
    var settings: ExerciseSettings {
        get {
            ExerciseSettings.decode(from: settingsData)
        }set {
            settingsData = newValue.encoded()
        }
    }
    
    init (exercise: Exercise, workoutSession: WorkoutSession, order: Int) {
        self.id = UUID()
        self.exercise = exercise
        self.workoutSession = workoutSession
        self.order = order
        self.setSessions = []
        self.settingsData = ExerciseSettings.defaultSettings.encoded()
    }
}
