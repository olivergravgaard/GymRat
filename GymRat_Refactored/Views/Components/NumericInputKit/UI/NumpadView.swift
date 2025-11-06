import UIKit
import ObjectiveC.runtime

final class NumpadView: UIView {
    private weak var sink: NumpadKeySink?
    private var currentTree: KeyboardNode?
    
    private let downFeedback = UIImpactFeedbackGenerator(style: .light)

    init(host: any NumpadHosting) {
        self.sink = host
        super.init(frame: .zero)
        isOpaque = false
        backgroundColor = .clear
        
        downFeedback.prepare()
    }

    required init?(coder: NSCoder) { fatalError() }

    public func applyTree(_ tree: KeyboardNode) {
        guard tree != currentTree else { return }
        currentTree = tree
        rebuild(from: tree)
    }

    private func rebuild(from tree: KeyboardNode) {
        subviews.forEach { $0.removeFromSuperview() }

        let contentPadding: CGFloat = 24

        let root = makeView(for: tree)
        root.translatesAutoresizingMaskIntoConstraints = false
        root.backgroundColor = .clear

        addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: leadingAnchor, constant: contentPadding),
            root.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -contentPadding),
            root.topAnchor.constraint(equalTo: topAnchor, constant: contentPadding),
            root.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -contentPadding),
        ])
    }

    private func makeView(for node: KeyboardNode) -> UIView {
        switch node {
        case .empty:
            return UIView()

        case .spacer(let flex):
            let v = UIView()
            if flex > 1 {
                // i en stack anvender vi setContentHugging/Compression så den får plads
                v.setContentHuggingPriority(.defaultLow, for: .horizontal)
                v.setContentHuggingPriority(.defaultLow, for: .vertical)
            }
            return v

        case .button(let title, let key, let style):
            return makeButton(title: title, key: key, style: style)

        case .vstack(let spacing, let children):
            let sv = UIStackView()
            sv.axis = .vertical
            sv.alignment = .fill
            sv.distribution = .fillEqually
            sv.spacing = spacing
            children.forEach { sv.addArrangedSubview(makeView(for: $0)) }
            return sv

        case .hstack(let spacing, let children):
            let sv = UIStackView()
            sv.axis = .horizontal
            sv.alignment = .fill
            sv.distribution = .fillEqually
            sv.spacing = spacing
            children.forEach { sv.addArrangedSubview(makeView(for: $0)) }
            return sv

        case .grid(let columns, let rowSpacing, let colSpacing, let items):
            let rows = Int(ceil(Double(items.count) / Double(max(1, columns))))
            let vStack = UIStackView()
            vStack.axis = .vertical
            vStack.alignment = .fill
            vStack.distribution = .fillEqually
            vStack.spacing = rowSpacing

            for r in 0..<rows {
                let h = UIStackView()
                h.axis = .horizontal
                h.alignment = .fill
                h.distribution = .fillEqually
                h.spacing = colSpacing
                let start = r*columns
                let end = min(start+columns, items.count)
                for i in start..<end {
                    h.addArrangedSubview(makeView(for: items[i]))
                }
                // fyld op med tomme så alle rækker har columns
                if end - start < columns {
                    for _ in 0..<(columns - (end - start)) {
                        h.addArrangedSubview(UIView())
                    }
                }
                vStack.addArrangedSubview(h)
            }
            
            return vStack

        case .box(let padding, let child):
            let container = UIView()
            let inner = makeView(for: child)
            inner.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(inner)
            NSLayoutConstraint.activate([
                inner.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding.left),
                inner.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -padding.right),
                inner.topAnchor.constraint(equalTo: container.topAnchor, constant: padding.top),
                inner.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -padding.bottom),
            ])
            return container

        case .aspectRatio(let ratio, let child):
            let container = UIView()
            let inner = makeView(for: child)
            inner.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(inner)
            NSLayoutConstraint.activate([
                inner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                inner.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                inner.widthAnchor.constraint(lessThanOrEqualTo: container.widthAnchor),
                inner.heightAnchor.constraint(lessThanOrEqualTo: container.heightAnchor),
                inner.widthAnchor.constraint(equalTo: inner.heightAnchor, multiplier: ratio)
            ])
            // fill så langt det kan uden at bryde ratio
            inner.setContentCompressionResistancePriority(.required, for: .horizontal)
            inner.setContentCompressionResistancePriority(.required, for: .vertical)
            return container

        case .zstack(let children):
            let container = UIView()
            for child in children {
                let v = makeView(for: child)
                v.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(v)
                NSLayoutConstraint.activate([
                    v.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    v.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                    v.topAnchor.constraint(equalTo: container.topAnchor),
                    v.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                ])
            }
            return container

        case .overlay(let anchor, let child):
            // anchor.x/anchor.y i [0,1]: (0,0)=top-left, (1,1)=bottom-right
            let container = UIView()
            let v = makeView(for: child)
            v.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(v)
            let cx = v.centerXAnchor.constraint(equalTo: container.leadingAnchor, constant: anchor.x)
            let cy = v.centerYAnchor.constraint(equalTo: container.topAnchor, constant: anchor.y)
            // Men vi vil typisk sammen med zstack/box; keep simple: center i container og lad padding/box styre placering
            NSLayoutConstraint.deactivate([cx, cy])
            NSLayoutConstraint.activate([
                v.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                v.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            ])
            return container
        }
    }

    private func makeButton(title: String, key: NumpadKey, style: KeyboardButtonStyle) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: style.fontSize, weight: style.weight)
        b.backgroundColor = style.fillColor
        b.layer.cornerRadius = style.cornerRadius
        b.layer.borderWidth = style.borderWidth
        b.layer.borderColor = style.borderColor.cgColor
        b.setTitleColor(style.titleColor, for: .normal)
        objc_setAssociatedObject(b, &AssociatedKey.payloadKey, Payload(key: key), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        b.addTarget(self, action: #selector(onTap(_:)), for: .touchUpInside)
        
        return b
    }

    @objc private func onTap(_ sender: UIButton) {
        if let payload = objc_getAssociatedObject(sender, &AssociatedKey.payloadKey) as? Payload {
            downFeedback.impactOccurred()
            downFeedback.prepare()
            sink?.handleKey(payload.key)
        }
    }

    private struct Payload { let key: NumpadKey }
    private struct AssociatedKey {
        static var payloadKey: UInt8 = 0
    }
}
