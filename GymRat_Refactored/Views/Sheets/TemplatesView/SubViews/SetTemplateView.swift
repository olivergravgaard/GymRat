import Foundation
import SwiftUI

struct SetTemplateView: View {
    
    @ObservedObject var editStore: SetTemplateEditStore
    
    let numpadHost: NumpadHost
    let standaloneNumpadHost: FocusOnlyHost
    
    @State private var weightTargetText: String = ""
    @State private var restText: String = ""
    
    var initialWeightTarget: String {
        return formatWeightTarget(editStore.setDTO.weightTarget)
    }
    
    var initialRestText: String {
        guard let restTemplate = editStore.setDTO.restTemplate else { return "" }
        return formatRest(restTemplate.duration)
    }
    
    @State private var restActive: Bool = false
    @State private var restSwipeProgress: CGFloat = 0
    
    init(editStore: SetTemplateEditStore, numpadHost: NumpadHost, standaloneNumpadHost: FocusOnlyHost) {
        self._editStore = ObservedObject(wrappedValue: editStore)
        self.numpadHost = numpadHost
        self.standaloneNumpadHost = standaloneNumpadHost
        self._weightTargetText = State(initialValue: initialWeightTarget)
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
                        Text("\(editStore._setTypeDisplay)")
                            .font(.footnote)
                            .fontWeight(.bold)
                            .foregroundColor(editStore.setTypeColor)
                            .frame(width: 55, height: 32, alignment: .center)
                            .background {
                                RoundedRectangle(cornerRadius: 12).fill(.white)
                            }
                    } menu: { close in
                        EditSetTypeView(
                            editStore: editStore,
                            close: close
                        )
                    }
                
                FieldRow(
                    id: editStore.weightTargetFieldId,
                    host: numpadHost,
                    inputPolicy: InputPolicies.decimal(maxDigits: 3, maxFractionDigits: 3, allowNegative: false),
                    config: .init(
                        font: .systemFont(ofSize: 12, weight: .semibold),
                        textColor: .black,
                        selectionColor: .black,
                        caretColor: .black,
                        insets: .init(top: 0, left: 0, bottom: 4, right: 4),
                        alignment: .center,
                        placeholderText: "-",
                        placeholderColor: UIColor.black.withAlphaComponent(0.2)
                    ),
                    text: $weightTargetText
                )
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: 32, alignment: .center)
                .onChange(of: weightTargetText) { _, _ in
                    commitWeightTarget()
                }
                
                MorphMenuView(
                    numpadHost: standaloneNumpadHost,
                    config: .init(
                        alignment: .topTrailing,
                        cornerRadius: 12,
                        extraBounce: 0,
                        animation: .smooth(duration: 0.3)
                    )) {
                        Text(editStore.repsTargetDisplay)
                            .font(.footnote)
                            .fontWeight(.bold)
                            .foregroundColor(editStore.repsTargetColor)
                            .frame(width: 55, height: 32, alignment: .center)
                            .background {
                                RoundedRectangle(cornerRadius: 12).fill(.white)
                            }
                    } menu: { close in
                        RepRangeSelectionMenu(
                            editStore: editStore) { onClosed in
                                close {
                                    onClosed()
                                }
                            }
                    }
            }
            .frame(height: 44)
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
                            close  {
                                withAnimation (.snappy(duration: 0.3)) {
                                    editStore.removeSelf()
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
                                withAnimation(.snappy(duration: 0.3)) {
                                    editStore.addRestTemplate()
                                }
                            }
                        }
                }
            
            if editStore.hasRest {
                Group {
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
                                onBecomeActive: {
                                    
                                    withAnimation {
                                        restActive = true
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
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: restActive ? 24 : 14 + (10 * restSwipeProgress), alignment: .center)
                    .background {
                        RoundedRectangle(cornerRadius: 12).fill(.indigo)
                    }
                    .onAppear(perform: {
                        restText = formatRest(editStore.setDTO.restTemplate?.duration)
                        Task {
                            numpadHost.setOrder(await editStore.getGlobalFieldsOrder())
                        }
                    })
                    .onChange(of: restText, { _, _ in
                        commitRest()
                    })
                    .onReceive(editStore.restDidChangeExternal, perform: { seconds in
                        let formatted = formatRest(seconds)
                        restText = formatted
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
                                            editStore.removeRestTemplate()
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
    
    private func commitWeightTarget () {
        if let v = parseWeightTarget(weightTargetText), v != editStore.setDTO.weightTarget {
            editStore.setDTO.weightTarget = v
            editStore.delegate?.childDidChange()
        }
    }
    
    private func commitRest () {
        guard let restTemplate = editStore.setDTO.restTemplate else { return }
        
        if let v = parseRest(restText), v != restTemplate.duration {
            editStore.setRestDuration(v)
            editStore.delegate?.childDidChange()
        }
    }
}
