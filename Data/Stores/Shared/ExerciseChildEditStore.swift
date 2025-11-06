import Foundation
import Combine

nonisolated protocol ExerciseChildEditStore: ObservableObject, Identifiable {
    associatedtype DTO: ExerciseChildDTO
    func setMetric (_ metricType: MetricType)
    func toggleWarmupRestTimer (_ value: Bool)
    func setWarmupRestDuration (_ value: Int)
    func addSet (_ setType: SetType)
    func removeSet (_ id: UUID)
    func setOrder (_ order: Int)
    func snapshot () -> DTO
    func deleteSelf()
    func replaceExercise (with newExerciseId: UUID, resetSets: Bool)
    var exerciseChildDTO: DTO { get }
}
