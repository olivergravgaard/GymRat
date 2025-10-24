import Foundation
import Combine
import SwiftUI

@MainActor
final class SetTemplateEditStore: @MainActor SetChildEditStore {
    
    typealias DTO = SetTemplateDTO
    
    let id: UUID
    @Published var setDTO: DTO
    
    let weightTargetFieldId = UUID()
    
    weak var delegate: (any WorkoutTemplateChildDelegate)?
    
    let parentEditStore: ExerciseTemplateEditStore
    
    @Published private(set) var _setTypeDisplay: String = "-"
    @Published private(set) var restTemplate: RestTemplateEditStore?
    
    static func == (lhs: SetTemplateEditStore, rhs: SetTemplateEditStore) -> Bool {
        lhs.setDTO.id == rhs.setDTO.id
    }
    
    init (dto: SetTemplateDTO, delegate: (any WorkoutTemplateChildDelegate)?, parentEditStore: ExerciseTemplateEditStore) {
        self.id = dto.id
        self.setDTO = dto
        self.delegate = delegate
        self.parentEditStore = parentEditStore
        
        if let restTemplate = dto.restTemplate {
            self.restTemplate = .init(
                dto: restTemplate,
                parentEditStore: self
            )
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
        guard restTemplate == nil else { return }
        
        let dto = RestTemplate(duration: 0)
        setDTO.restTemplate = dto
        
        let store = RestTemplateEditStore(dto: dto, parentEditStore: self)
        self.restTemplate = store
        delegate?.childDidChange()
    }
    
    func removeRestTemplate () {
        guard restTemplate != nil else { return }
        setDTO.restTemplate = nil
        
        self.restTemplate = nil
        delegate?.childDidChange()
    }
    
    func snapshot () -> DTO {
        setDTO.restTemplate = restTemplate?.dto ?? nil
        return setDTO
    }
    
    func getLocalFieldsOrder () -> [UUID] {
        var final: [UUID] = [weightTargetFieldId]
        
        if restTemplate != nil {
            final.append(restTemplate!.uid)
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
            return .black
        }
        
        return .indigo
    }
}
