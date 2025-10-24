import Foundation
import UIKit

public enum FieldTextAlignment: Equatable {
    case leading, center, trailing
}

public struct FieldConfig {
    public var font: UIFont
    public var textColor: UIColor
    public var selectionColor: UIColor
    public var caretColor: UIColor
    public var insets: FieldInsets
    public var alignment: FieldTextAlignment
    public var actions: FieldsActions
    
    public var placeholderText: String?
    public var placeholderFont: UIFont?
    public var placeholderColor: UIColor?
    
    public init(
        font: UIFont = .monospacedSystemFont(ofSize: 14, weight: .regular),
        textColor: UIColor = .label,
        selectionColor: UIColor = UIColor.blue.withAlphaComponent(0.2),
        caretColor: UIColor = .label,
        insets: FieldInsets = .default,
        alignment: FieldTextAlignment = .center,
        actions: FieldsActions = .init(),
        placeholderText: String = "",
        placeholderFont: UIFont? = nil,
        placeholderColor: UIColor? = nil,
    ) {
        self.font = font
        self.textColor = textColor
        self.selectionColor = selectionColor
        self.caretColor = caretColor
        self.insets = insets
        self.alignment = alignment
        self.placeholderText = placeholderText
        self.placeholderFont = placeholderFont
        self.placeholderColor = placeholderColor
        self.actions = actions
    }
}

public struct FieldMetrics {
    public let font: UIFont
    public let charAdvance: CGFloat
    public let ascent: CGFloat
    public let descent: CGFloat
    public let leading: CGFloat
    public let lineHeight: CGFloat

    public init(font: UIFont) {
        self.font = font
        let attr: [NSAttributedString.Key: Any] = [.font: font]
        let w = ("8" as NSString).size(withAttributes: attr).width
        self.charAdvance = ceil(w)

        var asc: CGFloat = 0, dsc: CGFloat = 0, l: CGFloat = 0
        let ctFont = CTFontCreateWithFontDescriptor(font.fontDescriptor, font.pointSize, nil)
        asc = CTFontGetAscent(ctFont)
        dsc = CTFontGetDescent(ctFont)
        l = CTFontGetLeading(ctFont)
        self.ascent = asc
        self.descent = dsc
        self.leading = l
        self.lineHeight = ceil(asc + dsc + l)
    }
}

public struct FieldInsets: Equatable {
    public var top: CGFloat = 6
    public var left: CGFloat = 8
    public var bottom: CGFloat = 6
    public var right: CGFloat = 8
    public static let `default` = FieldInsets()
}

private final class LineLayout {
    private var font: CTFont
    private var attr: [NSAttributedString.Key: Any]
    private var ctLine: CTLine = CTLineCreateWithAttributedString(NSAttributedString(string: "") as CFAttributedString)

    init(uiFont: UIFont) {
        self.font = CTFontCreateWithFontDescriptor(uiFont.fontDescriptor, uiFont.pointSize, nil)
        // slå kerning fra for fuld 1:1 hit-test
        self.attr = [.font: uiFont, .kern: 0]
        rebuild(for: "")
    }

    func rebuild(for text: String) {
        let at = NSAttributedString(string: text, attributes: attr)
        ctLine = CTLineCreateWithAttributedString(at as CFAttributedString)
    }

    /// X-position for en UTF-16 caret index (clampet)
    func x(forUTF16 idx: Int) -> CGFloat {
        let length = CTLineGetStringRange(ctLine).length
        let clamped = max(0, min(idx, length))
        var secondary: CGFloat = 0
        let x = CTLineGetOffsetForStringIndex(ctLine, clamped, &secondary)
        return x
    }

    /// Hit-test: find nærmeste UTF-16 index for et x (lokalt i linjen)
    func index(forX x: CGFloat) -> Int {
        let i = CTLineGetStringIndexForPosition(ctLine, CGPoint(x: x, y: 0))
        if i == kCFNotFound { return CTLineGetStringRange(ctLine).location + CTLineGetStringRange(ctLine).length }
        return i
    }
    
    func width() -> CGFloat {
        var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
        let w = CGFloat(CTLineGetTypographicBounds(ctLine, &ascent, &descent, &leading))
        return ceil(max(0, w))
    }
}

extension FieldView: UIGestureRecognizerDelegate {
    override public func gestureRecognizerShouldBegin(_ gr: UIGestureRecognizer) -> Bool {
        if gr === longPressGR, let sel = value.selection, !sel.isEmpty {
            return false
        }

        if gr === panGR, let sel = value.selection, !sel.isEmpty {
            let p = gr.location(in: self)
            let slop: CGFloat = handleHitSlop
            let onLeft  = leftHandle.frame.insetBy(dx: -slop, dy: -slop).contains(p)
            let onRight = rightHandle.frame.insetBy(dx: -slop, dy: -slop).contains(p)
            return onLeft || onRight
        }
        return true
    }

    public func gestureRecognizer(_ gr: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        if (gr === panGR && other === longPressGR) || (gr === longPressGR && other === panGR) {
            return false
        }
        
        return false
    }

    public func gestureRecognizer(_ gr: UIGestureRecognizer, shouldRequireFailureOf other: UIGestureRecognizer) -> Bool {
        if gr === panGR && other === longPressGR { return false }
        
        return false
    }

    public func gestureRecognizer(_ gr: UIGestureRecognizer, shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
        if gr === longPressGR && other === panGR { return true }
        
        return false
    }
}


public final class FieldView: UIView, FieldEndpoint {

    private var lineLayout: LineLayout!
    
    public private(set) var id: FieldID = .init()
    public var inputPolicy: _InputPolicy
    public func apply(_ value: NumericValue) { setValue(value, animated: false) }
    weak var host: _NumpadHost?
    private(set) var metrics: FieldMetrics = .init(font: .monospacedSystemFont(ofSize: 18, weight: .regular))
    private var config: FieldConfig
    public var insets: FieldInsets = .default { didSet { setNeedsLayout() } }
    private var value: NumericValue = .init()
    private var isActive: Bool = false { didSet { updateActiveState() } }
    var onTextChanged: ((String) -> Void)?
    
    private let textLayer = CATextLayer()
    private let caretLayer = CALayer()
    private let selectionLayer = CALayer()
    
    private lazy var tapGR = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
    private lazy var doubleTapGR: UITapGestureRecognizer = {
        let g = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        g.numberOfTapsRequired = 2
        return g
    }()
    
    private var selectionAnchorUTF16: Int?
    
    private let handleSize: CGFloat = 12
    private let handleHitSlop: CGFloat = 16
    private enum DragMode { case none, adjustStart, adjustEnd }
    private var dragMode: DragMode = .none
    private var fixedAnchor: Int?
    private lazy var panGR: UIPanGestureRecognizer = {
        let g = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        g.maximumNumberOfTouches = 1
        g.minimumNumberOfTouches = 1
        g.delegate = self
        return g
    }()
    
    private let handleRadius: CGFloat = 7
    private var leftHandle: CALayer = CALayer()
    private var rightHandle: CALayer = CALayer()
    
    private let placeholderLayer = CATextLayer()


    public init (inputPolicy: _InputPolicy, config: FieldConfig) {
        self.inputPolicy = inputPolicy
        self.config = config
        super.init(frame: .zero)
        commonInit()
    }
    
    public override init (frame: CGRect) {
        fatalError("Use init(inputPolicy:) instead.")

    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func commonInit() {
        selectionLayer.backgroundColor = config.selectionColor.cgColor
        selectionLayer.isHidden = true
        layer.addSublayer(selectionLayer)

        caretLayer.backgroundColor = UIColor.label.cgColor
        caretLayer.isHidden = true
        layer.addSublayer(caretLayer)
        
        placeholderLayer.contentsScale = UIScreen.main.scale
        placeholderLayer.alignmentMode = .left
        placeholderLayer.truncationMode = .none
        placeholderLayer.isWrapped = false
        layer.addSublayer(placeholderLayer)

        textLayer.contentsScale = UIScreen.main.scale
        textLayer.alignmentMode = .left
        textLayer.truncationMode = .none
        textLayer.isWrapped = false
        textLayer.foregroundColor = UIColor.label.cgColor
        layer.addSublayer(textLayer)

        addGestureRecognizer(tapGR)
        addGestureRecognizer(doubleTapGR)
        addGestureRecognizer(longPressGR)

        addGestureRecognizer(panGR)
        
        leftHandle.backgroundColor = config.selectionColor.cgColor
        leftHandle.cornerRadius = 7
        leftHandle.isHidden = true
        rightHandle.backgroundColor = config.selectionColor.cgColor
        rightHandle.cornerRadius = 7
        rightHandle.isHidden = true
        layer.addSublayer(leftHandle)
        layer.addSublayer(rightHandle)

        isAccessibilityElement = true
        accessibilityTraits = [.updatesFrequently]
        accessibilityLabel = "Number field"
        
        disableImplicitAnimations(for: placeholderLayer)
        disableImplicitAnimations(for: textLayer)
        disableImplicitAnimations(for: selectionLayer)
        disableImplicitAnimations(for: leftHandle)
        disableImplicitAnimations(for: rightHandle)
        disableImplicitAnimations(for: layer)

        disableImplicitAnimations(for: caretLayer, keepOpacity: true)
    }
    
    private func contentOffsetX() -> CGFloat {
        let available = textLayer.bounds.width
        let w = min(available, lineLayout.width())
        switch config.alignment {
            case .leading:  return 0
            case .center:   return (available - w) * 0.5
            case .trailing: return (available - w)
        }
    }
    
    public func becomeActive() {
        isActive = true

        let n = value.text.utf16Count
        if n > 0, value.selection == nil {
            var t = value
            t.selection = 0..<n
            t.caret = n
            setValue(t, animated: false)
        }

        layoutSelection()
        layoutCaret()
        updateHandles()
        updateGestureEnabling()
    }
    
    public func resignActive() {
        isActive = false
    }
    
    public var currentValue: NumericValue {
        value
    }

    public func configure(
        id: FieldID,
        host: _NumpadHost,
        initial: NumericValue,
        config: FieldConfig
    ) {
        self.id = id
        self.host = host
        self.config = config
        self.metrics = .init(font: config.font)
        self.lineLayout = LineLayout(uiFont: config.font)
        self.insets = config.insets
        
        setValue(initial, animated: false)
        
        textLayer.font = config.font
        textLayer.fontSize = config.font.pointSize
        textLayer.foregroundColor = config.textColor.cgColor
        
        placeholderLayer.font = config.placeholderFont ?? config.font
        placeholderLayer.fontSize = config.placeholderFont?.pointSize ?? config.font.pointSize
        placeholderLayer.foregroundColor = config.placeholderColor?.cgColor ?? config.textColor.cgColor
        placeholderLayer.string = (config.placeholderText ?? "") as NSString?
        
        selectionLayer.backgroundColor = config.selectionColor.withAlphaComponent(0.2).cgColor
        leftHandle.backgroundColor = config.selectionColor.cgColor
        rightHandle.backgroundColor = config.selectionColor.cgColor
        caretLayer.backgroundColor = config.caretColor.cgColor
        
        setNeedsLayout()
        
        host.setActions(config.actions, for: id)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        let x = insets.left
        let y = (bounds.height - metrics.lineHeight) * 0.5
        let width = bounds.width - insets.left - insets.right
        
        textLayer.frame = CGRect(x: x, y: y, width: width, height: metrics.lineHeight)
        textLayer.frame.origin.x += textAlignmentOffset()
        
        placeholderLayer.frame = CGRect(x: x, y: y, width: width, height: metrics.lineHeight)
        placeholderLayer.frame.origin.x += placeholderAlignmentOffset()
        placeholderLayer.isHidden = !(value.text.isEmpty && (config.placeholderText?.isEmpty == false))

        layoutSelection()
        layoutCaret()
    }
    
    public func applyExternalText (_ newText: String) {
        var nv = value
        if nv.text == newText { return }
        nv.text = newText
        
        let maxCaret = newText.utf16.count
        if nv.caret > maxCaret {
            nv.caret = maxCaret
        }
        
        setValue(nv, animated: false)
    }
    
    private func placeholderWidth() -> CGFloat {
        guard let s = config.placeholderText, !s.isEmpty else { return 0 }
        let attr: [NSAttributedString.Key: Any] = [.font: config.placeholderFont ?? config.font]
        return ceil((s as NSString).size(withAttributes: attr).width)
    }
    
    private func textAlignmentOffset() -> CGFloat {
        let available = textLayer.bounds.width
        let lineW = min(available, lineLayout.width())
        switch config.alignment {
        case .leading:  return 0
        case .center:   return max(0, (available - lineW) * 0.5)
        case .trailing: return max(0, (available - lineW))
        }
    }

    private func placeholderAlignmentOffset() -> CGFloat {
        let available = placeholderLayer.bounds.width
        let w = min(available, placeholderWidth())
        switch config.alignment {
        case .leading:  return 0
        case .center:   return max(0, (available - w) * 0.5)
        case .trailing: return max(0, (available - w))
        }
    }
    
    private func disableImplicitAnimations(for layer: CALayer, keepOpacity: Bool = false) {
        var actions: [String: CAAction] = [
            "contents": NSNull(),
            "bounds": NSNull(),
            "position": NSNull(),
            "frame": NSNull(),
            "transform": NSNull(),
            "backgroundColor": NSNull(),
            "cornerRadius": NSNull(),
            "borderWidth": NSNull(),
            "borderColor": NSNull()
        ]
        if !keepOpacity {
            actions["opacity"] = NSNull()
        }
        layer.actions = actions
    }

    private func updateHandles() {
        guard isActive, let sel = value.selection, sel.count > 0 else {
            leftHandle.isHidden = true
            rightHandle.isHidden = true
            return
        }

        let x1 = caretX(forUTF16: sel.lowerBound)
        let x2 = caretX(forUTF16: sel.upperBound)
        let y  = textLayer.frame.minY
        let h  = metrics.lineHeight
        let r  = handleRadius

        leftHandle.isHidden = false
        rightHandle.isHidden = false

        leftHandle.frame = CGRect(x: x1 - r * 2, y: y + h - 2*r, width: 2*r, height: 2*r)
        rightHandle.frame = CGRect(x: x2, y: y + h - 2*r, width: 2*r, height: 2*r)
    }


    private func setValue(_ newValue: NumericValue, animated: Bool) {
        guard value != newValue else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        let old = value

        value = normalized(newValue)
        textLayer.string = value.text as NSString
        lineLayout.rebuild(for: value.text)

        let baseX = insets.left
        let baseY = textLayer.frame.origin.y
        let width = bounds.width - insets.left - insets.right
        
        textLayer.frame = CGRect(x: baseX, y: baseY, width: width, height: metrics.lineHeight)
        textLayer.frame.origin.x += textAlignmentOffset()
        
        
        placeholderLayer.frame = CGRect(x: baseX, y: baseY, width: width, height: metrics.lineHeight)
        placeholderLayer.frame.origin.x += placeholderAlignmentOffset()
        placeholderLayer.isHidden = !(value.text.isEmpty && (config.placeholderText?.isEmpty == false))

        layoutSelection()
        layoutCaret()
        updateHandles()
        updateGestureEnabling()

        CATransaction.commit()
        
        if old.text != value.text {
            onTextChanged?(value.text)
        }
    }

    private func normalized(_ v: NumericValue) -> NumericValue {
        var t = v
        let n = t.text.utf16.count
        t.caret = min(max(0, t.caret), n)
        
        if let sel = t.selection {
            let lo = min(max(0, sel.lowerBound), n)
            let hi = min(max(0, sel.upperBound), n)
            t.selection = lo < hi ? lo..<hi : nil
        }
        
        return t
    }

    private func layoutCaret() {
        guard isActive else { caretLayer.isHidden = true; return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        caretLayer.isHidden = false
        let x = caretX(forUTF16: value.caret) - 2
        let y = textLayer.frame.minY + max(0, (metrics.lineHeight - metrics.ascent - metrics.descent) * 0.5) - 2
        let h = metrics.ascent + metrics.descent + 4
        caretLayer.frame = CGRect(x: x, y: y, width: 2, height: h)
        ensureCaretBlink()
        
        CATransaction.commit()
    }

    private func layoutSelection() {
        guard isActive else {
            selectionLayer.isHidden = true
            leftHandle.isHidden = true
            rightHandle.isHidden = true
            return
        }

        guard let sel = value.selection, sel.count > 0 else {
            selectionLayer.isHidden = true
            leftHandle.isHidden = true
            rightHandle.isHidden = true
            return
        }
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        selectionLayer.isHidden = false
        let x1 = caretX(forUTF16: sel.lowerBound)
        let x2 = caretX(forUTF16: sel.upperBound)
        let y  = textLayer.frame.minY
        selectionLayer.frame = CGRect(x: min(x1, x2),
                                      y: y,
                                      width: max(1, abs(x2 - x1)),
                                      height: metrics.lineHeight)

        updateHandles()
        CATransaction.commit()
    }

    private func caretX(forUTF16 idx: Int) -> CGFloat {
        let local = lineLayout.x(forUTF16: idx)
        return textLayer.frame.minX + local
    }

    private func updateActiveState() {
        caretLayer.isHidden = !isActive
        selectionLayer.opacity = isActive ? 1 : 0
        
        if isActive {
            ensureCaretBlink()
        } else {
            caretLayer.removeAnimation(forKey: "blink")
            leftHandle.isHidden = true
            rightHandle.isHidden = true
        }
    }

    private func ensureCaretBlink() {
        guard caretLayer.animation(forKey: "blink") == nil else { return }
        let a = CABasicAnimation(keyPath: "opacity")
        a.fromValue = 1
        a.toValue = 0
        a.autoreverses = true
        a.repeatCount = .infinity
        a.duration = 0.7
        caretLayer.add(a, forKey: "blink")
    }
    
    private func updateGestureEnabling() {
        let hasSelection = (value.selection?.isEmpty == false)
        panGR.isEnabled = hasSelection
        longPressGR.isEnabled = !hasSelection
    }
    
    @inline(__always)
    private func localX(for point: CGPoint) -> CGFloat {
        return max(0, point.x - textLayer.frame.minX)
    }

    @objc private func handleTap(_ g: UITapGestureRecognizer) {
        guard g.state == .ended else { return }
        
        if !isActive {
            isActive = true
            host?.setActive(id)
        }
        
        let idx = lineLayout.index(forX: localX(for: g.location(in: self)))
        let clamped = max(0, min(idx, value.text.utf16Count))
        if value.caret != clamped || value.selection != nil {
            var t = value
            t.caret = clamped
            t.selection = nil
            setValue(t, animated: false)
            layoutCaret()
            updateGestureEnabling()
        }
    }

    @objc private func handleDoubleTap(_ g: UITapGestureRecognizer) {
        guard g.state == .ended else { return }
        let n = value.text.utf16Count
        guard n > 0 else { return }

        var t = value
        t.selection = 0..<n
        t.caret = n
        setValue(t, animated: false)
        layoutSelection()
        layoutCaret()
        updateHandles()
        updateGestureEnabling()
    }

    public func handleKey(_ key: NumpadKey) {
        host?.handleKey(key)
    }
    
    // NEW
    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        let p = g.location(in: self)
        switch g.state {
            case .began:
                guard let sel = value.selection else { return }

                let slop: CGFloat = 16
                let leftHit  = leftHandle.frame.insetBy(dx: -slop, dy: -slop).contains(p)
                let rightHit = rightHandle.frame.insetBy(dx: -slop, dy: -slop).contains(p)

                if leftHit {
                    dragMode = .adjustStart
                    fixedAnchor = sel.upperBound
                } else if rightHit {
                    dragMode = .adjustEnd
                    fixedAnchor = sel.lowerBound
                } else {
                    dragMode = .none
                }

            case .changed:
                guard dragMode != .none, let anchor = fixedAnchor else { return }
                let cur = lineLayout.index(forX: localX(for: p))
                var t = value
                switch dragMode {
                case .adjustStart:
                    let lo = min(cur, anchor), hi = max(cur, anchor)
                    t.selection = lo < hi ? lo..<hi : nil
                    t.caret = lo
                case .adjustEnd:
                    let lo = min(anchor, cur), hi = max(anchor, cur)
                    t.selection = lo < hi ? lo..<hi : nil
                    t.caret = hi
                case .none: break
                }
                setValue(t, animated: false)

            case .ended, .cancelled, .failed:
                dragMode = .none
                fixedAnchor = nil
                
                if value.selection?.isEmpty == true {
                    var t = value
                    t.selection = nil
                    setValue(t, animated: false)
                }
                
                updateGestureEnabling()

            default: break
        }
    }
    
    @inline(__always)
    private func utf16Index(at point: CGPoint) -> Int {
        let localX = max(0, point.x - textLayer.frame.minX)
        return lineLayout.index(forX: localX)
    }
    
    @objc private func handleLongPress(_ g: UILongPressGestureRecognizer) {
        let p = g.location(in: self)

        switch g.state {
            case .began:
                if host?.activeId != id { isActive = true; host?.setActive(id) }

                let i = lineLayout.index(forX: localX(for: p))
                selectionAnchorUTF16 = i

                var t = value
                t.caret = i
                t.selection = nil
                setValue(t, animated: false)
                layoutCaret()
                updateGestureEnabling()

            case .changed:
                guard let anchor = selectionAnchorUTF16 else { return }
                let cur = lineLayout.index(forX: localX(for: p))
            
                var lo = anchor, hi = cur
                if cur < anchor { swap(&lo, &hi) }

                var t = value
                t.caret = cur
                t.selection = (lo != hi) ? lo..<hi : nil
                setValue(t, animated: false)
                layoutSelection()

            case .ended, .cancelled, .failed:
                if value.selection?.isEmpty == true {
                    var t = value; t.selection = nil; setValue(t, animated: false)
                }
                selectionAnchorUTF16 = nil
                updateGestureEnabling()

        default:
            break
        }
    }
    
    private lazy var longPressGR: UILongPressGestureRecognizer = {
        let g = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        g.minimumPressDuration = 0.2
        g.allowableMovement = 8
        return g
    }()
}
