import Foundation
import Combine

nonisolated protocol ExerciseChildEditStore: ObservableObject, Identifiable {
    associatedtype DTO: ExerciseChildDTO
    func setMetric (_ metricType: MetricType)
    func setWarmupRestDuration (_ value: Int)
    func addNote (_ text: String)
    func addSet (_ setType: SetType)
    func addSets (setType: SetType, count: Int)
    func updateRestTimers (warmup: Int?, working: Int?)
    func addMissingRest ()
    func removeSet (_ id: UUID)
    func setOrder (_ order: Int)
    func snapshot () -> DTO
    func deleteSelf()
    func replaceExercise (with newExerciseId: UUID, resetSets: Bool)
    var exerciseChildDTO: DTO { get }
}
