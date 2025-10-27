import UIKit
import ObjectiveC.runtime
/*
final class NumpadView: UIView {
    private weak var sink: NumpadKeySink?
    private let showNavigation: Bool
    
    init(host: any NumpadHosting) {
        self.sink = host
        self.showNavigation = host.supportsNavigation
        super.init(frame: .zero)
        isOpaque = true
        backgroundColor = .secondarySystemBackground
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.1
        layer.shadowRadius = 8
        layer.shadowOffset = .init(width: 0,height: -2)
        buildLayout()
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    private func buildLayout() {
        let rows = UIStackView()
        rows.axis = .vertical
        rows.alignment = .fill
        rows.distribution = .fillEqually
        rows.spacing = 8
        rows.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rows)
        NSLayoutConstraint.activate(
            [
                rows.leadingAnchor.constraint(
                    equalTo: leadingAnchor,
                    constant: 12
                ),
                rows.trailingAnchor.constraint(
                    equalTo: trailingAnchor,
                    constant: -12
                ),
                rows.topAnchor.constraint(
                    equalTo: safeAreaLayoutGuide.topAnchor,
                    constant: 8
                ),
                rows.bottomAnchor.constraint(
                    equalTo: safeAreaLayoutGuide.bottomAnchor,
                    constant: -8
                )
            ]
        )
        
        func row(_ items: [UIButton]) -> UIStackView {
            let r = UIStackView(arrangedSubviews: items)
            r.axis = .horizontal
            r.alignment = .fill
            r.distribution = .fillEqually
            r.spacing = 8
            return r
        }
        
        func key(_ title: String, _ action: Selector) -> UIButton {
            let b = UIButton(type: .system)
            b.setTitle(title,for: .normal)
            b.titleLabel?.font = .systemFont(ofSize: 22, weight: .semibold)
            b.backgroundColor = .systemBackground
            b.layer.cornerRadius = 12
            b.layer.borderWidth = 0.5
            b.layer.borderColor = UIColor.separator.cgColor
            b.addTarget(self, action: action, for: .touchUpInside)
            return b
        }
        
        rows.addArrangedSubview(
            row(
                [
                    key("1", #selector(t1)),
                    key("2", #selector(t2)),
                    key("3", #selector(t3)),
                    key("Prev", #selector(prev))
                ]
            )
        )
        
        rows.addArrangedSubview(
            row(
                [
                    key("4", #selector(t4)),
                    key("5", #selector(t5)),
                    key("6", #selector(t6)),
                    key("Next", #selector(didTapNext))
                ]
            )
        )
        
        rows.addArrangedSubview(
            row(
                [
                    key("7", #selector(t7)),
                    key("8", #selector(t8)),
                    key("9", #selector(t9)),
                    key(
                        "⌫",
                        #selector(
                            backspace
                        )
                    )
                ]
            )
        )
        
        rows.addArrangedSubview(
            row(
                [
                    key(".", #selector(dot)),
                    key("0", #selector(t0)),
                    key("Clear", #selector(clear)),
                    key("Done", #selector(done))
                ]
            )
        )
    }
    
    @objc private func t0() {
        sink?.handleKey(.digit("0"))
    }
    
    @objc private func t1() {
        sink?.handleKey(.digit("1"))
    }
    
    @objc private func t2() {
        sink?.handleKey(.digit("2"))
    }
    
    @objc private func t3() {
        sink?.handleKey(.digit("3"))
    }
    
    @objc private func t4() {
        sink?.handleKey(.digit("4"))
    }
    
    @objc private func t5() {
        sink?.handleKey(.digit("5"))
    }
    
    @objc private func t6() {
        sink?.handleKey(.digit("6"))
    }
    
    @objc private func t7() {
        sink?.handleKey(.digit("7"))
    }
    
    @objc private func t8() {
        sink?.handleKey(.digit("8"))
    }
    
    @objc private func t9() {
        sink?.handleKey(.digit("9"))
    }
    
    @objc private func dot() {
        sink?.handleKey(.decimal)
    }
    
    @objc private func backspace() {
        sink?.handleKey(.backspace)
    }
    
    @objc private func clear() {
        sink?.handleKey(.clear)
    }
    
    @objc private func didTapNext() {
        sink?.handleKey(.next)
    }
    
    @objc private func prev() {
        sink?.handleKey(.prev)
    }
    
    @objc private func done() {
        sink?.handleKey(.done)
    }
}
*/


final class NumpadView: UIView {
    private weak var sink: NumpadKeySink?
    private var currentTree: KeyboardNode?

    init(host: any NumpadHosting) {
        self.sink = host
        super.init(frame: .zero)
        isOpaque = false
        backgroundColor = .clear
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
            sink?.handleKey(payload.key)
        }
    }

    private struct Payload { let key: NumpadKey }
    private struct AssociatedKey {
        static var payloadKey: UInt8 = 0
    }
}
