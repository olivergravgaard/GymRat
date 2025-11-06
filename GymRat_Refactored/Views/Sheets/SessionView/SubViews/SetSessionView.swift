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
                                RoundedRectangle(cornerRadius: 12).fill(.white)
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
                        insets: .init(top: 0, left: 0, bottom: 4, right: 4),
                        alignment: .center,
                        placeholderText: "0.0",
                        placeholderColor: UIColor.black.withAlphaComponent(0.2)
                    ),
                    text: $weightText
                )
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: 32, alignment: .center)
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
                        insets: .init(top: 0, left: 0, bottom: 4, right: 4),
                        alignment: .center,
                        actions: .init(onNext: {
                            editStore.markPerformed()
                            
                            editStore.startRest()
                            return false
                        }),
                        placeholderText: "0",
                        placeholderColor: UIColor.black.withAlphaComponent(0.2)
                    ),
                    text: $repsText
                )
                .frame(width: 55, height: 32, alignment: .center)
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
                        editStore.startRest()
                    }
                } label: {
                    Image(systemName: "checkmark")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundStyle(editStore.setDTO.performed ? .white : .gray)
                        .padding(.vertical, 10)
                        .frame(width: 44, height: 32, alignment: .center)
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(editStore.setDTO.performed ? .green : .white)
                        }
                }
                
            }
            .onReceive(editStore.weightAndRestChangeExternal, perform: { (weight, reps) in
                print("Received")
                guard let weight = weight, let reps = reps else { return }
                weightText = formatWeight(weight)
                repsText = String(reps)
            })
            .frame(height: 44)
            .padding(.horizontal, 6)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(editStore.setDTO.performed ? .green.opacity(0.1) : .clear)
            }
            .swipeActions(
                config: .init(
                    leadingPadding: 8,
                    trailingPadding: 8,
                    spacing: 8,
                    occupiesFullWidth: false
                )) {
                    SwipeAction(
                        symbolImage: "trash",
                        tint: .red,
                        background: .red.opacity(0.1),
                        font: .caption,
                        size: .init(width: 44, height: 44)) { close in
                            close {
                                withAnimation(.snappy(duration: 0.3)) {
                                    editStore.removeSelf()
                                } completion: {
                                    Task {
                                        numpadHost.setOrder(await editStore.getGlobalFieldsOrder())
                                    }
                                }
                            }
                        }
                    
                    SwipeAction(
                        symbolImage: "timer",
                        tint: .green,
                        background: .green.opacity(0.1),
                        font: .caption,
                        size: .init(width: 44, height: 44)) { close in
                            close {
                                withAnimation (.snappy(duration: 0.3)) {
                                    editStore.addRestSession()
                                }
                            }
                        }
                }
                .onReceive(editStore.restDidChangeExternal, perform: { seconds in
                    let formatted = formatRest(seconds)
                    restText = formatted
                })
            
            if editStore.hasRest {
                let active = editStore.restTick?.isFinished == false
                
                if active {
                    Text(formatRest(editStore.restTick?.remaining))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(height: 24)
                        .background {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.indigo.opacity(0.1))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 24)
                                
                                GeometryReader { geo in
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.indigo)
                                        .frame(width: geo.size.width * (1 - (editStore.restTick?.progress ?? 0)), height: geo.size.height)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 24)
                            
                        }
                        .swipeActions(
                            config: .init(
                                leadingPadding: 8,
                                trailingPadding: 8,
                                spacing: 8,
                                occupiesFullWidth: false
                            ), progress: $restSwipeProgress) {
                                SwipeAction(
                                    symbolImage: "trash",
                                    tint: .red,
                                    background: .red.opacity(0.1),
                                    font: .caption,
                                    size: .init(width: 24, height: 24)) { close in
                                        close{
                                            withAnimation(.snappy(duration: 0.3)) {
                                                editStore.removeRestSession()
                                            } completion: {
                                                Task {
                                                    numpadHost.setOrder(await editStore.getGlobalFieldsOrder())
                                                }
                                            }
                                        }
                                    }
                            }
                        
                }else {
                    FieldRow(
                        id: editStore.restFieldId,
                        host: numpadHost,
                        inputPolicy: InputPolicies.time(limit: .hours, allowedNegative: false),
                        config: .init(
                            font: .systemFont(ofSize: 12, weight: .semibold),
                            textColor: .white,
                            selectionColor: .white,
                            caretColor: .white,
                            insets: .init(top: 0, left: 0, bottom: 4, right: 4),
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
                        RoundedRectangle(cornerRadius: 12).fill(.indigo)
                    }
                    .onAppear(perform: {
                        Task {
                            numpadHost.setOrder(await editStore.getGlobalFieldsOrder())
                        }
                    })
                    .onChange(of: restText, { _, _ in
                        commitRest()
                    })
                    .swipeActions(
                        config: .init(
                            leadingPadding: 8,
                            trailingPadding: 8,
                            spacing: 8,
                            occupiesFullWidth: false
                        ), progress: $restSwipeProgress) {
                            SwipeAction(
                                symbolImage: "trash",
                                tint: .red,
                                background: .red.opacity(0.1),
                                font: .caption,
                                size: .init(width: 24, height: 24)) { close in
                                    close{
                                        withAnimation(.snappy(duration: 0.3)) {
                                            editStore.removeRestSession()
                                        } completion: {
                                            Task {
                                                numpadHost.setOrder(await editStore.getGlobalFieldsOrder())
                                            }
                                        }
                                    }
                                }
                        }
                }
            }
        }
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
