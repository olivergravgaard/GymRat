import Foundation
import SwiftUI
import UIKit
import Combine

@MainActor
final class NumpadHost: ObservableObject {
    private(set) var order: [UUID] = []
    private var indexOf: [UUID: Int] = [:]
    
    private struct WeakTextField {
        weak var textField: UITextField?
    }
    
    private var fieldsById: [UUID: WeakTextField] = [:]
    
    private(set) var activeId: UUID?
    
    var onScrollTo: ((UUID) -> Void)?
    
    // NEW
    private var pendingFocus: UUID?
    private var displayLink: CADisplayLink?
    private var focusGateUntil: CFTimeInterval = 0
    private let focusGateInterval: CFTimeInterval = 0.08
    private var lastScrollCall: CFTimeInterval = 0
    private let minScrollInterval: CFTimeInterval = 0.06
    private var didScrollForPendingFocus: Bool = false

    func startCoalescer () {
        guard displayLink == nil else { return }
        let dl = CADisplayLink(target: self, selector: #selector(onFrame))
        dl.add(to: .main, forMode: .common)
        dl.isPaused = true
        displayLink = dl
    }
    
    func scheduleFocus(_ id: UUID) {
        if pendingFocus == id { return }
        if activeId == id, let tf = fieldsById[id]?.textField, tf.isFirstResponder { return }
        pendingFocus = id
        displayLink?.isPaused = false
    }
    
    func stopCoalescer() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func onFrame() {
        guard let id = pendingFocus else {
            displayLink?.isPaused = true
            return
        }
        let now = CACurrentMediaTime()
        guard now >= focusGateUntil else { return }

        if let tf = fieldsById[id]?.textField, tf.window != nil, tf.isUserInteractionEnabled {
            if tf.isFirstResponder, activeId == id {
                pendingFocus = nil
                didScrollForPendingFocus = false
                displayLink?.isPaused = true
                return
            }
            
            focusGateUntil = now + focusGateInterval
            UIView.performWithoutAnimation {
                tf.becomeFirstResponder()
            }
            activeId = id
            pendingFocus = nil
            didScrollForPendingFocus = false
            displayLink?.isPaused = true
        } else {
            if !didScrollForPendingFocus && (now - lastScrollCall >= minScrollInterval) {
                lastScrollCall = now
                onScrollTo?(id)
                didScrollForPendingFocus = true
            }
        }
    }
    
    func setActive (_ id: UUID?) {
        if activeId == id { return }
        activeId = id
    }
    
    func textField (for id: UUID) -> UITextField? {
        fieldsById[id]?.textField
    }
    
    func setOrder (_ ids: [UUID]) {
        guard ids != order else { return }
        order = ids
        indexOf = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
    }
    
    func didInsert (_ id: UUID, at index: Int) {
        order.insert(id, at: index)
        for i in index..<order.count {
            indexOf[order[i]] = i
        }
    }
    
    func didDelete (_ id: UUID) {
        guard let idx = indexOf[id] else { return }
        order.remove(at: idx)
        indexOf[id] = nil
        for i in idx..<order.count {
            indexOf[order[i]] = i
        }
    }

    func didDeleteMany(_ ids: [UUID]) {
      guard !ids.isEmpty, !order.isEmpty else { return }
      let toDelete = Set(ids)

      let newOrder = order.filter { !toDelete.contains($0) }

      var newIndex: [UUID: Int] = [:]
      newIndex.reserveCapacity(newOrder.count)
      for (i, id) in newOrder.enumerated() { newIndex[id] = i }

      for id in toDelete { fieldsById[id] = nil }

      order = newOrder
      indexOf = newIndex
    }

    
    func move(_ id: UUID, to index: Int) {
        guard let old = indexOf[id], old != index else { return }
        order.remove(at: old)
        let newIdx = min(index, order.count)
        order.insert(id, at: newIdx)
        let lo = min(old,newIdx), hi = max(old,newIdx)
        for i in lo...hi {
            indexOf[order[i]] = i
        }
    }
    
    func register(id: UUID, textField: UITextField) {
        fieldsById[id] = WeakTextField(textField: textField)
        
        if displayLink == nil  {
            startCoalescer()
        }
    }
    
    func unregister(id: UUID) {
        fieldsById[id] = nil
    }

    func focusNext(from current: UUID, wrap: Bool = true) -> Bool {
        /*guard focusGateOpen(), let start = indexOf[current] else { return false}
        
        if tryAdvance(from: start+1, to: order.count-1) {
            return true
        }
        
        if wrap {
            if tryAdvance(from: 0, to: max(0, start-1)) {
                return true
            }
        }
        
        dismissNumpad()
        
        return false*/
        
        guard let i = indexOf[current], !order.isEmpty else { return false }
        var j = i + 1
        if j >= order.count {
            guard wrap else {
                dismissNumpad()
                return false
            }
            
            j = 0
        }
        
        scheduleFocus(order[j])
        
        return true
    }
    
    func focusPrev(from current: UUID, wrap: Bool = false) -> Bool {
        /*guard focusGateOpen(), let start = indexOf[current] else {
            return false
        }
        
        if tryReverse(from: start-1, to: 0) {
            return true
        }
        
        if wrap {
            if tryReverse(from: order.count-1, to: min(order.count-1, start+1)) {
                return true
            }
        }
        
        dismissNumpad()
        
        return false*/
        
        guard let i = indexOf[current], !order.isEmpty else { return false }
        var j = i - 1
        if j < 0 { guard wrap else { dismissNumpad(); return false }; j = order.count - 1 }
        scheduleFocus(order[j]); return true
    }
    
    func dismissNumpad() {
        if let id = activeId, let tf = fieldsById[id]?.textField, tf.isFirstResponder {
            tf.resignFirstResponder()
        } else if let tf = fieldsById.values.compactMap({ $0.textField }).first(where: { $0.isFirstResponder }) {
            tf.resignFirstResponder()
        } else {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        
        activeId = nil
    }
}

struct NumericInputStyle {
    var caretColor: Color
    var textAlignment: NSTextAlignment
    var textColor: Color
    var textStyle: UIFont.TextStyle
    var textWeight: UIFont.Weight
    var placeholderColor: Color
    var placeholderStyle: UIFont.TextStyle
    var placeholderWeight: UIFont.Weight
    
    static let def = NumericInputStyle(
        caretColor: .black,
        textAlignment: .center,
        textColor: .black,
        textStyle: .caption1,
        textWeight: .medium,
        placeholderColor: .gray,
        placeholderStyle: .caption1,
        placeholderWeight: .medium
    )
}

struct NumericInputActionsConfig {
    var onNext: (() -> Void)?
    var onPrev: (() -> Void)?
    var onDismiss: (() -> Void)?
    
    static var def: NumericInputActionsConfig = .init(
        onNext: nil,
        onPrev: nil,
        onDismiss: nil
    )
}

final class NakedTextField: UITextField {
    override init (frame: CGRect) {
        super.init(frame: frame)
        configure()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }
    
    private func configure () {
        autocorrectionType = .no
        spellCheckingType = .no
        autocapitalizationType = .none
        smartDashesType = .no
        smartQuotesType = .no
        smartInsertDeleteType = .no
        
        textContentType = .none
        passwordRules = nil
        clearsOnInsertion = false
        
        enablesReturnKeyAutomatically = false
        inputAssistantItem.leadingBarButtonGroups = []
        inputAssistantItem.trailingBarButtonGroups = []
        
        clearsContextBeforeDrawing = false
        backgroundColor = .clear
        borderStyle = .none
        layer.masksToBounds = false
        
        isContextMenuInteractionEnabled = false
        
        self.textDragInteraction?.isEnabled = false
        
        isExclusiveTouch = true
        translatesAutoresizingMaskIntoConstraints = false
        tintAdjustmentMode = .normal
        
        self.keyboardType = .numberPad
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        false
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        gestureRecognizers?.forEach { gr in
            if gr is UILongPressGestureRecognizer {
                gr.isEnabled = false
            }
        }
    }
    
    override var canBecomeFirstResponder: Bool { true }
    
    override func becomeFirstResponder() -> Bool {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let ok = super.becomeFirstResponder()
        CATransaction.commit()
        return ok
    }
    
    override func editMenu(for textRange: UITextRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
        return UIMenu(title: "", children: [])
    }
    
    override func paste(_ sender: Any?) {}
    override func copy(_ sender: Any?) {}
    override func cut(_ sender: Any?) {}
    override func select(_ sender: Any?) {}
    override func selectAll(_ sender: Any?) {}
}

struct NumericInputField: UIViewRepresentable {
    
    @Binding var text: String
    var id: UUID
    var placeholder: String
    let numpadHost: NumpadHost
    let style: NumericInputStyle
    var inputPolicy: InputPolicy
    var actions: NumericInputActionsConfig
    
    static weak var currentHost: NumpadHost?
    
    init (
        text: Binding<String>,
        id: UUID,
        placeholder: String,
        numpadHost: NumpadHost,
        style: NumericInputStyle = .def,
        inputPolicy: InputPolicy,
        actions: NumericInputActionsConfig = .def
    ) {
        self._text = text
        self.id = id
        self.placeholder = placeholder
        self.numpadHost = numpadHost
        self.style = style
        self.inputPolicy = inputPolicy
        self.actions = actions
    }
    
    private func dynamicFont(
        textStyle: UIFont.TextStyle,
        weight: UIFont.Weight? = nil
    ) -> UIFont {
        let base = UIFont.preferredFont(forTextStyle: textStyle)
        let pointSize = base.pointSize

        let unscaled: UIFont
        
        if let weight {
            unscaled = UIFont.systemFont(ofSize: pointSize, weight: weight)
        }else {
            unscaled = UIFont.systemFont(ofSize: pointSize) // regular
        }

        let scaled = UIFontMetrics(forTextStyle: textStyle).scaledFont(for: unscaled)
        return scaled
    }
    
    private func applyStyle (textField: UITextField) {
        textField.tintColor = UIColor(style.caretColor)
        textField.textColor = UIColor(style.textColor)
        textField.font = dynamicFont(textStyle: style.textStyle, weight: style.textWeight)
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: UIColor(style.placeholderColor),
                .font: dynamicFont(textStyle: style.placeholderStyle, weight: style.placeholderWeight)
            ]
        )
        
        textField.adjustsFontForContentSizeCategory = false
        textField.textAlignment = style.textAlignment
    }
    
    func makeUIView(context: Context) -> UITextField {
        let textField = NakedTextField(frame: .zero)
        textField.text = text

        textField.delegate = context.coordinator

        applyStyle(textField: textField)
        textField.inputView = KeyboardManager.shared.inputView

        DispatchQueue.main.async {
            numpadHost.register(id: id, textField: textField)
        }
        
        return textField
    }
    
    func updateUIView(_ textField: UITextField, context: Context) {
        if !textField.isFirstResponder, textField.text != text {
            textField.text = text
        }
    }
    
    func dismantleUIView(_ tf: UITextField, coordinator: Coordinator) {
        numpadHost.unregister(id: id)
    }
    
    final class Coordinator: NSObject, UITextFieldDelegate, KeyboardTarget {
        var parent: NumericInputField
        
        // NEW
        private var pendingModelText: String?
        private var writebackLink: CADisplayLink?
        
        init (_ parent: NumericInputField) {
            self.parent = parent
        }
        
        // NEW
        private func ensureWritebackLink() {
            guard writebackLink == nil else { return }
            let dl = CADisplayLink(target: self, selector: #selector(flushWriteback))
            dl.add(to: .main, forMode: .common)
            dl.isPaused = true
            writebackLink = dl
        }

        // NEW
        private func scheduleWriteback(_ s: String) {
            pendingModelText = s
            ensureWritebackLink()
            writebackLink?.isPaused = false
        }

        // NEW
        @objc private func flushWriteback() {
            guard let s = pendingModelText else {
                writebackLink?.isPaused = true
                return
            }
            if parent.text != s { parent.text = s }
            pendingModelText = nil
            writebackLink?.isPaused = true
        }
        
        func onKey (_ action: KeyAction) {
            guard let host = NumericInputField.currentHost,
                  host.activeId == parent.id,
                  let tf = host.textField(for: parent.id) else { return }
            handleKeyPress(for: tf, keyAction: action)
        }
        
        func textFieldDidBeginEditing(_ textField: UITextField) {
            NumericInputField.currentHost = parent.numpadHost
            parent.numpadHost.setActive(parent.id)
            
            KeyboardManager.shared.keyTarget = self
            KeyboardManager.shared.setProfile(parent.inputPolicy.keyboardProfile)
            
            switch parent.inputPolicy {
                case .time:
                    DispatchQueue.main.async {
                        let end = textField.text?.utf16.count ?? 0
                        textField.selectedRange = NSRange(location: end, length: 0)
                    }
                default:
                    DispatchQueue.main.async {
                        if let start = textField.beginningOfDocument as UITextPosition?,
                           let end = textField.endOfDocument as UITextPosition?,
                           let range = textField.textRange(from: start, to: end) {
                            textField.selectedTextRange = range
                        }else {
                            textField.selectAll(nil)
                        }
                    }
            }
        }
        
        func textFieldDidEndEditing(_ textField: UITextField) {
            if parent.numpadHost.activeId == parent.id {
                parent.numpadHost.setActive(nil)
            }
            
            if parent.numpadHost.activeId == nil {
                NumericInputField.currentHost = nil
                //KeyboardManager.shared.keyTarget = nil
            }
            
            if case .time(let config) = parent.inputPolicy {
                let current = textField.text ?? ""
                let finalized = config.finalizeDisplay(current)
                if finalized != current {
                    textField.text = finalized
                    parent.text = finalized
                }
                
                let end = finalized.utf16.count
                textField.selectedRange = NSRange(location: end, length: 0)
            }
        }
        
        func textFieldDidChangeSelection(_ textField: UITextField) {
            if case .time = parent.inputPolicy {
                let end = textField.text?.utf16.count ?? 0
                let desired = NSRange(location: end, length: 0)
                if textField.selectedRange.location != desired.location || textField.selectedRange.length != 0 {
                    textField.selectedRange = desired
                }
            }
        }
        
        func textField(_ tf: UITextField, shouldChangeCharactersIn range: NSRange, replacementString s: String) -> Bool {
            return false
        }
        
        func handleKeyPress (for textField: UITextField, keyAction: KeyAction) {
            switch keyAction {
            case .insert(let text):
                insert(textField, text: text)
            case .delete:
                delete(textField)
            case .next:
                if parent.numpadHost.focusNext(from: parent.id) {
                    parent.actions.onNext?()
                }
                
            case .prev:
                if parent.numpadHost.focusPrev(from: parent.id) {
                    parent.actions.onPrev?()
                }
            case .dismiss:
                parent.numpadHost.dismissNumpad()
                parent.actions.onDismiss?()
            }
        }
        
        func setSeelectionIfChanged (_ tf: UITextField, to range: NSRange) {
            let cur = tf.selectedRange
            if cur.location != range.location || cur.length != range.length {
                tf.selectedRange = range
            }
        }
        
        private func insert (_ textField: UITextField, text: String) {
            let currentText = textField.text ?? ""
            let selectedRange = textField.selectedRange
            
            switch parent.inputPolicy {
                case .digitsOnly(config: let config):
                    if let (newText, newSelection) = config.safeInsertion(
                        currentText: currentText,
                        selection: selectedRange,
                        inserted: text
                    ) {
                        // NEW
                        if textField.text == newText && textField.selectedRange == newSelection { return }
                        
                        textField.text = newText
                        //textField.selectedRange = newSelection
                        setSeelectionIfChanged(textField, to: newSelection)
                        
                        /*if parent.text != newText {
                            parent.text = newText
                        }*/
                        
                        // NEW
                        scheduleWriteback(newText)
                    }
                case .decimal(config: let config):
                    if let (newText, newSelection) = config.safeInsertion(
                        currentText: currentText,
                        selection: selectedRange,
                        inserted: text
                    ) {
                        if textField.text == newText && textField.selectedRange == newSelection { return }
                        textField.text = newText
                        //textField.selectedRange = newSelection
                        setSeelectionIfChanged(textField, to: newSelection)
                        
                        /*if parent.text != newText {
                            parent.text = newText
                        }*/
                        
                        // NEW
                        scheduleWriteback(newText)
                    }
                
                case .time(config: let config):
                    if let (newText, newSelection) = config.safeInsertion(
                        currentText: currentText,
                        selection: selectedRange,
                        inserted: text
                    ) {
                        if textField.text == newText && textField.selectedRange == newSelection { return }
                        textField.text = newText
                        //textField.selectedRange = newSelection
                        setSeelectionIfChanged(textField, to: newSelection)
                        
                        /*if parent.text != newText {
                            parent.text = newText
                        }*/
                        
                        // NEW
                        scheduleWriteback(newText)
                    }
                }
        }
        
        private func delete(_ textField: UITextField) {
            let currentText = textField.text ?? ""
            let selectedRange = textField.selectedRange
            
            switch parent.inputPolicy {
                case .digitsOnly(config: let config):
                    if let (newText, newSelection) = config.safeDeletion(
                        currentText: currentText,
                        selection: selectedRange
                    ) {
                        if textField.text == newText && textField.selectedRange == newSelection { return }
                        textField.text = newText
                        //textField.selectedRange = newSelection
                        setSeelectionIfChanged(textField, to: newSelection)
                        
                        /*if parent.text != newText {
                            parent.text = newText
                        }*/
                        
                        // NEW
                        scheduleWriteback(newText)
                    }

                case .decimal(config: let config):
                    if let (newText, newSelection) = config.safeDeletion(
                        currentText: currentText,
                        selection: selectedRange
                    ) {
                        if textField.text == newText && textField.selectedRange == newSelection { return }
                        textField.text = newText
                        //textField.selectedRange = newSelection
                        setSeelectionIfChanged(textField, to: newSelection)
                        
                        /*if parent.text != newText {
                            parent.text = newText
                        }*/
                        
                        // NEW
                        scheduleWriteback(newText)
                    }
                case .time(config: let config):
                    if let (newText, newSelection) = config.safeDeletion(
                        currentText: currentText,
                        selection: selectedRange
                    ) {
                        if textField.text == newText && textField.selectedRange == newSelection { return }
                        textField.text = newText
                        //textField.selectedRange = newSelection
                        setSeelectionIfChanged(textField, to: newSelection)
                        
                        /*if parent.text != newText {
                            parent.text = newText
                        }*/
                        
                        // NEW
                        scheduleWriteback(newText)
                    }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
}

enum KeyAction {
    case insert(String)
    case delete
    case next
    case prev
    case dismiss
}

enum NumpadContent {
    case text(String)
    case image(String)
}

public enum InputPolicy {
    case digitsOnly(config: DigitsOnlyPolicy)
    case decimal(config: DecimalPolicy)
    case time(config: TimePolicy)
    
    var keyboardProfile: KeyboardManager.Profile {
        switch self {
        case .digitsOnly:
            return .digitsOnly
        case .decimal:
            return .decimal
        case .time:
            return .time
        }
    }
}

protocol InputPolicyProtocol {
    func safeInsertion (currentText: String, selection: NSRange, inserted: String) -> (String, NSRange)?
    func safeDeletion (currentText: String, selection: NSRange) -> (String, NSRange)?
}

public struct TimePolicy: InputPolicyProtocol, Equatable {

    public enum MaxTimeLimit: Equatable {
        case seconds
        case minutes
        case hours
        case days
    }

    var allowNegative: Bool = false
    var maxTimeLimit: MaxTimeLimit

    public static func == (lhs: TimePolicy, rhs: TimePolicy) -> Bool {
        lhs.allowNegative == rhs.allowNegative && lhs.maxTimeLimit == rhs.maxTimeLimit
    }

    public func safeInsertion(currentText: String, selection: NSRange, inserted: String) -> (String, NSRange)? {
        guard let replaced = replaceRange(in: currentText, selection: selection, with: inserted) else { return nil }
        guard let normalized = normalize(raw: replaced, allowNegative: allowNegative) else { return nil }

        if let cap = capacity(for: maxTimeLimit), normalized.digits.count > cap {
            return nil
        }

        let cappedDigits: [Character]
        if let cap = capacity(for: maxTimeLimit) {
            cappedDigits = Array(normalized.digits.prefix(cap))
        } else {
            cappedDigits = normalized.digits
        }

        let pretty = format(digits: cappedDigits, negative: normalized.negative, limit: maxTimeLimit)
        return (pretty, NSRange(location: pretty.utf16.count, length: 0))
    }

    public func safeDeletion(currentText: String, selection: NSRange) -> (String, NSRange)? {
        guard !currentText.isEmpty else { return nil }
        var deletionRange = selection
        if deletionRange.length == 0 {
            guard deletionRange.location > 0 else { return nil }
            deletionRange = NSRange(location: deletionRange.location - 1, length: 1)
        }
        guard let afterDelete = replaceRange(in: currentText, selection: deletionRange, with: "") else { return nil }
        guard let normalized = normalize(raw: afterDelete, allowNegative: allowNegative) else { return nil }

        let pretty = format(digits: normalized.digits, negative: normalized.negative, limit: maxTimeLimit)
        return (pretty, NSRange(location: pretty.utf16.count, length: 0))
    }

    private func capacity(for limit: MaxTimeLimit) -> Int? {
        switch limit {
            case .seconds: return 2
            case .minutes: return 4
            case .hours:   return 6
            case .days:    return 8
        }
    }
    
    private func replaceRange(in base: String, selection: NSRange, with inserted: String) -> String? {
        guard let r = Range(selection, in: base) else { return nil }
        var s = base
        s.replaceSubrange(r, with: inserted)
        return s
    }

    private func normalize(raw: String, allowNegative: Bool) -> (negative: Bool, digits: [Character])? {
        let trimmed = raw.filter { $0 != ":" && !$0.isWhitespace }
        var negative = false
        var digits: [Character] = []

        for (idx, ch) in trimmed.enumerated() {
            if ch == "-" {
                if allowNegative && idx == 0 && !negative { negative = true } else { return nil }
            } else if ch.isNumber {
                digits.append(ch)
            } else {
                return nil
            }
        }

        
        digits = canonicalDigits(from: digits)
        return (negative, digits)
    }
    
    private func canonicalDigits(from digits: [Character]) -> [Character] {
        var d = digits
        while d.count > 1, d.first == "0" { d.removeFirst() }
        if d.isEmpty { return [] }
        return d
    }

    private func format(digits: [Character], negative: Bool, limit: MaxTimeLimit) -> String {
        if digits.isEmpty { return negative ? "-" : "" }

        func takeRight(_ n: Int, from arr: [Character]) -> (left: [Character], right: [Character]) {
            let right = Array(arr.suffix(n))
            let left  = Array(arr.dropLast(min(n, arr.count)))
            return (left, right)
        }
        func pad2(_ s: String) -> String { s.count == 1 ? "0" + s : (s.isEmpty ? "00" : s) }

        switch limit {
        case .seconds:
            let ss = String(Array(digits.suffix(2)))
            return (negative ? "-" : "") + ss

        case .minutes:
            var left = digits
            let r1 = takeRight(2, from: left); left = r1.left; let ssRaw = String(r1.right)
            let mmRaw = String(left)

            var groups: [String] = []
            if !mmRaw.isEmpty { groups.append(mmRaw) }
            groups.append(ssRaw)

            while groups.count > 1, (groups.first ?? "") == "" || Int(groups.first!) == 0 {
                groups.removeFirst()
            }

            if groups.count == 1 {
                return (negative ? "-" : "") + groups[0]
            } else {
                let head = groups.first!
                let tail = groups.dropFirst().map { pad2($0) }
                return (negative ? "-" : "") + ([head] + tail).joined(separator: ":")
            }

        case .hours:
            var left = digits
            let r1 = takeRight(2, from: left); left = r1.left; let ssRaw = String(r1.right)
            let r2 = takeRight(2, from: left); left = r2.left; let mmRaw = String(r2.right)
            let hhRaw = String(left)

            var groups: [String] = []
            if !hhRaw.isEmpty { groups.append(hhRaw) }
            if !mmRaw.isEmpty || !groups.isEmpty { groups.append(mmRaw) }
            groups.append(ssRaw)

            while groups.count > 1, (groups.first ?? "") == "" || Int(groups.first!) == 0 {
                groups.removeFirst()
            }

            if groups.count == 1 {
                return (negative ? "-" : "") + groups[0]
            } else {
                let head = groups.first!
                let tail = groups.dropFirst().map { pad2($0) }
                return (negative ? "-" : "") + ([head] + tail).joined(separator: ":")
            }

        case .days:
            var left = digits
            let r1 = takeRight(2, from: left); left = r1.left; let ssRaw = String(r1.right)
            let r2 = takeRight(2, from: left); left = r2.left; let mmRaw = String(r2.right)
            let r3 = takeRight(2, from: left); left = r3.left; let hhRaw = String(r3.right)
            let ddRaw = String(left)

            var groups: [String] = []
            if !ddRaw.isEmpty { groups.append(ddRaw) }
            if !hhRaw.isEmpty || !groups.isEmpty { groups.append(hhRaw) }
            if !mmRaw.isEmpty || !groups.isEmpty { groups.append(mmRaw) }
            groups.append(ssRaw)

            while groups.count > 1, (groups.first ?? "") == "" || Int(groups.first!) == 0 {
                groups.removeFirst()
            }

            if groups.count == 1 {
                return (negative ? "-" : "") + groups[0]
            } else {
                let head = groups.first!
                let tail = groups.dropFirst().map { pad2($0) }
                return (negative ? "-" : "") + ([head] + tail).joined(separator: ":")
            }
        }
    }
    
    public func finalizeDisplay(_ currentText: String) -> String {
        guard let norm = normalize(raw: currentText, allowNegative: allowNegative) else { return currentText }
        let negative = norm.negative
        var d = 0, h = 0, m = 0, s = 0

        func read2(_ arr: [Character]) -> (left: [Character], val: Int) {
            let right = Array(arr.suffix(2))
            let left  = Array(arr.dropLast(min(2, arr.count)))
            let v = Int(String(right)) ?? 0
            return (left, v)
        }

        var digits = norm.digits
        var r = read2(digits); digits = r.left; s = r.val
        if maxTimeLimit != .seconds {
            r = read2(digits); digits = r.left; m = r.val
        }
        if maxTimeLimit == .hours || maxTimeLimit == .days {
            r = read2(digits); digits = r.left; h = r.val
        }
        if maxTimeLimit == .days {
            d = Int(String(digits)) ?? 0
        }

        if maxTimeLimit != .seconds {
            m += s / 60; s = s % 60
        }
        if maxTimeLimit == .hours || maxTimeLimit == .days {
            h += m / 60; m = m % 60
        }
        if maxTimeLimit == .days {
            d += h / 24; h = h % 24
        }

        func pad2(_ x: Int) -> String { String(format: "%02d", x) }

        var groups: [String] = []
        switch maxTimeLimit {
        case .seconds:
            groups = ["\(s)"]
        case .minutes:
            groups = ["\(m)", pad2(s)]
        case .hours:
            groups = ["\(h)", pad2(m), pad2(s)]
        case .days:
            groups = ["\(d)", pad2(h), pad2(m), pad2(s)]
        }

        while groups.count > 1, (Int(groups.first ?? "") ?? 0) == 0 {
            groups.removeFirst()
        }

        return (negative ? "-" : "") + groups.joined(separator: ":")
    }
}

public struct DecimalPolicy: InputPolicyProtocol, Equatable {
    var allowNegative: Bool
    var maxDigits: Int
    var maxFractionDigits: Int

    private static let _locale = Locale(identifier: "en_US_POSIX")
    private static let _sepStr: String = _locale.decimalSeparator ?? ","
    private static let _sepChr: Character = Character(_sepStr)
    private static let _minus: Character = "-"

    var decimalSeparator: String { DecimalPolicy._sepStr }

    public static func == (lhs: DecimalPolicy, rhs: DecimalPolicy) -> Bool {
        lhs.allowNegative == rhs.allowNegative &&
        lhs.maxDigits == rhs.maxDigits &&
        lhs.maxFractionDigits == rhs.maxFractionDigits
    }

    @inline(__always) private func isDigitOrSepOrMinus(_ c: Character) -> Bool {
        if c.isNumber { return true }
        if c == DecimalPolicy._minus { return true }
        return c == DecimalPolicy._sepChr
    }

    @inline(__always) private func normalizeInserted(_ s: String) -> String {
        if DecimalPolicy._sepChr == "." {
            return s.map { $0 == "," ? "." : $0 }.reduce(into: "", { $0.append($1) })
        } else if DecimalPolicy._sepChr == "," {
            return s.map { ($0 == "." ? "," : $0) }.reduce(into: "", { $0.append($1) })
        } else {
            return s
        }
    }

    @inline(__always) private func firstUTF16(of s: String, char target: Character) -> Int? {
        guard let i = s.firstIndex(of: target) else { return nil }
        return s.utf16.distance(from: s.utf16.startIndex, to: i)
    }

    @inline(__always) private func countDigitsAroundSep(_ s: String) -> (intDigits: Int, fracDigits: Int, hasSep: Bool, sepUTF16: Int?) {
        var intDigits = 0, fracDigits = 0
        var seenSep = false
        var sepLoc: Int? = nil
        var utf16pos = 0
        for ch in s {
            if !seenSep {
                if ch == DecimalPolicy._sepChr {
                    seenSep = true; sepLoc = utf16pos
                } else if ch.isNumber {
                    intDigits &+= 1
                }
            } else {
                if ch.isNumber { fracDigits &+= 1 }
            }
            utf16pos &+= ch.utf16.count
        }
        return (intDigits, fracDigits, seenSep, sepLoc)
    }

    @inline(__always) private func countMinusAndValidatePosition(_ s: String) -> (count: Int, firstIsMinus: Bool) {
        var cnt = 0
        var firstIsMinus = false
        var i = 0
        for ch in s {
            if ch == DecimalPolicy._minus {
                cnt &+= 1
                if i == 0 { firstIsMinus = true }
            }
            i &+= 1
        }
        return (cnt, firstIsMinus)
    }

    @inline(__always) private func idxInUTF16(_ s: String, offset: Int) -> String.Index? {
        guard let u16 = s.utf16.index(s.utf16.startIndex, offsetBy: offset, limitedBy: s.utf16.endIndex) else { return nil }
        return String.Index(u16, within: s)
    }

    func safeInsertion(currentText: String, selection: NSRange, inserted: String) -> (String, NSRange)? {
        let ins = normalizeInserted(inserted)

        for ch in ins { if !isDigitOrSepOrMinus(ch) { return nil } }

        let base = currentText as NSString
        var candidate = base.replacingCharacters(in: selection, with: ins)

        var sepCount = 0
        for ch in candidate { if ch == DecimalPolicy._sepChr { sepCount &+= 1; if sepCount > 1 { return nil } } }
        let minusInfo = countMinusAndValidatePosition(candidate)
        if minusInfo.count > 1 { return nil }
        if minusInfo.count == 1 && !minusInfo.firstIsMinus { return nil }
        if !allowNegative && minusInfo.count > 0 { return nil }

        let around = countDigitsAroundSep(candidate)
        var intDigits = around.intDigits
        var fracDigits = around.fracDigits
        let hasSep = around.hasSep
        let sepUTF16 = around.sepUTF16

        if hasSep && fracDigits > maxFractionDigits {
            let overflow = fracDigits - maxFractionDigits

            let insLen = (ins as NSString).length
            let insRange = NSRange(location: selection.location, length: insLen)

            let fracStart = (sepUTF16 ?? candidate.utf16.count) + DecimalPolicy._sepStr.utf16.count
            let fracRange = NSRange(location: fracStart, length: max(0, candidate.utf16.count - fracStart))

            let overlapStart = max(insRange.location, fracRange.location)
            let overlapEnd = min(insRange.location + insRange.length, fracRange.location + fracRange.length)
            let overlapLen = max(0, overlapEnd - overlapStart)
            if overlapLen == 0 { return nil }

            let toRemove = min(overflow, overlapLen)
            guard toRemove > 0 else { return nil }

            guard
                let rmStart = idxInUTF16(candidate, offset: overlapEnd - toRemove),
                let rmEnd   = idxInUTF16(candidate, offset: overlapEnd)
            else { return nil }
            candidate.removeSubrange(rmStart..<rmEnd)

            fracDigits -= toRemove
        }

        if intDigits > maxDigits {
            if hasSep {
                let insLen = (ins as NSString).length
                let insRange = NSRange(location: selection.location, length: insLen)
                let intEnd = sepUTF16 ?? candidate.utf16.count
                let intRange = NSRange(location: 0, length: intEnd)

                let overlapStart = max(insRange.location, intRange.location)
                let overlapEnd = min(insRange.location + insRange.length, intRange.location + intRange.length)
                let overlapLen = max(0, overlapEnd - overlapStart)
                if overlapLen == 0 { return nil }

                let overflow = intDigits - maxDigits
                let toRemove = min(overflow, overlapLen)
                guard toRemove > 0 else { return nil }

                guard
                    let rmStart = idxInUTF16(candidate, offset: overlapEnd - toRemove),
                    let rmEnd   = idxInUTF16(candidate, offset: overlapEnd)
                else { return nil }
                candidate.removeSubrange(rmStart..<rmEnd)

                intDigits = countDigitsAroundSep(candidate).intDigits
                if intDigits > maxDigits { return nil }
            } else {
                var insertedAnyDigit = false
                for ch in ins { if ch.isNumber { insertedAnyDigit = true; break } }
                if insertedAnyDigit { return nil }
            }
        }

        let baseWithoutSel = base.replacingCharacters(in: selection, with: "")
        let deltaLen = candidate.utf16.count - baseWithoutSel.utf16.count
        let newLoc = selection.location + max(0, deltaLen)

        return (candidate, NSRange(location: newLoc, length: 0))
    }

    func safeDeletion(currentText: String, selection: NSRange) -> (String, NSRange)? {
        guard !currentText.isEmpty else { return nil }

        var delRange = selection
        if delRange.length == 0 {
            guard delRange.location > 0 else { return nil }
            delRange = NSRange(location: delRange.location - 1, length: 1)
        }

        let ns = currentText as NSString
        var candidate = ns.replacingCharacters(in: delRange, with: "")

        if candidate.last == DecimalPolicy._sepChr {
            candidate.removeLast()
        }

        let minusInfo = countMinusAndValidatePosition(candidate)
        if minusInfo.count > 1 { return nil }
        if minusInfo.count == 1 && !minusInfo.firstIsMinus { return nil }
        if !allowNegative && minusInfo.count > 0 { return nil }
        if allowNegative && candidate == String(DecimalPolicy._minus) { candidate = "" }

        if maxFractionDigits >= 0 {
            if let sepPos = firstUTF16(of: candidate, char: DecimalPolicy._sepChr) {
                let fracStart = sepPos + DecimalPolicy._sepStr.utf16.count
                let fracLen = max(0, candidate.utf16.count - fracStart)
                if fracLen > maxFractionDigits {
                    let keep = maxFractionDigits
                    if let start = idxInUTF16(candidate, offset: fracStart + keep) {
                        candidate.removeSubrange(start..<candidate.endIndex)
                    }
                }
            }
        }

        return (candidate, NSRange(location: delRange.location, length: 0))
    }
}

public struct DigitsOnlyPolicy: InputPolicyProtocol {
    var allowNegative: Bool
    var maxDigits: Int

    @inline(__always) private func isDigitOrMinus(_ c: Character) -> Bool {
        c.isNumber || c == "-"
    }

    @inline(__always) private func countDigits(_ s: String) -> Int {
        var n = 0
        for ch in s { if ch.isNumber { n &+= 1 } }
        return n
    }

    @inline(__always) private func countDigits(in s: String, utf16Range: NSRange) -> Int {
        var n = 0
        var pos = 0
        for ch in s {
            let w = ch.utf16.count
            let next = pos + w

            if next > utf16Range.location && pos < (utf16Range.location + utf16Range.length) {
                if ch.isNumber { n &+= 1 }
            }
            pos = next
            if pos >= utf16Range.location + utf16Range.length { break }
        }
        return n
    }

    @inline(__always) private func hasLeadingMinus(_ s: String) -> Bool {
        s.first == "-"
    }

    func safeInsertion(currentText: String, selection: NSRange, inserted: String) -> (String, NSRange)? {
        for ch in inserted { if !isDigitOrMinus(ch) { return nil } }

        var insertedDigits = ""
        insertedDigits.reserveCapacity(inserted.count)
        var wantsMinus = false
        if allowNegative {
            for ch in inserted {
                if ch == "-" { wantsMinus = true }
                else if ch.isNumber { insertedDigits.append(ch) }
            }
        } else {
            for ch in inserted where ch.isNumber { insertedDigits.append(ch) }
        }

        let currentDigitsCount = countDigits(currentText)
        let selectionDigits = selection.length > 0 ? countDigits(in: currentText, utf16Range: selection) : 0
        let remaining = max(0, maxDigits - (currentDigitsCount - selectionDigits))
        guard remaining > 0 else {
            guard allowNegative, wantsMinus, selection.location == 0 else { return nil }
            let ns = currentText as NSString
            var candidate = ns.replacingCharacters(in: selection, with: "")
            candidate.removeAll(where: { $0 == "-" })
            candidate = "-" + candidate

            if !allowNegative { return nil }
            if !candidate.hasPrefix("-") { return nil }
            let newLoc = selection.location + 1
            return (candidate, NSRange(location: newLoc, length: 0))
        }

        if insertedDigits.utf16.count > remaining {
            var out = ""
            out.reserveCapacity(remaining)
            var taken = 0
            for ch in insertedDigits {
                out.append(ch)
                taken &+= 1
                if taken == remaining { break }
            }
            insertedDigits = out
        }
        
        guard !insertedDigits.isEmpty || (allowNegative && wantsMinus) else { return nil }

        let mayPlaceMinusAtStart = (selection.location == 0)
        let hadMinus = hasLeadingMinus(currentText)

        let selectionRemovesExistingMinus = hadMinus && selection.location == 0 && selection.length > 0
        let keepMinus: Bool = {
            if allowNegative && wantsMinus && mayPlaceMinusAtStart { return true }
            if hadMinus && !selectionRemovesExistingMinus { return true }
            return false
        }()

        let ns = currentText as NSString
        var candidate = ns.replacingCharacters(in: selection, with: insertedDigits)

        if candidate.contains("-") {
            candidate.removeAll(where: { $0 == "-" })
        }
        if keepMinus { candidate = "-" + candidate }

        if candidate.contains("-") && !candidate.hasPrefix("-") { return nil }
        if !allowNegative && candidate.contains("-") { return nil }
        
        if countDigits(candidate) > maxDigits { return nil }

        let deltaInserted =
            (keepMinus && mayPlaceMinusAtStart && selection.location == 0 ? 1 : 0)
            + (insertedDigits as NSString).length
        let newLocation = selection.location + deltaInserted
        return (candidate, NSRange(location: newLocation, length: 0))
    }

    func safeDeletion(currentText: String, selection: NSRange) -> (String, NSRange)? {
        guard !currentText.isEmpty else { return nil }

        var deletionRange = selection
        if deletionRange.length == 0 {
            guard deletionRange.location > 0 else { return nil }
            deletionRange = NSRange(location: deletionRange.location - 1, length: 1)
        }

        let ns = currentText as NSString
        var candidate = ns.replacingCharacters(in: deletionRange, with: "")

        if allowNegative, candidate == "-" {
            candidate = ""
        }

        if countDigits(candidate) > maxDigits { return nil }

        return (candidate, NSRange(location: deletionRange.location, length: 0))
    }
}

fileprivate extension UITextField {
    var selectedRange: NSRange {
        get {
            guard let start = selectedTextRange?.start, let end = selectedTextRange?.end else {
                return NSRange(location: 0, length: 0)
            }
            let location = offset(from: beginningOfDocument, to: start)
            let length = offset(from: start, to: end)
            return NSRange(location: location, length: length)
        }
        set {
            guard let startPos = position(from: beginningOfDocument, offset: newValue.location) else {
                return
            }
            
            let endOffset = newValue.location + newValue.length
            guard let endPos = position(from: beginningOfDocument, offset: endOffset) else {
                return
            }
            selectedTextRange = textRange(from: startPos, to: endPos)
        }
    }
}

final class KeyboardManager {
    static let shared = KeyboardManager()
    
    private var tapGateUntil: CFTimeInterval = 0
    private let tapGateInterval: CFTimeInterval = 0.10
    
    private init () {
        buildKeyboard()
    }
    
    enum Profile {
        case digitsOnly
        case decimal
        case time
    }
    
    private(set) var inputView: UIInputView!
    private var digitsView: UIView!
    private var decimalView: UIView!
    private var timeView: UIView!
    
    weak var keyTarget: KeyboardTarget?
    private var currentProfile: Profile = .digitsOnly
    private var nextGateUntil: CFTimeInterval = 0
    
    private func buildKeyboard () {
        let height: CGFloat = 264
        inputView = UIInputView(frame: .init(x: 0, y: 0, width: 0, height: height), inputViewStyle: .keyboard)
        inputView.autoresizingMask = [.flexibleWidth]
        inputView.translatesAutoresizingMaskIntoConstraints = true
        inputView.allowsSelfSizing = false
        inputView.isOpaque = false
        inputView.backgroundColor = .clear

        digitsView = buildGrid(profile: .digitsOnly)
        decimalView = buildGrid(profile: .decimal)
        timeView = buildGrid(profile: .time)
        
        for v in [digitsView!, decimalView!, timeView!] {
            v.translatesAutoresizingMaskIntoConstraints = false
            inputView.addSubview(v)

            NSLayoutConstraint.activate([
                v.topAnchor.constraint(equalTo: inputView.safeAreaLayoutGuide.topAnchor),
                v.bottomAnchor.constraint(equalTo: inputView.safeAreaLayoutGuide.bottomAnchor),
                v.leadingAnchor.constraint(equalTo: inputView.safeAreaLayoutGuide.leadingAnchor),
                v.trailingAnchor.constraint(equalTo: inputView.safeAreaLayoutGuide.trailingAnchor),
            ])
        }
        
        digitsView.isHidden = false
        decimalView.isHidden = true
        timeView.isHidden = true
    }
    
    func setProfile (_ p: Profile) {
        guard p != currentProfile else { return }
        currentProfile = p
        digitsView.isHidden = (p != .digitsOnly)
        decimalView.isHidden = (p != .decimal)
        timeView.isHidden = (p != .time)
    }
    
    func buildGrid(profile: Profile) -> UIView {
        let wrapper = UIView()
        wrapper.backgroundColor = .clear
        wrapper.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let container = UIStackView()
        container.axis = .vertical
        container.alignment = .fill
        container.distribution = .fillEqually
        container.spacing = 8
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .clear

        func row(_ items: [NumpadContent]) -> UIStackView {
            let r = UIStackView()
            r.axis = .horizontal
            r.alignment = .fill
            r.distribution = .fillEqually
            r.spacing = 8
            items.forEach { content in
                let b = makeButton(content: content)
                r.addArrangedSubview(b)
            }
            return r
        }

        let comma = Locale.current.decimalSeparator ?? "."

        let layout: [[NumpadContent]]
        switch profile {
        case .digitsOnly:
            layout = [
                [.text("1"), .text("2"), .text("3"), .image("keyboard.chevron.compact.down.fill")],
                [.text("4"), .text("5"), .text("6"), .text("-")],
                [.text("7"), .text("8"), .text("9"), .text("-")],
                [.text(""), .text("0"), .image("delete.left.fill"), .text("Next")]
            ]
        case .decimal:
            layout = [
                [.text("1"), .text("2"), .text("3"), .image("keyboard.chevron.compact.down.fill")],
                [.text("4"), .text("5"), .text("6"), .text("-")],
                [.text("7"), .text("8"), .text("9"), .text("-")],
                [.text(comma), .text("0"), .image("delete.left.fill"), .text("Next")]
            ]
        case .time:
            layout = [
                [.text("1"), .text("2"), .text("3"), .image("keyboard.chevron.compact.down.fill")],
                [.text("4"), .text("5"), .text("6"), .text("Prev")],
                [.text("7"), .text("8"), .text("9"), .text("Next")],
                [.text(""), .text("0"), .image("delete.left.fill"), .text("Done")]
            ]
        }

        layout.forEach { container.addArrangedSubview(row($0)) }
        wrapper.addSubview(container)

        // 🔲 Tilføj padding via Auto Layout (hurtigt og sikkert)
        let padding: CGFloat = 12
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: padding),
            container.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -padding),
            container.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: padding),
            container.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -padding)
        ])

        return wrapper
    }
    
    private func makeButton(content: NumpadContent) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(nil, for: .normal)
        b.tintColor = .white
        b.setTitleColor(.white, for: .normal)
        b.backgroundColor = UIColor.systemIndigo
        b.layer.cornerRadius = 12
        b.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)

        switch content {
        case .text(let t):
            if t.isEmpty {
                b.isEnabled = false
                b.backgroundColor = UIColor.systemIndigo.withAlphaComponent(0.3)
            } else {
                b.setTitle(t, for: .normal)
            }
        case .image(let name):
            b.setImage(UIImage(systemName: name), for: .normal)
        }

        // Brug label som “payload”
        b.accessibilityLabel = {
            switch content {
            case .text(let t): return t
            case .image(let name): return name
            }
        }()

        b.addTarget(self, action: #selector(handleTap(_:)), for: .touchUpInside)
        return b
    }
    
    @objc private func handleTap(_ sender: UIButton) {
        let now = CACurrentMediaTime()
        if now < tapGateUntil { return }
        tapGateUntil = now + tapGateInterval
        
        if let title = sender.title(for: .normal), !title.isEmpty {
            switch title {
            case "Next":
                if now < nextGateUntil { return }
                nextGateUntil = now + 0.1
                self.keyTarget?.onKey(KeyAction.next)
            case "Prev":
                self.keyTarget?.onKey(KeyAction.prev)
            case "Done":
                self.keyTarget?.onKey(KeyAction.dismiss)
            default:
                self.keyTarget?.onKey(KeyAction.insert(title))
            }
            return
        }

        let id = sender.accessibilityLabel ?? ""
        if id == "delete.left.fill" {
            self.keyTarget?.onKey(KeyAction.delete)
            return
        }
        if id == "keyboard.chevron.compact.down.fill" {
            self.keyTarget?.onKey(KeyAction.dismiss)
            return
        }
    }
}

protocol KeyboardTarget: AnyObject {
    func onKey (_ action: KeyAction)
}

