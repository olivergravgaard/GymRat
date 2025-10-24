import UIKit

final class NumpadView: UIView {
    private weak var host: _NumpadHost?
    init(host: _NumpadHost) {
        self.host = host
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
        host?.handleKey(.digit("0"))
    }
    
    @objc private func t1() {
        host?.handleKey(.digit("1"))
    }
    
    @objc private func t2() {
        host?.handleKey(.digit("2"))
    }
    
    @objc private func t3() {
        host?.handleKey(.digit("3"))
    }
    
    @objc private func t4() {
        host?.handleKey(.digit("4"))
    }
    
    @objc private func t5() {
        host?.handleKey(.digit("5"))
    }
    
    @objc private func t6() {
        host?.handleKey(.digit("6"))
    }
    
    @objc private func t7() {
        host?.handleKey(.digit("7"))
    }
    
    @objc private func t8() {
        host?.handleKey(.digit("8"))
    }
    
    @objc private func t9() {
        host?.handleKey(.digit("9"))
    }
    
    @objc private func dot() {
        host?.handleKey(.decimal)
    }
    
    @objc private func backspace() {
        host?.handleKey(.backspace)
    }
    
    @objc private func clear() {
        host?.handleKey(.clear)
    }
    
    @objc private func didTapNext() {
        host?.handleKey(.next)
    }
    
    @objc private func prev() {
        host?.handleKey(.prev)
    }
    
    @objc private func done() {
        host?.handleKey(.done)
    }
}
