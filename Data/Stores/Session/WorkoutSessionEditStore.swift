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
    
    lazy var restOrchestrator: RestSessionOrchestrator = {
        RestSessionOrchestrator(onFinish: { [weak self] completion in
            guard let self else { return }
            if let loc = self.locateSetDTO(completion.setId) {
                var dto = self.exerciseSessions[loc.exerciseIdx].setSessions[loc.setIdx].setDTO
                if var r = dto.restSession {
                    r.endedAt = completion.endedAt
                    r.restState = .completed
                    dto.restSession = r
                    self.exerciseSessions[loc.exerciseIdx].setSessions[loc.setIdx].setDTO = dto
                    self.childDidChange()
                }
            }
        })
    }()
    
    init (draftStore: SessionDraftStore, repo: SessionRepository) {
        self.id = nil
        self.sessionDTO = nil
        self.draftStore = draftStore
        self.repo = repo
    }
    
    func restoreRunningRestIfAny() {
        var running: (setId: UUID, duration: Int, startedAt: Date)?
        
        for ex in exerciseSessions {
            for setStore in ex.setSessions {
                if let r = setStore.setDTO.restSession,
                   r.restState == .running,
                   let started = r.startedAt {
                    if running == nil || started > running!.startedAt {
                        running = (setStore.id, r.duration, started)
                    }
                }
            }
        }
        
        if let r = running {
            Task {
                await restOrchestrator.restoreIfNeeded(
                    setId: r.setId,
                    total: r.duration,
                    startedAt: r.startedAt
                )
            }
        }
    }

    // Hjælpere til at finde set
    private struct SetLocator { let exerciseIdx: Int; let setIdx: Int }
    private func locateSetDTO(_ setId: UUID) -> SetLocator? {
        for (ei, ex) in exerciseSessions.enumerated() {
            if let si = ex.setSessions.firstIndex(where: { $0.id == setId }) {
                return .init(exerciseIdx: ei, setIdx: si)
            }
        }
        return nil
    }
    
    func boot (dto: WorkoutSessionDTO) {
        Task {
            self.id = dto.id
            self.sessionDTO = dto
            self.exerciseSessions = dto.exercises
                .sorted(by: { $0.order < $1.order })
                .map{
                    ExerciseSessionEditStore(
                        dto: $0,
                        lastPerfomedDTO: repo.lastPerformedExerciseSessionDTO(for: $0.exerciseId),
                        delegate: self,
                        parentEditStore: self
                    )
                }
            
            restoreRunningRestIfAny()
        }
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
            sets: [],
            notes: []
        )
        
        let store = ExerciseSessionEditStore(
            dto: dto,
            lastPerfomedDTO: repo.lastPerformedExerciseSessionDTO(for: exerciseId),
            delegate: self,
            parentEditStore: self
        )
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
                sets: [],
                notes: []
            )
            
            exerciseSessions.append(
                ExerciseSessionEditStore(
                    dto: dto,
                    lastPerfomedDTO: repo.lastPerformedExerciseSessionDTO(for: exerciseId),
                    delegate: self,
                    parentEditStore: self
                )
            )
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
            
            try repo.persistAndFinishSession(from: out)
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
    func markAllSetsAsPerformed () async {
        for exerciseSession in exerciseSessions {
            exerciseSession.markAllSetsAsPerformed()
        }
    }
    
    // Should not trigger childDidChange
    func discardAllUnperformedSets () async {
        for exerciseSession in exerciseSessions {
            if exerciseSession.hasNoPerformedSets {
                removeExercise(exerciseSession.id)
            }else {
                exerciseSession.discardAllUnperformedSets()
            }
        }
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
            e.setOrder(i + 1)
        }
    }
    
}
