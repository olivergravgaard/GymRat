import Foundation

nonisolated struct WorkoutSessionDTO: Equatable, Identifiable, Sendable, Codable {
    var id: UUID
    var name: String
    var startedAt: Date
    var endedAt: Date?
    var muscleGroupIDs: [UUID]
    var exercises: [ExerciseSessionDTO]
    var version: Int
    
    nonisolated static func blank (name: String) -> Self {
        return .init(
            id: UUID(),
            name: name,
            startedAt: .now,
            endedAt: nil,
            muscleGroupIDs: [],
            exercises: [],
            version: 0
        )
    }
    
    nonisolated static func fromTemplate (_ template: WorkoutTemplateDTO) -> Self {
        let exerciseSessionDTOs: [ExerciseSessionDTO] = template.exerciseTemplates
            .sorted(by: { $0.order < $1.order })
            .map {
                .init(
                    id: UUID(),
                    exerciseId: $0.exerciseId,
                    order: $0.order,
                    settings: $0.settings,
                    sets: $0.sets.sorted(by: { $0.order < $1.order }).map {
                        .init(
                            id: UUID(),
                            order: $0.order,
                            weightTarget: $0.weightTarget,
                            minReps: $0.minReps,
                            maxReps: $0.maxReps,
                            weight: 0.0,
                            reps: 0,
                            setType: $0.setType,
                            performed: false,
                            restSession: (
                                $0.restTemplate == nil ? nil : .init(
                                    from: $0.restTemplate!
                                )
                            )
                        )
                    },
                    notes: $0.notes.sorted(by: { $0.order < $1.order })
                )
            }
        
        return .init(
            id: UUID(),
            name: template.name,
            startedAt: .now,
            endedAt: nil,
            muscleGroupIDs: template.muscleGroupsIDs,
            exercises: exerciseSessionDTOs,
            version: 0
        )
    }
    
    var totalSetsCount: Int {
        self.exercises.reduce(0) {
            $0 + $1.sets.count
        }
    }

    var performedSetsCount: Int {
        self.exercises.flatMap(\.sets).reduce(into: 0) { $0 += ($1.performed == true) ? 1 : 0 }
    }
    
    var duration: Int {
        guard let endedAt = endedAt else { return 0 }
        return max(0, Int(endedAt.timeIntervalSince(startedAt)))
    }
}

