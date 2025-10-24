import Foundation
import Combine
import SwiftUI

@MainActor
final class SetSessionEditStore: @MainActor SetChildEditStore {
    
    typealias DTO = SetSessionDTO
    
    let id: UUID
    @Published var setDTO: DTO
    
    let weightFieldId = UUID()
    let repsFieldId = UUID()
    
    weak var delegate: (any WorkoutSessionChildDelegate)?
    
    let parentEditStore: ExerciseSessionEditStore
    
    @Published private(set) var setTypeDisplay: String = "-"
    @Published private(set) var restSession: RestSessionEditStore?
    
    static func == (lhs: SetSessionEditStore, rhs: SetSessionEditStore) -> Bool {
        lhs.setDTO.id == rhs.setDTO.id
    }
    
    init (dto: DTO, delegate: (any WorkoutSessionChildDelegate)?, parentEditStore: ExerciseSessionEditStore) {
        self.id = dto.id
        self.setDTO = dto
        self.delegate = delegate
        self.parentEditStore = parentEditStore
        
        if let restSession = dto.restSession {
            self.restSession = .init(
                dto: restSession,
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
        guard setTypeDisplay != value else { return }
        setTypeDisplay = value
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
    
    func addRestSession () {
        guard restSession == nil else { return }
        
        let dto = RestSession(duration: 0, startedAt: nil, endedAt: nil, restState: .none)
        setDTO.restSession = dto
        
        let store = RestSessionEditStore(dto: dto, parentEditStore: self)
        self.restSession = store
        delegate?.childDidChange()
    }
    
    func removeRestSession () {
        guard restSession != nil else { return }
        setDTO.restSession = nil
        
        self.restSession = nil
        delegate?.childDidChange()
    }
    
    func markPerformed () {
        guard setDTO.performed == false else { return }
        setDTO.performed = true
        
        self.delegate?.childDidChange()
    }
    
    func unmarkPerformed () {
        guard setDTO.performed == true else { return }
        setDTO.performed = false
        
        self.delegate?.childDidChange()
    }
    
    func snapshot () -> DTO {
        setDTO.restSession = restSession?.dto ?? nil
        return setDTO
    }
    
    func getLocalFieldsORder () -> [UUID] {
        var final: [UUID] = [weightFieldId, repsFieldId]
        
        if restSession != nil {
            final.append(restSession!.uid)
        }
        
        return final
    }
    
    func getGlobalFieldsOrder () async -> [UUID] {
        return await parentEditStore.getGlobalFieldsOrder()
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
