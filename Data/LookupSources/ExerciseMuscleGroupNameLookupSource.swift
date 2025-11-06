import Foundation
import Combine

@MainActor
final class ExerciseMuscleGroupNameLookupSource: ObservableObject {
    @Published private(set) var muscleGroupNameByExerciseId: [UUID: String] = [:]
    
    init (
        exerciseLookup: ExerciseLookupSource,
        muscleGroupLookup: MuscleGroupLookupSource
    ) {
        exerciseLookup.$muscleGroupIDs
            .combineLatest(muscleGroupLookup.$names)
            .map { exerciseIdToMuscleGroupId, muscleGroupIdToName  -> [UUID: String] in
                var out: [UUID: String] = [:]
                out.reserveCapacity(exerciseIdToMuscleGroupId.count)
                for (exerciseId, muscleGroupId) in exerciseIdToMuscleGroupId {
                    if let name = muscleGroupIdToName[muscleGroupId] {
                        out[exerciseId] = name
                    }
                }
                return out
            }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .assign(to: &$muscleGroupNameByExerciseId)
    }
    
    func muscleGroupName(for exerciseId: UUID) -> String? {
        muscleGroupNameByExerciseId[exerciseId]
    }

}
