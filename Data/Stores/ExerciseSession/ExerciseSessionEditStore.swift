import Foundation
import Combine

@MainActor
final class ExerciseSessionEditStore: ExerciseChildEditStore {
    let id: UUID
    @Published private(set) var exerciseChildDTO: ExerciseSessionDTO
    @Published private(set) var setSessions: [SetSessionEditStore] = []
    
    let parentEditStore: WorkoutSessionEditStore
    
    weak var delegate: (any WorkoutSessionChildDelegate)?
    
    let lastPerformedDTO: ExerciseSessionDTO?
    
    enum SimplifiedSetType {
        case warmup
        case working
    }
    
    lazy var lastPerformedSetSessionDTOs: [SimplifiedSetType: [SetSessionDTO]] = {
        guard lastPerformedDTO != nil else { return [:] }
        
        var dict: [SimplifiedSetType: [SetSessionDTO]] = [:]
        
        let warmupSets = lastPerformedDTO?.sets.filter({ $0.setType == .warmup }).sorted(by: { $0.order < $1.order })
        let workingsSets = lastPerformedDTO?.sets.filter({ $0.setType != .warmup}).sorted(by: { $0.order < $1.order })
        
        dict[.warmup] = warmupSets
        dict[.working] = workingsSets
        
        return dict
    }()

    init (
        dto: ExerciseSessionDTO,
        lastPerfomedDTO: ExerciseSessionDTO?,
        delegate: (any WorkoutSessionChildDelegate)?,
        parentEditStore: WorkoutSessionEditStore
    ) {
        self.id = dto.id
        self.exerciseChildDTO = dto
        self.lastPerformedDTO = lastPerfomedDTO
        self.delegate = delegate
        self.parentEditStore = parentEditStore
        self.setSessions = dto.sets
            .sorted { $0.order < $1.order }
            .map {
                SetSessionEditStore(
                    dto: $0,
                    delegate: delegate,
                    parentEditStore: self,
                    orchestrator: parentEditStore.restOrchestrator
                )
            }
        
        self.recomputeSetTypeDisplays()
        self.recomputePreviousPerfomedDisplays()
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
    
    func addMissingRestSessions () {
        let toAdd = setSessions.filter { $0.hasRest == false }
        
        guard toAdd.count > 0 else { return }
        
        toAdd.forEach {
            $0.addRestSession()
        }
        
        delegate?.childDidChange()
    }
    
    func updateRestTimers (warmup: Int?, working: Int?) {
        if let warmup = warmup {
            exerciseChildDTO.settings.warmupRestDuration = warmup
        }
        
        if let working = working {
            exerciseChildDTO.settings.setRestDuration = working
        }
        
        setSessions.filter(\.hasRest).forEach {
            $0.setRestDuration($0.isWarmup ? warmup : working, source: .external)
        }
        
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
            restSession: getDefuaultRestSession(for: setType)
        )
        
        let store = SetSessionEditStore(
            dto: dto,
            delegate: delegate,
            parentEditStore: self,
            orchestrator: parentEditStore.restOrchestrator
        )
        
        setSessions.append(store)
        
        let lastPerformedData = getLastPerformedSetDTO(for: dto)
        store.applyPrevPerformed(weight: lastPerformedData?.weight ?? nil, reps: lastPerformedData?.reps ?? nil)
        
        delegate?.childDidChange()
        recomputeSetTypeDisplays()
    }
    
    func addSets (setType: SetType, count: Int) {
        guard count > 0 else { return }
        
        var newSets: [SetSessionEditStore] = []
        newSets.reserveCapacity(count)
        
        if setType == .warmup {
            setSessions.forEach { setSession in
                setSession.setOrder(setSession.setDTO.order + count)
            }
        }
            
        var setsCount = setSessions.count
        for i in 1...count {
            let dto = SetSessionDTO(
                id: UUID(),
                order: setType == .warmup ? i : setsCount + 1,
                weight: 0.0,
                reps: 0,
                setType: setType,
                performed: false,
                restSession: getDefuaultRestSession(for: setType)
            )
            
            let store = SetSessionEditStore(
                dto: dto,
                delegate: delegate,
                parentEditStore: self,
                orchestrator: parentEditStore.restOrchestrator
            )
            
            newSets.append(store)
            
            setsCount += 1
        }
        
        setSessions.append(contentsOf: newSets)
        setSessions.sort(by: { $0.setDTO.order < $1.setDTO.order })
        delegate?.childDidChange()
        
        recomputeSetTypeDisplays()
    }
    
    func addNote(_ text: String) {
        
    }
    
    func addMissingRest() {
        
    }
    
    func getDefuaultRestSession (for setType: SetType) -> RestSession {
        let isWarmup = setType == .warmup
        return .init(
            duration: isWarmup ? exerciseChildDTO.settings.warmupRestDuration : exerciseChildDTO.settings.setRestDuration,
            startedAt: nil,
            endedAt: nil,
            restState: .idle
        )
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
            let setTypeDisplay: String
            if setSession.setDTO.setType != .warmup {
                regularIndex += 1
                
                if setSession.setDTO.setType == .regular {
                    setTypeDisplay = "\(regularIndex)"
                }else {
                    setTypeDisplay = setSession.setDTO.setType.initials
                }
            }else {
                setTypeDisplay = setSession.setDTO.setType.initials
            }
            
            setSession.applySetTypeDisplay(setTypeDisplay)
        }
    }
    
    func recomputePreviousPerfomedDisplays () {
        setSessions.forEach {
            guard let lastPerformedSetSession = getLastPerformedSetDTO(for: $0.setDTO) else { return }
            
            $0.applyPrevPerformed(weight: lastPerformedSetSession.weight, reps: lastPerformedSetSession.reps)
        }
    }
    
    func getLastPerformedSetDTO (for setDTO: SetSessionDTO) -> SetSessionDTO? {
        guard let _ = lastPerformedDTO else {
            return nil
        }
        
        if setDTO.setType == .warmup {
            if let idx = setSessions.filter(\.isWarmup).sorted(by: { $0.setDTO.order < $1.setDTO.order}).firstIndex(where: { $0.setDTO == setDTO}) {
                guard let lastPerformedWarmupSets = lastPerformedSetSessionDTOs[SimplifiedSetType.warmup], lastPerformedWarmupSets.count > idx else { return nil }
                
                return lastPerformedWarmupSets[idx]
            }
        }
        
        if let idx = setSessions.filter({$0.setDTO.setType != .warmup}).sorted(by: { $0.setDTO.order < $1.setDTO.order}).firstIndex(where: { $0.setDTO == setDTO}) {
            guard let lastPerformedWorkingSets = lastPerformedSetSessionDTOs[SimplifiedSetType.working], lastPerformedWorkingSets.count > idx else { return nil }
            
            return lastPerformedWorkingSets[idx]
        }
        
        return nil
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
            final.append(contentsOf: setSession.getLocalFieldsOrder())
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
            s.setOrder(i + 1)
        }
    }
}
