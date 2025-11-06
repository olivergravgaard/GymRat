import Foundation
import Combine
import SwiftUI

@MainActor
final class SetSessionEditStore: @MainActor SetChildEditStore {
    
    typealias DTO = SetSessionDTO
    
    let id: UUID
    @Published var setDTO: DTO
    
    weak var delegate: (any WorkoutSessionChildDelegate)?
    let parentEditStore: ExerciseSessionEditStore
    
    private let orchestrator: RestSessionOrchestrator
    @Published private(set) var restTick: RestTick?
    private var tickTask: Task<Void, Never>?
    
    @Published private(set) var setTypeDisplay: String = "-"
    @Published private(set) var prevPerformedWeight: Double? = nil
    @Published private(set) var prevPerformedReps: Int? = nil
    
    let weightFieldId = UUID()
    let repsFieldId = UUID()
    let restFieldId = UUID()
    
    enum UpdateSource {
        case view, external
    }
    
    let restDidChangeExternal = PassthroughSubject<Int, Never>()
    let weightAndRestChangeExternal = PassthroughSubject<(Double?, Int?), Never>()
    
    static func == (lhs: SetSessionEditStore, rhs: SetSessionEditStore) -> Bool {
        lhs.setDTO.id == rhs.setDTO.id
    }
    
    init (
        dto: DTO,
        delegate: (any WorkoutSessionChildDelegate)?,
        parentEditStore: ExerciseSessionEditStore,
        orchestrator: RestSessionOrchestrator
    ) {
        self.id = dto.id
        self.setDTO = dto
        self.delegate = delegate
        self.parentEditStore = parentEditStore
        self.orchestrator = orchestrator
        
        subscribeToRestTicks()
    }
    
    deinit {
        tickTask?.cancel()
    }
    
    var hasRest: Bool {
        setDTO.restSession != nil
    }
    
    var isWarmup: Bool {
        return setDTO.setType == .warmup
    }
    
    func addRestSession () {
        guard !hasRest else { return }
        let restSession = parentEditStore.getDefuaultRestSession(for: setDTO.setType)
        restDidChangeExternal.send(restSession.duration)
        setDTO.restSession = parentEditStore.getDefuaultRestSession(for: setDTO.setType)
        delegate?.childDidChange()
    }
    
    func removeRestSession () {
        guard hasRest else { return }
        setDTO.restSession = nil
        restTick = nil
        delegate?.childDidChange()
        
        Task {
            await orchestrator.stopIfActive(setId: id, sendFinal: true)
        }
    }
    
    func addTimeToRest (_ seconds: Int) {
        guard hasRest, setDTO.restSession?.restState == .running else { return }
        
        setDTO.restSession!.duration += seconds
        delegate?.childDidChange()
        
        Task {
            await orchestrator.adjust(by: seconds)
        }
    }
    
    func setRestDuration (_ seconds: Int?, source: UpdateSource = .view) {
        guard hasRest, let seconds = seconds else { return }
        setDTO.restSession!.duration = max(0, seconds)
        delegate?.childDidChange()
        
        if source == .external {
            restDidChangeExternal.send(seconds)
        }
    }
    
    func startRest () {
        if !hasRest { return }
        let now = Date()
        let total = max(0, setDTO.restSession?.duration ?? 0)
        
        setDTO.restSession!.startedAt = now
        setDTO.restSession!.endedAt = nil
        setDTO.restSession!.restState = .running
        delegate?.childDidChange()
        
        restTick = RestTick(setId: id, total: total, remaining: total, isFinished: false)
        
        Task {
            await orchestrator.start(setId: id, total: total, startedAt: now)
        }
    }
    
    func stopRest () {
        let ended = Date()
        
        if hasRest {
            setDTO.restSession!.endedAt = ended
            setDTO.restSession!.restState = .completed
            delegate?.childDidChange()
        }
        
        Task {
            await orchestrator.stopIfActive(setId: id, sendFinal: true)
        }
    }
    
    private func subscribeToRestTicks () {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            guard let self else { return }
            let stream = await orchestrator.subscribe(setId: self.id)
            for await tick in stream {
                await MainActor.run {
                    self.restTick = tick
                }
            }
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
    
    func applyPrevPerformed (weight: Double?, reps: Int?) {
        if prevPerformedWeight != weight {
            prevPerformedWeight = weight
        }
        
        if prevPerformedReps != reps {
            prevPerformedReps = reps
        }
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
        return setDTO
    }
    
    func getLocalFieldsORder () -> [UUID] {
        var final: [UUID] = [weightFieldId, repsFieldId]
        
        if setDTO.restSession != nil {
            final.append(restFieldId)
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
    
    var prevPerformedDisplay: String {
        guard let prevPerformedReps = prevPerformedReps, let prevPerformedWeight = prevPerformedWeight else { return "-"}
        return "\(prevPerformedWeight)\(parentEditStore.exerciseChildDTO.settings.metricType.rawValue) x \(prevPerformedReps)"
    }
}
