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
    let activeRestFieldId = UUID()
    
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
    
    func addRestSession () {
        guard !hasRest else { return }
        let restSession = parentEditStore.getDefuaultRestSession(for: setDTO.setType)
        restDidChangeExternal.send(restSession.duration)
        setDTO.restSession = restSession
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
    
    func setRestDuration (_ seconds: Int?, source: UpdateSource = .view) {
        guard hasRest, let seconds = seconds else { return }
        setDTO.restSession!.duration = max(0, seconds)
        delegate?.childDidChange()
        
        if source == .external {
            restDidChangeExternal.send(seconds)
        }
    }
    
    func startRest () {
        guard let rest = setDTO.restSession, rest.restState != .running else { return }
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
        guard hasRest, let rest = setDTO.restSession, rest.restState == .running else { return }
        
        setDTO.restSession!.restState = .completed
        setDTO.restSession!.endedAt = Date()
        
        delegate?.childDidChange()
        
        Task {
            await orchestrator.stopIfActive(setId: id, sendFinal: false)
        }
    }
    
    func cancelRest () {
        guard hasRest, let rest = setDTO.restSession else { return }
        
        setDTO.restSession!.startedAt = nil
        setDTO.restSession!.endedAt = nil
        setDTO.restSession!.pausedRemaining = nil
        setDTO.restSession!.restState = .idle
        
        restTick = nil
        delegate?.childDidChange()
        
        Task {
            await orchestrator.stopIfActive(setId: id, sendFinal: false)
        }
    }
    
    func resetRest () {
        guard hasRest else { return }
        
        let total = max(0, setDTO.restSession!.duration)
        let state = setDTO.restSession!.restState
        
        switch state {
        case .running:
            let now = Date()
            setDTO.restSession!.startedAt = now
            setDTO.restSession!.endedAt = nil
            setDTO.restSession!.pausedRemaining = nil
            setDTO.restSession!.restState = .running
            
            restTick = .init(setId: id, total: total, remaining: total, isFinished: false)
            
            delegate?.childDidChange()
            
            Task {
                await orchestrator.start(setId: id, total: total, startedAt: now)
            }
            
        case .paused:
            setDTO.restSession!.startedAt = nil
            setDTO.restSession!.endedAt = nil
            setDTO.restSession!.pausedRemaining = total
            setDTO.restSession!.restState = .paused
            
            restTick = .init(setId: id, total: total, remaining: total, isFinished: false)
            
            delegate?.childDidChange()
            
            Task {
                await orchestrator.stopIfActive(setId: id, sendFinal: false)
            }
        case .idle, .completed:
            setDTO.restSession!.startedAt = nil
            setDTO.restSession!.endedAt = nil
            setDTO.restSession!.pausedRemaining = nil
            setDTO.restSession!.restState = .idle
            
            restTick = nil
            delegate?.childDidChange()
            
            Task {
                await orchestrator.stopIfActive(setId: id, sendFinal: false)
            }
        }
    }
    
    func skipRest () {
        
    }
    
    func togglePauseRest () {
        guard hasRest, let state = setDTO.restSession?.restState, state == .running || state == .paused else { return }
        
        switch state {
            case .running:
                pauseRest()
            case .paused:
                resumeRest()
            default:
                return
        }
    }
    
    func adjustActiveRest (by delta: Int) {
        guard hasRest, let rest = setDTO.restSession else { return }
        
        switch rest.restState {
        case .running:
            let newDuration = max(0, rest.duration + delta)
            setDTO.restSession!.duration = newDuration
            delegate?.childDidChange()
            
            Task {
                await orchestrator.adjust(by: delta)
            }
            
        case .paused:
            let newTotal = max(0, rest.duration + delta)
            let newRem = max(0, (rest.pausedRemaining ?? rest.duration) + delta)
            setDTO.restSession!.duration = newTotal
            setDTO.restSession!.pausedRemaining = newRem
            
            if newRem == 0 {
                setDTO.restSession!.restState = .completed
                setDTO.restSession!.pausedRemaining = nil
                setDTO.restSession!.endedAt = Date()
                restTick = nil
                delegate?.childDidChange()
                
                Task {
                    await orchestrator.stopIfActive(setId: id, sendFinal: false)
                }
                
                return
            }
            
            restTick = .init(
                setId: id,
                total: newTotal,
                remaining: newRem,
                isFinished: false
            )
            
            delegate?.childDidChange()
        default:
            return
        }
    }
    
    private func pauseRest () {
        Task { [weak self] in
            guard let self else { return }
            if let rem = await orchestrator.pause(setId: self.id) {
                self.setDTO.restSession!.pausedRemaining = rem
                self.setDTO.restSession!.startedAt = nil
                self.setDTO.restSession!.endedAt = nil
                self.setDTO.restSession!.restState = .paused
                
                let total = self.setDTO.restSession!.duration
                self.restTick = .init(setId: self.id, total: total, remaining: rem, isFinished: false)
                self.delegate?.childDidChange()
            }
        }
    }
    
    private func resumeRest () {
        let now = Date()
        let total = max(0, setDTO.restSession!.duration)
        let rem = max(0, setDTO.restSession!.pausedRemaining ?? total)
        
        setDTO.restSession!.startedAt = now
        setDTO.restSession!.endedAt = nil
        setDTO.restSession!.restState = .running
        setDTO.restSession!.pausedRemaining = nil
        delegate?.childDidChange()
        
        restTick = .init(
            setId: id,
            total: total,
            remaining: rem,
            isFinished: false
        )
        
        Task {
            await orchestrator
                .resumeFromPause(
                    setId: id,
                    total: total,
                    remaining: rem,
                    startedAt: now
                )
        }
    }
    
    private func reconcileRestStateBeforeSubscribe () async {
        await MainActor.run {
            guard let r = self.setDTO.restSession else {
                self.restTick = nil
                return
            }
            
            switch r.restState {
            case .running:
                if let startedAt = r.startedAt {
                    Task { [weak self] in
                        guard let self else { return }
                        await self.orchestrator.restoreIfNeeded(
                            setId: self.id,
                            total: r.duration,
                            startedAt: startedAt
                        )
                    }
                }else {
                    self.restTick = .init(
                        setId: self.id,
                        total: r.duration,
                        remaining: r.duration,
                        isFinished: false
                    )
                }
            case .paused:
                Task { [weak self] in
                    guard let self else { return }
                    await self.orchestrator.stopIfActive(setId: self.id, sendFinal: false)
                }
                let rem = r.pausedRemaining ?? r.duration
                self.restTick = .init(
                    setId: self.id,
                    total: r.duration,
                    remaining: rem,
                    isFinished: false
                )
            default:
                self.restTick = nil
            }
        }
    }
    
    private func subscribeToRestTicks () {
        tickTask?.cancel()
        
        tickTask = Task { [weak self] in
            guard let self else { return }
            
            await self.reconcileRestStateBeforeSubscribe()
            
            let stream = await orchestrator.subscribe(setId: self.id)
            
            for await tick in stream {
                await MainActor.run {
                    
                    if self.setDTO.restSession?.restState == .paused {
                        return
                    }
                    
                    if tick.total == 0, tick.remaining == 0, tick.isFinished {
                        if self.setDTO.restSession?.restState == .paused {
                            return
                        }
                        
                        self.restTick = nil
                        return
                    }
                    
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
        startRest()
        
        self.delegate?.childDidChange()
    }
    
    func unmarkPerformed () {
        guard setDTO.performed == true else { return }
        setDTO.performed = false
        cancelRest()
        
        self.delegate?.childDidChange()
    }
    
    func snapshot () -> DTO {
        return setDTO
    }
    
    func getLocalFieldsOrder () -> [UUID] {
        var final: [UUID] = [weightFieldId, repsFieldId]
        
        if let restSession = setDTO.restSession {
            if restSession.restState == .running || restSession.restState == .paused {
                final.append(activeRestFieldId)
            }else {
                final.append(restFieldId)
            }
        }
        
        return final
    }
    
    func getGlobalFieldsOrder () async -> [UUID] {
        return await parentEditStore.getGlobalFieldsOrder()
    }
    
    var hasRest: Bool {
        setDTO.restSession != nil
    }
    
    var isWarmup: Bool {
        return setDTO.setType == .warmup
    }
    
    var restComplete: Bool {
        guard hasRest else { return false }
        
        if setDTO.restSession!.restState == .completed {
            return true
        }
        
        return false
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
