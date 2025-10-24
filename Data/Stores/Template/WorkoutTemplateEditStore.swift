import Foundation
import Combine

@MainActor
protocol WorkoutTemplateChildDelegate: WorkoutChildStore {
    func childDidChange()
}

@MainActor
final class WorkoutTemplateEditStore: WorkoutTemplateChildDelegate {
    @Published private(set) var id: UUID
    @Published private(set) var exerciseTemplates: [ExerciseTemplateEditStore] = []
    @Published private(set) var isDirty: Bool = false
    
    private let repo: TemplateRepository
    private let exerciseProvider: ExerciseProvider
    
    init (dto: WorkoutTemplateDTO, repo: TemplateRepository, exerciseProvider: ExerciseProvider) {
        self.id = dto.id
        self.repo = repo
        self.exerciseProvider = exerciseProvider
        self.exerciseTemplates = dto.exerciseTemplates
            .sorted { $0.order < $1.order}
            .map { .init(dto: $0, delegate: self, parentEditStore: self) }
        
        for et in exerciseTemplates {
            et.delegate = self
        }
    }
    
    func childDidChange() {
        isDirty = true
    }
    
    func addExercise (_ exerciseId: UUID) {
        let nextOrder = (exerciseTemplates.map { $0.exerciseChildDTO.order}.max() ?? 0) + 1
        let dto = ExerciseTemplateDTO(
            id: UUID(),
            exerciseId: exerciseId,
            order: nextOrder,
            sets: [],
            settings: ExerciseSettings.defaultSettings
        )
        
        let store = ExerciseTemplateEditStore(dto: dto, delegate: self, parentEditStore: self)
        exerciseTemplates.append(store)
        isDirty = true
    }
    
    func addExercises (_ exercisesIds: Set<UUID>) {
        guard !exercisesIds.isEmpty else { return }
        
        var nextOrder = (exerciseTemplates.map { $0.exerciseChildDTO.order }.max() ?? 0) + 1
        
        exerciseTemplates.reserveCapacity(exerciseTemplates.count + exercisesIds.count)
        
        for exerciseId in exercisesIds {
            let dto = ExerciseTemplateDTO(
                id: UUID(),
                exerciseId: exerciseId,
                order: nextOrder,
                sets: [],
                settings: ExerciseSettings.defaultSettings
            )
            
            let store = ExerciseTemplateEditStore(dto: dto, delegate: self, parentEditStore: self)
            exerciseTemplates.append(store)
            nextOrder += 1
        }
        
        isDirty = true
    }
    
    func removeExercise (_ id: UUID) {
        exerciseTemplates.removeAll { $0.id == id }
        normalizeExerciseOrder()
        isDirty = true
    }
    
    func replaceExercise (id: UUID, with replacementId: UUID, resetSets: Bool) {
        guard let idx = exerciseTemplates.firstIndex(where: { $0.id == id }) else { return }
        
        exerciseTemplates[idx].replaceExercise(with: replacementId, resetSets: resetSets)
        
        isDirty = true
    }
    
    func updateExercisesOrder (_ mapping: [UUID: Int]) {
        for exerciseTemplate  in exerciseTemplates {
            if let newOrder = mapping[exerciseTemplate.id] {
                exerciseTemplate.setOrder(newOrder)
            }
        }
        
        exerciseTemplates.sort { $0.exerciseChildDTO.order < $1.exerciseChildDTO.order }
        isDirty = true
    }
    
    func save (using originalDTO: WorkoutTemplateDTO) async throws {
        let out = WorkoutTemplateDTO(
            id: id,
            version: originalDTO.version,
            name: originalDTO.name,
            muscleGroupsIDs: originalDTO.muscleGroupsIDs,
            exerciseTemplates: exerciseTemplates.map { $0.snapshot() }.sorted { $0.order < $1.order }
        )
        
        _ = try await repo.restoreTemplate(from: out)
        isDirty = false
    }
    
    func getGlobalFieldsOrder () async -> [UUID] {
        var final: [UUID] = []
        
        for exerciseTemplate in exerciseTemplates {
            final.append(contentsOf: exerciseTemplate.getLocalFieldsOrder())
        }
        
        return final
    }
    
    private func normalizeExerciseOrder () {
        for (i, e) in exerciseTemplates.enumerated() {
            e.setOrder(i)
        }
    }
}
