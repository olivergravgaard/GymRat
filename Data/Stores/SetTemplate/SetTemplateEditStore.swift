import Foundation
import Combine
import SwiftUI

@MainActor
final class SetTemplateEditStore: @MainActor SetChildEditStore {
    
    typealias DTO = SetTemplateDTO
    
    let id: UUID
    @Published var setDTO: DTO
    
    weak var delegate: (any WorkoutTemplateChildDelegate)?
    
    let parentEditStore: ExerciseTemplateEditStore
    
    @Published private(set) var _setTypeDisplay: String = "-"
    
    let weightTargetFieldId = UUID()
    let restFieldId = UUID()
    
    enum UpdateSource {
        case view, external
    }
    
    let restDidChangeExternal = PassthroughSubject<Int, Never>()
    
    static func == (lhs: SetTemplateEditStore, rhs: SetTemplateEditStore) -> Bool {
        lhs.setDTO.id == rhs.setDTO.id
    }
    
    init (dto: SetTemplateDTO, delegate: (any WorkoutTemplateChildDelegate)?, parentEditStore: ExerciseTemplateEditStore) {
        self.id = dto.id
        self.setDTO = dto
        self.delegate = delegate
        self.parentEditStore = parentEditStore
    }
    
    var hasRest: Bool {
        setDTO.restTemplate != nil
    }
    
    var isWarmup: Bool {
        setDTO.setType == .warmup
    }
    
    func setRestDuration (_ seconds: Int?, source: UpdateSource = .view) {
        guard hasRest, let seconds = seconds else { return }
        setDTO.restTemplate!.duration = max(0, seconds)
        delegate?.childDidChange()
        
        if source == .external {
            restDidChangeExternal.send(seconds)
        }
    }
    
    func setSetType (to setType: SetType) {
        guard setDTO.setType != setType else { return }
        setDTO.setType = setType
            
        parentEditStore.recomputeSetTypeDisplays()
        
        self.delegate?.childDidChange()
    }
    
    func applySetTypeDisplay (_ value: String) {
        guard _setTypeDisplay != value else { return }
        _setTypeDisplay = value
    }
    
    func setWeightTarget (to target: Double?) {
        guard setDTO.weightTarget != target else { return }
        
        setDTO.weightTarget = target
        
        self.delegate?.childDidChange()
    }
    
    func setRepsTarget (min: Int?, max: Int?) {
        setDTO.minReps = min
        setDTO.maxReps = max
        
        self.delegate?.childDidChange()
    }
    
    func setOrder (_ order: Int) {
        setDTO.order = order
        
        self.delegate?.childDidChange()
    }
    
    func removeSelf () {
        parentEditStore.removeSet(self.id)
    }
    
    func addRestTemplate () {
        guard !hasRest else { return }
        let duration = isWarmup ? parentEditStore.exerciseChildDTO.settings.warmupRestDuration : parentEditStore.exerciseChildDTO.settings.setRestDuration
        setDTO.restTemplate = RestTemplate(duration: duration)
        delegate?.childDidChange()
    }
    
    func removeRestTemplate () {
        guard hasRest else { return }
        setDTO.restTemplate = nil
        delegate?.childDidChange()
    }
    
    func snapshot () -> DTO {
        return setDTO
    }
    
    func getLocalFieldsOrder () -> [UUID] {
        var final: [UUID] = [weightTargetFieldId]
        
        if setDTO.restTemplate != nil {
            final.append(restFieldId)
        }
        
        return final
    }
    
    func getGlobalFieldsOrder () async -> [UUID] {
        return await parentEditStore.getGlobalFieldsOrder()
    }
    
    var setTypeDisplay: String {
        if setDTO.setType != .regular {
            return setDTO.setType.initials
        }
        
        return "\(setDTO.order)"
    }
    
    var setTypeColor: Color {
        return setDTO.setType.color
    }
    
    var repsType: RepsType {
        let minReps = setDTO.minReps
        let maxReps = setDTO.maxReps
        
        if minReps == nil && maxReps == nil {
            return .none
        }else if minReps != nil && maxReps == nil {
            return .single
        }else {
            return .range
        }
    }
    
    var repsTargetDisplay: String {
        guard let minReps = setDTO.minReps else {
            return "-"
        }
        
        guard let maxReps = setDTO.maxReps else {
            return "\(minReps)"
        }
        
        return "\(minReps)-\(maxReps)"
    }
    
    var repsTargetColor: Color {
        if repsType == .none {
            return .gray
        }
        
        return .black
    }
}
