import Foundation
import Combine

@MainActor
final class ExerciseSessionEditStore: ExerciseChildEditStore {
    let id: UUID
    @Published private(set) var exerciseChildDTO: ExerciseSessionDTO
    @Published private(set) var setSessions: [SetSessionEditStore] = []
    
    let parentEditStore: WorkoutSessionEditStore
    
    weak var delegate: (any WorkoutSessionChildDelegate)?
    
    init (dto: ExerciseSessionDTO, delegate: (any WorkoutSessionChildDelegate)?, parentEditStore: WorkoutSessionEditStore) {
        self.id = dto.id
        self.exerciseChildDTO = dto
        self.delegate = delegate
        self.parentEditStore = parentEditStore
        self.setSessions = dto.sets
            .sorted { $0.order < $1.order }
            .map { SetSessionEditStore(dto: $0, delegate: delegate, parentEditStore: self)}
        
        self.recomputeSetTypeDisplays()
    }
    
    func setMetric (_ metricType: MetricType) {
        exerciseChildDTO.settings.metricType = metricType
        delegate?.childDidChange()
    }
    
    func toggleWarmupRestTimer (_ value: Bool) {
        exerciseChildDTO.settings.useWarmupRestTimer = value
        delegate?.childDidChange()
    }
    
    func setWarmupRestDuration (_ value: Int) {
        exerciseChildDTO.settings.warmupRestDuration = value
        delegate?.childDidChange()
    }
    
    func toggleRestTimer (_ value: Bool) {
        exerciseChildDTO.settings.useRestTimer = value
        delegate?.childDidChange()
    }
    
    func setRestDuration (_ value: Int) {
        exerciseChildDTO.settings.setRestDuration = value
        delegate?.childDidChange()
    }
    
    func addSet (_ setType: SetType) {
        
        let nextOrder = (setSessions.map { $0.setDTO.order}.max() ?? 0) + 1
        let dto = SetSessionDTO(
            id: UUID(),
            order: nextOrder,
            weight: 0.0,
            reps: 0,
            setType: setType,
            performed: false,
            restSession: nil
        )
        
        let store = SetSessionEditStore(dto: dto, delegate: delegate, parentEditStore: self)
        setSessions.append(store)
        delegate?.childDidChange()
        
        recomputeSetTypeDisplays()
    }
    
    func addWarmupSets (_ count: Int) {
        for setSession in setSessions {
            setSession.setOrder(setSession.setDTO.order + count)
        }
        
        var warmupSets: [SetSessionEditStore] = []
        warmupSets.reserveCapacity(count)
        
        for i in 1...count {
            let dto = SetSessionDTO(
                id: UUID(),
                order: i,
                weight: 0.0,
                reps: 0,
                setType: .warmup,
                performed: false,
                restSession: nil
            )
            let store = SetSessionEditStore(
                dto: dto,
                delegate: delegate,
                parentEditStore: self
            )
            
            warmupSets.append(store)
        }
        
        setSessions.append(contentsOf: warmupSets)
        setSessions.sort(by: { $0.setDTO.order < $1.setDTO.order })
        delegate?.childDidChange()
        
        recomputeSetTypeDisplays()
    }
    
    func removeSet (_ id: UUID) {
        if let idx = setSessions.firstIndex(where: { $0.id == id}) {
            setSessions.remove(at: idx)
            normalizeSetOrder()
            delegate?.childDidChange()
            recomputeSetTypeDisplays()
        }
    }
    
    func removeSets (_ ids: [UUID]) {
        guard !ids.isEmpty else { return }
        let toRemove = Set(ids)
        
        setSessions.removeAll { toRemove.contains($0.id) }
        normalizeSetOrder()
        delegate?.childDidChange()
    }
    
    func recomputeSetTypeDisplays () {
        let orderedSetSessions = setSessions.sorted { $0.setDTO.order < $1.setDTO.order }
        
        var regularIndex = 0
        for setSession in orderedSetSessions {
            let label: String
            if setSession.setDTO.setType != .warmup {
                regularIndex += 1
                
                if setSession.setDTO.setType == .regular {
                    label = "\(regularIndex)"
                }else {
                    label = setSession.setDTO.setType.initials
                }
            }else {
                label = setSession.setDTO.setType.initials
            }
            
            setSession.applySetTypeDisplay(label)
        }
    }
    
    // Should not trigger childDidChange
    func markAllSetsAsPerformed () {
        for setSession in setSessions where !setSession.setDTO.performed {
            setSession.markPerformed()
        }
    }
    
    // Should not trigger childDidChange
    func discardAllUnperformedSets () {
        for setSession in setSessions where !setSession.setDTO.performed {
            setSessions.removeAll { $0.id == setSession.id}
        }
    }
    
    func setOrder (_ order: Int) {
        exerciseChildDTO.order = order
    }
    
    func replaceExercise(with newExerciseId: UUID, resetSets: Bool) {
        self.exerciseChildDTO.exerciseId = newExerciseId
    }
    
    func deleteSelf (){
        delegate?.removeExercise(id)
    }
    
    func snapshot () -> ExerciseSessionDTO {
        var out = exerciseChildDTO
        out.sets = setSessions
            .map { $0.snapshot() }
            .sorted { $0.order < $1.order }
        
        return out
    }
    
    func getLocalFieldsOrder () -> [UUID] {
        var final: [UUID] = []
        
        for setSession in setSessions {
            final.append(contentsOf: setSession.getLocalFieldsORder())
        }
        
        return final
    }
    
    func getGlobalFieldsOrder () async -> [UUID] {
        return await parentEditStore.getGlobalFieldsOrder()
    }
    
    var hasUnperformedSets: Bool {
        return setSessions.compactMap(\.setDTO).contains { !$0.performed }
    }
    
    var hasNoPerformedSets: Bool {
        if setSessions.compactMap(\.setDTO).contains(where: { $0.performed} ) {
            return false
        }
        
        return true
    }
    
    private func normalizeSetOrder () {
        for (i, s) in setSessions.enumerated() {
            s.setOrder(i)
        }
    }
}
