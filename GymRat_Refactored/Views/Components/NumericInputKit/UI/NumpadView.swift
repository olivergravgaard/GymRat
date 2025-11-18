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
                v.setContentHuggingPriority(.defaultLow, for: .horizontal)
                v.setContentHuggingPriority(.defaultLow, for: .vertical)
            }
            return v
            
        case .button(let title, let key, let style):
            return makeButton(title: title, key: key, style: style)
            
            
        case .imageButton(let imageName, sends: let key, let style):
            return makeImageButton(imageName: imageName, key: key, style: style)
            
        case .frame(let width, let height, let child):
            let container = UIView()
            let inner = makeView(for: child)
            inner.translatesAutoresizingMaskIntoConstraints = false

            container.addSubview(inner)
            NSLayoutConstraint.activate([
                inner.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                inner.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                inner.topAnchor.constraint(equalTo: container.topAnchor),
                inner.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])

            // Hvis width/height er sat, så giv faste constraints
            if let w = width {
                let c = container.widthAnchor.constraint(equalToConstant: w)
                c.priority = .required
                c.isActive = true
            }
            if let h = height {
                let c = container.heightAnchor.constraint(equalToConstant: h)
                c.priority = .required
                c.isActive = true
            }

            // Hvis de IKKE er sat, så skal viewet “tage alt den plads det kan”.
            // Det gør vi ved at gøre det villigt til at udvide sig:
            inner.setContentHuggingPriority(.defaultLow, for: .horizontal)
            inner.setContentHuggingPriority(.defaultLow, for: .vertical)
            inner.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            inner.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

            return container
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
    
    private func makeImageButton(imageName: String, key: NumpadKey, style: KeyboardButtonStyle) -> UIView {

        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false

        button.backgroundColor = style.fillColor
        button.layer.cornerRadius = style.cornerRadius
        button.layer.masksToBounds = true
        button.layer.borderWidth = style.borderWidth
        button.layer.borderColor = style.borderColor.cgColor
        button.tintColor = style.titleColor

        let image: UIImage?
        if let sfImage = UIImage(systemName: imageName) {
            image = sfImage
        } else {
            image = UIImage(named: imageName)
        }

        if let img = image {
            button.setImage(img.withRenderingMode(.alwaysTemplate), for: .normal)
        } else {
            let placeholder = UIImage(systemName: "questionmark.square.dashed")
            button.setImage(placeholder?.withRenderingMode(.alwaysTemplate), for: .normal)
        }

        button.imageView?.contentMode = .scaleAspectFit
        
        objc_setAssociatedObject(button, &AssociatedKey.payloadKey, Payload(key: key), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        button.addTarget(self, action: #selector(onTap(_:)), for: .touchUpInside)

        return button
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
