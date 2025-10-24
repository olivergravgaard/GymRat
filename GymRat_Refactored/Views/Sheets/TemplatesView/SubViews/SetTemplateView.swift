import Foundation
import SwiftUI

struct SetTemplateView: View {
    
    @ObservedObject var editStore: SetTemplateEditStore
    
    let numpadHost: _NumpadHost
    
    @State private var weightTargetText: String = ""
    @State private var restText: String = ""
    
    var initialWeightTarget: String {
        return formatWeightTarget(editStore.setDTO.weightTarget)
    }
    
    var initialRestText: String {
        guard let restTemplate = editStore.restTemplate else { return "" }
        return formatRest(restTemplate.dto.duration)
    }
    
    @State private var restActive: Bool = false
    
    @State private var restSwipeProgress: CGFloat = 0
    
    init(editStore: SetTemplateEditStore, numpadHost: _NumpadHost) {
        self._editStore = ObservedObject(wrappedValue: editStore)
        self.numpadHost = numpadHost
        self._weightTargetText = State(initialValue: initialWeightTarget)
        self._restText = State(initialValue: initialRestText)
    }
    
    var body: some View {
        VStack {
            HStack (spacing: 8) {
                MorphMenuView(
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
                                withAnimation (.snappy(duration: 0.3)) {
                                    editStore.addRestTemplate()
                                }
                            }
                        }
                }
            
            if let restTemplate = editStore.restTemplate {
                FieldRow(
                    id: restTemplate.uid,
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
    
    private var decSep: String {
        return Locale.current.decimalSeparator ?? "."
    }
    
    private func formatWeightTarget (_ v: Double?) -> String {
        guard let v = v else { return ""}
        let s = String(v)
        return decSep == "." ? s : s.replacingOccurrences(of: ".", with: decSep)
    }
    
    private func parseWeightTarget (_ s: String) -> Double? {
        return Double(s.replacingOccurrences(of: decSep, with: "."))
    }
    
    private func formatRest(_ v: Int?) -> String {
        guard let v = v else { return "" }
        var total = v
        if total < 0 { total = -total } // fjern evt. hvis du ikke vil håndtere negative værdier

        let days  = total / 86_400; total %= 86_400
        let hours = total / 3_600;  total %= 3_600
        let mins  = total / 60
        let secs  = total % 60

        func pad2(_ x: Int) -> String { String(format: "%02d", x) }

        if days > 0 {
            return "\(days):\(pad2(hours)):\(pad2(mins)):\(pad2(secs))"
        } else if hours > 0 {
            return "\(hours):\(pad2(mins)):\(pad2(secs))"
        } else if mins > 0 {
            return "\(mins):\(pad2(secs))"
        } else {
            return "\(secs)"
        }
    }
    
    private func parseRest(_ s: String) -> Int? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.split(separator: ":").map(String.init)
        guard (1...4).contains(parts.count) else { return nil }

        let nums = parts.compactMap { Int($0) }
        guard nums.count == parts.count else { return nil }

        switch nums.count {
        case 1:
            let ss = nums[0]
            guard ss >= 0 else { return nil }
            return ss

        case 2:
            let (mm, ss) = (nums[0], nums[1])
            guard mm >= 0, (0...59).contains(ss) else { return nil }
            return mm * 60 + ss

        case 3:
            let (hh, mm, ss) = (nums[0], nums[1], nums[2])
            guard hh >= 0, (0...59).contains(mm), (0...59).contains(ss) else { return nil }
            return hh * 3_600 + mm * 60 + ss

        case 4:
            let (dd, hh, mm, ss) = (nums[0], nums[1], nums[2], nums[3])
            guard dd >= 0, (0...23).contains(hh), (0...59).contains(mm), (0...59).contains(ss) else { return nil }
            return dd * 86_400 + hh * 3_600 + mm * 60 + ss

        default:
            return nil
        }
    }
    
    private func commitWeightTarget () {
        if let v = parseWeightTarget(weightTargetText), v != editStore.setDTO.weightTarget {
            editStore.setDTO.weightTarget = v
            editStore.delegate?.childDidChange()
        }
    }
    
    private func commitRest () {
        guard let restTemplate = editStore.restTemplate else { return }
        
        if let v = parseRest(restText), v != restTemplate.dto.duration {
            restTemplate.setDuration(v)
            editStore.delegate?.childDidChange()
        }
    }
}
