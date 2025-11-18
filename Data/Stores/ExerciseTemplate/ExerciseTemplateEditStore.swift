import Foundation
import Combine

@MainActor
final class ExerciseTemplateEditStore: ExerciseChildEditStore {
    let id: UUID
    @Published private(set) var exerciseChildDTO: ExerciseTemplateDTO
    @Published private(set) var setTemplates: [SetTemplateEditStore] = []
    
    let parentEditStore: WorkoutTemplateEditStore
    
    weak var delegate: (any WorkoutTemplateChildDelegate)?
    
    init (dto: ExerciseTemplateDTO, delegate: (any WorkoutTemplateChildDelegate)?, parentEditStore: WorkoutTemplateEditStore) {
        self.id = dto.id
        self.exerciseChildDTO = dto
        self.delegate = delegate
        self.parentEditStore = parentEditStore
        self.setTemplates = dto.sets
            .sorted { $0.order < $1.order }
            .map { .init(dto: $0, delegate: delegate, parentEditStore: self)}
        
        self.recomputeSetTypeDisplays()
        
    }
    
    func setMetric (_ metricType: MetricType) {
        exerciseChildDTO.settings.metricType = metricType
        delegate?.childDidChange()
    }
    
    func setWarmupRestDuration (_ value: Int) {
        exerciseChildDTO.settings.warmupRestDuration = value
        delegate?.childDidChange()
    }
    
    func addMissingRest () {
        let toAdd = setTemplates.filter { $0.hasRest == false}
        
        guard toAdd.count > 0 else { return }
        
        toAdd.forEach {
            $0.addRestTemplate()
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
        
        setTemplates.filter(\.hasRest).forEach {
            $0.setRestDuration($0.isWarmup ? warmup : working, source: .external)
        }
        
        delegate?.childDidChange()
    }
    
    func addSet (_ setType: SetType) {
        
        let nextOrder = (setTemplates.map { $0.setDTO.order}.max() ?? 0) + 1
        let dto = SetTemplateDTO(
            id: UUID(),
            order: nextOrder,
            setType: setType,
            restTemplate: nil
        )
        
        let store = SetTemplateEditStore(dto: dto, delegate: delegate, parentEditStore: self)
        setTemplates.append(store)
        delegate?.childDidChange()
        
        recomputeSetTypeDisplays()
    }
    
    func addSets (setType: SetType, count: Int) {
        guard count > 0 else { return }
        
        var newSets: [SetTemplateEditStore] = []
        newSets.reserveCapacity(count)
        
        if setType == .warmup {
            setTemplates.forEach { setTemplate in
                setTemplate.setOrder(setTemplate.setDTO.order + count)
            }
        }
            
        var setsCount = setTemplates.count
        for i in 1...count {
            let dto = SetTemplateDTO(
                id: UUID(),
                order: setType == .warmup ? i : setsCount + 1,
                weightTarget: nil,
                minReps: nil,
                maxReps: nil,
                setType: setType,
                restTemplate: getDefuaultRestSession(for: setType)
            )
            
            let store = SetTemplateEditStore(
                dto: dto,
                delegate: delegate,
                parentEditStore: self
            )
            
            newSets.append(store)
            
            setsCount += 1
        }
        
        setTemplates.append(contentsOf: newSets)
        setTemplates.sort(by: { $0.setDTO.order < $1.setDTO.order })
        delegate?.childDidChange()
        
        recomputeSetTypeDisplays()
    }
    
    func addNote (_ text: String) {
        let newNote = Note(order: exerciseChildDTO.notes.count + 1, note: "New note")
        
        exerciseChildDTO.notes.append(newNote)
        
        delegate?.childDidChange()
    }
    
    func updateNote (at index: Int, to newText: String) {
        exerciseChildDTO.notes[index].note = newText
    }
    
    func getDefuaultRestSession (for setType: SetType) -> RestTemplate {
        let isWarmup = setType == .warmup
        return .init(duration: isWarmup ? exerciseChildDTO.settings.warmupRestDuration : exerciseChildDTO.settings.setRestDuration)
    }
    
    func removeSet (_ id: UUID) {
        if let idx = setTemplates.firstIndex(where: { $0.id == id}) {
            setTemplates.remove(at: idx)
            normalizeSetOrder()
            delegate?.childDidChange()
            recomputeSetTypeDisplays()
        }
    }
    
    func recomputeSetTypeDisplays () {
        let orderedSetSessions = setTemplates.sorted { $0.setDTO.order < $1.setDTO.order }
        
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
    
    func setOrder (_ order: Int) {
        exerciseChildDTO.order = order
    }
    
    func snapshot () -> ExerciseTemplateDTO {
        var out = exerciseChildDTO
        out.sets = setTemplates.map { $0.snapshot()}.sorted { $0.order < $1.order }
        
        return out
    }
    
    func getLocalFieldsOrder () -> [UUID] {
        var final: [UUID] = []
        
        for setTemplate in setTemplates {
            final.append(contentsOf: setTemplate.getLocalFieldsOrder())
        }
        
        return final
    }
    
    func getGlobalFieldsOrder () async -> [UUID] {
        return await parentEditStore.getGlobalFieldsOrder()
    }
    
    func deleteSelf () {
        delegate?.removeExercise(id)
    }
    
    func replaceExercise (with newExerciseId: UUID, resetSets: Bool) {
        exerciseChildDTO.exerciseId = newExerciseId
        
        if resetSets {
            setTemplates.removeAll()
            exerciseChildDTO.settings = .defaultSettings
        }
        
        delegate?.childDidChange()
    }
    
    private func normalizeSetOrder () {
        for (i, s) in setTemplates.enumerated() {
            s.setOrder(i)
        }
    }
}
