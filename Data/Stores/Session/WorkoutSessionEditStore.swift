import Foundation
import Combine

@MainActor
protocol WorkoutSessionChildDelegate: WorkoutChildStore {
    func childDidChange()
}

@MainActor
final class WorkoutSessionEditStore: WorkoutSessionChildDelegate {
    
    @Published private(set) var id: UUID?
    @Published private(set) var sessionDTO: WorkoutSessionDTO?
    @Published private(set) var exerciseSessions: [ExerciseSessionEditStore] = []
    @Published private(set) var isFinishing: Bool = false
    @Published private(set) var finishError: Error?
    
    private let draftStore: SessionDraftStore
    private let repo: SessionRepository
    
    private var isDirty: Bool = false
    private var persistTask: Task<Void, Never>?
    private var lastKick: ContinuousClock.Instant?
    private let debounce: Duration = .milliseconds(2000)
    private let maxCoalesce: Duration = .seconds(4)
    
    init (draftStore: SessionDraftStore, repo: SessionRepository) {
        self.id = nil
        self.sessionDTO = nil
        self.draftStore = draftStore
        self.repo = repo
    }
    
    func boot (dto: WorkoutSessionDTO) {
        self.id = dto.id
        self.sessionDTO = dto
        self.exerciseSessions = dto.exercises
            .sorted(by: { $0.order < $1.order })
            .map{ ExerciseSessionEditStore(dto: $0, delegate: self, parentEditStore: self )}
    }
    
    func childDidChange() {
        markDirty()
    }
    
    func addExercise(_ exerciseId: UUID) {
        let nextOrder = (exerciseSessions.map { $0.exerciseChildDTO.order}.max() ?? 0) + 1
        let dto = ExerciseSessionDTO(
            id: UUID(),
            exerciseId: exerciseId,
            order: nextOrder,
            settings: ExerciseSettings.defaultSettings,
            sets: []
        )
        
        let store = ExerciseSessionEditStore(dto: dto, delegate: self, parentEditStore: self)
        exerciseSessions.append(store)
        markDirty()
    }
    
    func addExercises(_ exercisesIds: Set<UUID>) {
        guard !exercisesIds.isEmpty else { return }
        var nextOrder = (exerciseSessions.map { $0.exerciseChildDTO.order}.max() ?? 0) + 1
        for exerciseId in exercisesIds {
            let dto = ExerciseSessionDTO(
                id: UUID(),
                exerciseId: exerciseId,
                order: nextOrder,
                settings: .defaultSettings,
                sets: []
            )
            
            exerciseSessions.append(ExerciseSessionEditStore(dto: dto, delegate: self, parentEditStore: self))
            nextOrder += 1
        }
        
        markDirty()
    }
    
    func removeExercise(_ id: UUID) {
        exerciseSessions.removeAll { $0.id == id }
        normalizeOrder()
        
        markDirty()
    }
    
    func replaceExercise(id: UUID, with replacementId: UUID, resetSets: Bool) {
        guard let idx = exerciseSessions.firstIndex(where: { $0.id == id}) else { return }
        exerciseSessions[idx].replaceExercise(with: replacementId, resetSets: resetSets)
        
        markDirty()
    }
    
    func updateExercisesOrder(_ mapping: [UUID : Int]) {
        for exerciseSession in exerciseSessions {
            if let newOrder = mapping[exerciseSession.id] {
                exerciseSession.setOrder(newOrder)
            }
        }
        
        exerciseSessions.sort { $0.exerciseChildDTO.order < $1.exerciseChildDTO.order }
        
        markDirty()
    }
    
    @discardableResult
    func finish () async throws -> Bool {
        guard !isFinishing else { return false }
        isFinishing = true
        finishError = nil
        
        defer { isFinishing = false}
        
        do {
            try await flushPersistNow()
            guard let out = snapshot() else { return false }
            
            try await repo.persistAndFinishSession(from: out)
            await draftStore.clear()
            
            self.id = nil
            self.sessionDTO = nil
            self.exerciseSessions = []
            
            return true
        }catch {
            finishError = error
            return false
        }
    }
    
    // Should not trigger childDidChange
    func markAllSetsAsPerformed () async -> Bool {
        for exerciseSession in exerciseSessions {
            exerciseSession.markAllSetsAsPerformed()
        }
        
        return true
    }
    
    // Should not trigger childDidChange
    func discardAllUnperformedSets () async -> Bool {
        for exerciseSession in exerciseSessions {
            if exerciseSession.hasNoPerformedSets {
                removeExercise(exerciseSession.id)
            }else {
                exerciseSession.discardAllUnperformedSets()
            }
        }
        
        return true
    }
    
    func cancel () async -> Bool {
        await draftStore.clear()
        return true
    }
    
    func getGlobalFieldsOrder () async -> [UUID] {
        var final: [UUID] = []
        
        for exerciseSession in exerciseSessions {
            final.append(contentsOf: exerciseSession.getLocalFieldsOrder())
        }
        
        return final
    }
    
    
    func getFieldIndex (for id: UUID) async -> Int? {
        let fieldsOrder: [UUID] = await self.getGlobalFieldsOrder()
        
        return fieldsOrder.firstIndex(of: id)
    }
    
    var hasUnperformedSets: Bool {
        return exerciseSessions.contains { $0.hasUnperformedSets }
    }
    
    var unperformedSetsCount: Int {
        exerciseSessions.reduce(0) { acc, exerciseSession in
            acc + exerciseSession.setSessions.reduce(0) {
                $0 + ($1.setDTO.performed ? 0 : 1)
            }
        }
    }
    
    private func markDirty (forceImmediate: Bool = false) {
        isDirty = true
        
        if forceImmediate {
            persistTask?.cancel()
            persistTask = Task { [weak self] in
                try? await self?.flushPersistNow()
            }
            return
        }
        
        let now = ContinuousClock().now
        lastKick = now
        
        persistTask?.cancel()
        persistTask = Task { [weak self, debounce, maxCoalesce] in
            guard let self else { return }
            try? await Task.sleep(for: debounce)
            
            if let first = self.lastKick, now.duration(to: first) > maxCoalesce {
                await self.flushPersistIfNeeded()
                return
            }
            
            await self.flushPersistIfNeeded()
        }
    }
    
    private func flushPersistIfNeeded() async {
        guard isDirty, let snap = snapshot() else { return }
        isDirty = false
        await draftStore.replace(snap)
    }

    private func flushPersistNow() async throws {
        persistTask?.cancel()
        guard let snap = snapshot() else { return }
        isDirty = false
        await draftStore.replace(snap, persistImmediately: true)
    }
    
    private func snapshot () -> WorkoutSessionDTO? {
        guard var out = sessionDTO else { return nil }
        out.exercises = exerciseSessions
            .map { $0.snapshot() }
            .sorted { $0.order < $1.order }
        
        return out
    }
    
    private func normalizeOrder () {
        for (i, e) in exerciseSessions.enumerated() {
            e.setOrder(i)
        }
    }
    
}
