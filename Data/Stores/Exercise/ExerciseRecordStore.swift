import Foundation
import Combine

struct ExerciseRecord: Identifiable, Equatable {
    
    var id: String {
        "\(reps)-\(weight)-\(performedAt)"
    }
    
    let reps: Int
    let weight: Double
    let performedAt: Date
}

@MainActor
final class ExerciseRecordStore: ObservableObject {
    @Published private(set) var records: [ExerciseRecord] = []
    
    private let exerciseId: UUID
    private let sessionProvider: SessionProvider
    private var task: Task<Void, Never>?
    
    init (exerciseId: UUID, sessionProvider: SessionProvider) {
        self.exerciseId = exerciseId
        self.sessionProvider = sessionProvider
        self.boot()
    }
    
    deinit {
        task?.cancel()
    }
    
    private func boot () {
        guard task == nil else { return }
        
        task = Task { [weak self] in
            guard let self else { return }
            
            for await sessions in await sessionProvider.streamAll() {
                let mapped = Self.map(
                    sessions: sessions,
                    for: exerciseId
                )
                
                await MainActor.run {
                    self.records = mapped
                }
            }
        }
    }
    
    private static func map (sessions: [WorkoutSessionDTO], for exerciseId: UUID) -> [ExerciseRecord] {
        var bestByReps: [Int: ExerciseRecord] = [:]
        
        for session in sessions {
            let performedAt = session.endedAt ?? session.startedAt
            
            guard let exercise = session.exercises.first(where: { $0.exerciseId == exerciseId }) else { continue }
            
            for set in exercise.sets {
                guard set.setType != .warmup, set.reps > 0, set.weight > 0 else { continue }
                
                let reps = set.reps
                
                let candidate = ExerciseRecord(
                    reps: reps,
                    weight: set.weight,
                    performedAt: performedAt
                )
                
                if let existing = bestByReps[reps] {
                    if candidate.weight > existing.weight {
                        bestByReps[reps] = candidate
                    }
                }else {
                    bestByReps[reps] = candidate
                }
            }
        }
        
        return bestByReps.values.sorted { $0.reps < $1.reps }
    }
}
