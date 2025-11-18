import Foundation
import SwiftUI

struct SetSessionView: View {
    @ObservedObject var editStore: SetSessionEditStore
    
    let numpadHost: NumpadHost
    let standaloneNumpadHost: FocusOnlyHost
    
    @State private var weightText: String = ""
    @State private var repsText: String = ""
    @State private var restText: String = ""
    
    var initialWeight: String {
        let formatted = formatWeight(editStore.setDTO.weight)
        
        if formatted == "0.0" || formatted == "0,0" || formatted == "0" {
            guard let prevPerformedWeight = editStore.prevPerformedWeight else {
                return ""
            }
            
            return formatWeight(prevPerformedWeight)
        }
        
        return formatted
    }
    
    var initialReps: String {
        if editStore.setDTO.reps == 0 {
            guard let prevPerformedReps = editStore.prevPerformedReps else {
                return ""
            }
            
            return String(prevPerformedReps)
        }
        
        return String(editStore.setDTO.reps)
    }
    
    var initialRestText: String {
        guard let restSession = editStore.setDTO.restSession else { return ""}
        return formatRest(restSession.duration)
    }
    
    @State private var restActive: Bool = false
    @State private var restSwipeProgress: CGFloat = 0
    
    init (editStore: SetSessionEditStore, numpadHost: NumpadHost, standaloneNumpadHost: FocusOnlyHost) {
        self._editStore = ObservedObject(wrappedValue: editStore)
        self.numpadHost = numpadHost
        self.standaloneNumpadHost = standaloneNumpadHost
        self._weightText = State(initialValue: initialWeight)
        self._repsText = State(initialValue: initialReps)
        self._restText = State(initialValue: initialRestText)
    }
    
    var body: some View {
        VStack {
            HStack (spacing: 8) {
                MorphMenuView(
                    numpadHost: standaloneNumpadHost,
                    config: .init(
                        alignment: .topLeading,
                        cornerRadius: 12,
                        extraBounce: 0,
                        animation: .smooth(duration: 0.3)
                    )) {
                        Text("\(editStore.setTypeDisplay)")
                            .font(.footnote)
                            .fontWeight(.bold)
                            .foregroundStyle(editStore.setTypeColor)
                            .frame(width: 44, height: 32, alignment: .center)
                            .background {
                                RoundedRectangle(cornerRadius: 12).fill(editStore.setDTO.setType.fadedColor)
                            }
                    } menu: { close in
                        EditSetTypeView { setType in
                            editStore.setSetType(to: setType)
                        } close: { onClosed in
                            close {
                                onClosed()
                            }
                        }

                    }
                
                Text("\(editStore.prevPerformedDisplay)")
                    .frame(width: 96, height: 32, alignment: .center)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.gray)
                
                FieldRow(
                    id: editStore.weightFieldId,
                    host: numpadHost,
                    inputPolicy: InputPolicies.decimal(maxDigits: 3, maxFractionDigits: 3, allowNegative: false),
                    config: .init(
                        font: .systemFont(ofSize: 12, weight: .semibold),
                        textColor: .black,
                        selectionColor: .black,
                        caretColor: .black,
                        insets: .init(top: 0, left: 4, bottom: 0, right: 4),
                        alignment: .center,
                        placeholderText: "0.0",
                        placeholderColor: UIColor.black.withAlphaComponent(0.2)
                    ),
                    text: $weightText
                )
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: 32, alignment: .center)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(editStore.setDTO.setType.fadedColor)
                }
                .onChange(of: weightText) { oldValue, newValue in
                    commitWeight()
                }
                
                FieldRow(
                    id: editStore.repsFieldId,
                    host: numpadHost,
                    inputPolicy: InputPolicies.digitsOnly(maxDigits: 3, allowNegative: false),
                    config: .init(
                        font: .systemFont(ofSize: 12, weight: .semibold),
                        textColor: .black,
                        selectionColor: .black,
                        caretColor: .black,
                        insets: .init(top: 0, left: 4, bottom: 0, right: 4),
                        alignment: .center,
                        actions: .init(onNext: {
                            editStore.markPerformed()
                            return false
                        }),
                        placeholderText: "0",
                        placeholderColor: UIColor.black.withAlphaComponent(0.2)
                    ),
                    text: $repsText
                )
                .frame(width: 55, height: 32, alignment: .center)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(editStore.setDTO.setType.fadedColor)
                }
                .onChange(of: repsText) { oldValue, newValue in
                    commitReps()
                }
                
                Button {
                    if editStore.setDTO.performed {
                        editStore.unmarkPerformed()
                    }else {
                        editStore.markPerformed()
                        commitWeight()
                        commitReps()
                    }
                } label: {
                    Image(systemName: "checkmark")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .font(.footnote)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.vertical, 10)
                        .frame(width: 44, height: 32, alignment: .center)
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(editStore.setDTO.performed ? editStore.setDTO.setType.color : editStore.setDTO.setType.fadedColor)
                        }
                }
                
            }
            .onReceive(editStore.weightAndRestChangeExternal, perform: { (weight, reps) in
                guard let weight = weight, let reps = reps else { return }
                weightText = formatWeight(weight)
                repsText = String(reps)
            })
            .frame(height: 44)
            .padding(.horizontal, 6)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(editStore.setDTO.performed ? editStore.setDTO.setType.fadedColor : .clear)
            }
            .onReceive(editStore.restDidChangeExternal, perform: { seconds in
                let formatted = formatRest(seconds)
                restText = formatted
            })
            
            if editStore.hasRest {
                Group {
                    if isRestActive {
                        Text(formatRest(editStore.restTick?.remaining))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .frame(height: 24)
                            .background {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(editStore.setDTO.setType.fadedColor)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 24)
                                    
                                    GeometryReader { geo in
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(editStore.setDTO.setType.color)
                                            .frame(width: geo.size.width * activeRestRemainingFraction, height: geo.size.height)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 24)
                                
                            }
                            .onTapGesture {
                                numpadHost.setActive(editStore.activeRestFieldId)
                            }
                        
                        FieldRow(
                            id: editStore.activeRestFieldId,
                            host: numpadHost,
                            inputPolicy: InputPolicies.restControl(addSeconds: 5, decSeconds: 5, onAdd: { _ in
                                editStore.adjustActiveRest(by: 5)
                            }, onDec: { _ in
                                editStore.adjustActiveRest(by: -5)
                            }, onPause: {
                                editStore.togglePauseRest()
                            }, onReset: {
                                editStore.resetRest()
                            }, onSkip: {
                                numpadHost.focusNext()
                                editStore.skipRest()
                            }),
                            config: .init(),
                            text: .constant("")
                        )
                        .frame(width: 0, height: 0)
                        .clipped()
                        .allowsTightening(false)
                        
                    }else {
                        FieldRow(
                            id: editStore.restFieldId,
                            host: numpadHost,
                            inputPolicy: InputPolicies.time(limit: .hours, allowedNegative: false),
                            config: .init(
                                font: .systemFont(ofSize: 12, weight: .semibold),
                                textColor: UIColor(editStore.restComplete ? .white : editStore.setDTO.setType.color),
                                selectionColor: .white,
                                caretColor: .white,
                                insets: .init(top: 0, left: 4, bottom: 0, right: 4),
                                alignment: .center,
                                actions: .init(
                                    onNext: {
                                        withAnimation {
                                            editStore.stopRest()
                                        }
                                        return false
                                    },
                                    onBecomeActive: {
                                        withAnimation {
                                            DispatchQueue.main.async {
                                                restActive = true
                                            }
                                        }
                                        
                                        return false
                                    }, onResignActive: {
                                        
                                        withAnimation {
                                            restActive = false
                                        }
                                        
                                        return false
                                    }
                                ),
                                placeholderText: "-",
                                placeholderColor: UIColor.white.withAlphaComponent(0.8),
                            ),
                            text: $restText
                        )
                        .transition(.scale(scale: 0.8, anchor: .top).combined(with: .opacity))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(height: restActive ? 24 : 14 + (10 * restSwipeProgress), alignment: .center)
                        .background {
                            RoundedRectangle(cornerRadius: 12).fill(editStore.restComplete ? editStore.setDTO.setType.color : editStore.setDTO.setType.fadedColor)
                        }
                        .onChange(of: restText, { _, _ in
                            commitRest()
                        })
                    }
                }
                .onChange(of: editStore.setDTO.restSession?.restState, { oldValue, newValue in
                    if (oldValue == .running || oldValue == .paused) && (newValue == .idle || newValue == .completed) {
                        Task {
                            numpadHost.setOrder(await editStore.getGlobalFieldsOrder())
                        }
                    }else if (oldValue == .idle || oldValue == .completed) && (newValue == .running || newValue == .paused) {
                        Task {
                            numpadHost.setOrder(await editStore.getGlobalFieldsOrder())
                            numpadHost.setActive(editStore.activeRestFieldId)
                        }
                    }
                    
                    return
                })
                .swipeToTrigger(
                    leftSwipeConfig: .init(
                        direction: .left,
                        isDeletion: true,
                        threshold: 0.6,
                        backgroundColor: .red.opacity(0.2),
                        actionView: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.red)
                                .padding(.horizontal)
                        },
                        onTrigger: {
                            withAnimation(.snappy(duration: 0.3)) {
                                editStore.removeRestSession()
                            } completion: {
                                Task {
                                    numpadHost.setOrder(await editStore.getGlobalFieldsOrder())
                                }
                            }
                        }
                    ),
                    rightSwipeConfig: nil,
                    occupiesFullWidth: true
                )
            }
        }
        .swipeToTrigger(
            leftSwipeConfig: .init(
                direction: .left,
                isDeletion: true,
                threshold: 0.6,
                backgroundColor: .red.opacity(0.2),
                actionView: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                },
                onTrigger: {
                    withAnimation(.snappy(duration: 0.3)) {
                        editStore.removeSelf()
                    } completion: {
                        Task {
                            numpadHost.setOrder(await editStore.getGlobalFieldsOrder())
                        }
                    }
                }
            ),
            rightSwipeConfig: .init(
                direction: .right,
                isDeletion: false,
                threshold: 0.4,
                backgroundColor: .green.opacity(0.2),
                actionView: {
                    Image(systemName: "timer")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                        .padding(.horizontal)
                },
                onTrigger: {
                    withAnimation(.snappy(duration: 0.3)) {
                        editStore.addRestSession()
                    } completion: {
                        Task {
                            numpadHost.setOrder(await editStore.getGlobalFieldsOrder())
                        }
                    }
                }
            ),
            occupiesFullWidth: true
        )
    }
    
    var isRestActive: Bool {
        return editStore.setDTO.restSession?.restState == .running || editStore.setDTO.restSession?.restState == .paused
    }
    
    private var activeRestRemainingFraction: Double {
        let remaining = max(0, min(editStore.restTick?.remaining ?? 0, editStore.setDTO.restSession?.duration ?? 1))
        return Double(remaining) / Double(editStore.setDTO.restSession?.duration ?? remaining)
    }
    
    private func commitWeight () {
        if let v = parseWeight(weightText), v != editStore.setDTO.weight {
            editStore.setDTO.weight = v
            editStore.delegate?.childDidChange()
        }
    }
    
    private func commitReps () {
        if let v = Int(repsText), v != editStore.setDTO.reps {
            editStore.setDTO.reps = v
            editStore.delegate?.childDidChange()
        }
    }
    
    private func commitRest () {
        guard let restSession = editStore.setDTO.restSession else { return }
        
        if let v = parseRest(restText), v != restSession.duration {
            editStore.setRestDuration(v, source: .view)
            editStore.delegate?.childDidChange()
        }
    }
}
