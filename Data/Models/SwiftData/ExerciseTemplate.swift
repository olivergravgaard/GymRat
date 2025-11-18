import SwiftData
import Foundation

@Model
final class ExerciseTemplate: Equatable, Identifiable {
    var id: UUID
    @Relationship var exercise: Exercise
    @Relationship var workoutTemplate: WorkoutTemplate
    var order: Int
    @Relationship(deleteRule: .cascade, inverse: \SetTemplate.exerciseTemplate) var setTemplates: [SetTemplate]
    
    @Attribute(.externalStorage) private var settingsData: Data
    var settings: ExerciseSettings {
        get {
            ExerciseSettings.decode(from: settingsData)
        }set {
            settingsData = newValue.encoded()
        }
    }
    
    @Attribute(.externalStorage) private var notesData: Data
    var notes: [Note] {
        get { Note.decodeMany(from: notesData)}
        set { notesData = Note.encodeMany(newValue)}
    }

    init (exercise: Exercise, workoutTemplate: WorkoutTemplate, order: Int) {
        self.id = UUID()
        self.exercise = exercise
        self.workoutTemplate = workoutTemplate
        self.order = order
        self.setTemplates = []
        self.settingsData = ExerciseSettings.defaultSettings.encoded()
        self.notesData = Note.encodeMany([])
    }
    
    func toDTO () -> ExerciseTemplateDTO {
        .init(
            id: self.id,
            exerciseId: self.exercise.id,
            order: self.order,
            sets: self.setTemplates.map({
                $0.toDTO()
            }),
            settings: self.settings,
            notes: self.notes
        )
    }
}
