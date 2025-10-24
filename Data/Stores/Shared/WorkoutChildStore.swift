import Combine
import Foundation

@MainActor
protocol WorkoutChildStore: ObservableObject {
    func addExercise (_ exerciseId: UUID)
    func addExercises (_ exercisesIds: Set<UUID>)
    func removeExercise (_ id: UUID)
    func replaceExercise (id: UUID, with replacementId: UUID, resetSets: Bool)
    func updateExercisesOrder (_ mapping: [UUID: Int])
}
