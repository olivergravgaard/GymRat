import Foundation
import FirebaseFirestore

struct WorkoutTemplateDTO: Identifiable, Hashable, Sendable, Codable {
    var id: UUID
    var version: Int
    var name: String
    var muscleGroupsIDs: [UUID]
    var exerciseTemplates: [ExerciseTemplateDTO]
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(version)
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.version == rhs.version
    }
    
    var totalSets: Int {
        return exerciseTemplates.reduce(0) { partialResult, exerciseTemplate in
            partialResult + exerciseTemplate.sets.count
        }
    }
    
    func estimatedDuration () -> Int {
        guard !exerciseTemplates.isEmpty else { return 0 }
        
        var total: Int = 0
        
        for exerciseTemplate in exerciseTemplates {
            for setTemplate in exerciseTemplate.sets {
                let restDuration = setTemplate.restTemplate?.duration ?? 0
                let minReps: Int? = setTemplate.minReps
                let maxReps: Int? = setTemplate.maxReps
                var reps: Int
                
                if let maxReps {
                    reps = maxReps
                }else if let minReps {
                    reps = minReps
                }else {
                    reps = 8
                }
                
                let work = reps * 2
                
                total += work + restDuration
            }
        }
        
        return total
    }
}

struct RemoteWorkoutTemplateDTO: Codable {
    @DocumentID var docId: String?
    
    var id: String
    var workoutTemplate: WorkoutTemplateDTO
    var updatedAt: Date
    var isDeleted: Bool
}
