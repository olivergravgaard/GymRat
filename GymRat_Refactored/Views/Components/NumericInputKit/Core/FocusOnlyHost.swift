import Foundation
import Combine

@MainActor
public final class FocusOnlyHost: ObservableObject, NumpadHosting {

    public var onScrollTo: ((FieldID) -> Void)?
    public var onValueChanged: ((FieldID, NumericValue) -> Void)?
    
    @Published public private(set) var activeId: FieldID?
    
    private struct WeakEndpoint { weak var ref: (any FieldEndpoint)? }
    private var registry: [FieldID: WeakEndpoint] = [:]
    private var values: [FieldID: NumericValue] = [:]
    private var actionsMap: [UUID: FieldsActions] = [:]
    
    public var supportsNavigation: Bool { false }
    
    public init() {}
    
    public func currentKeyboardTree() -> KeyboardNode {
        guard let id = activeId, let endpoint = registry[id]?.ref else {
            // fallback: et simpelt 4x4 standardlayout
            return KeyboardNode.vstack(spacing: 8, children: [
                .hstack(spacing: 8, children: [
                    .button(title:"1", sends:.digit("1")),
                    .button(title:"2", sends:.digit("2")),
                    .button(title:"3", sends:.digit("3")),
                    .button(title:"Prev", sends:.prev)
                ]),
                .hstack(spacing: 8, children: [
                    .button(title:"4", sends:.digit("4")),
                    .button(title:"5", sends:.digit("5")),
                    .button(title:"6", sends:.digit("6")),
                    .button(title:"Next", sends:.next)
                ]),
                .hstack(spacing: 8, children: [
                    .button(title:"7", sends:.digit("7")),
                    .button(title:"8", sends:.digit("8")),
                    .button(title:"9", sends:.digit("9")),
                    .button(title:"⌫", sends:.backspace)
                ]),
                .hstack(spacing: 8, children: [
                    .button(title:".", sends:.decimal),
                    .button(title:"0", sends:.digit("0")),
                    .button(title:"Clear", sends:.clear),
                    .button(title:"Done", sends:.done)
                ])
            ])
        }

        if let p = endpoint.inputPolicy as? KeyboardTreeProviding {
            return p.keyboardTree(hostSupportsNavigation: supportsNavigation)
        }

        return KeyboardNode.vstack(spacing: 8, children: [
            .hstack(spacing: 8, children: [
                .button(title:"1", sends:.digit("1")),
                .button(title:"2", sends:.digit("2")),
                .button(title:"3", sends:.digit("3")),
                .button(title:"Prev", sends:.prev)
            ]),
            .hstack(spacing: 8, children: [
                .button(title:"4", sends:.digit("4")),
                .button(title:"5", sends:.digit("5")),
                .button(title:"6", sends:.digit("6")),
                .button(title:"Next", sends:.next)
            ]),
            .hstack(spacing: 8, children: [
                .button(title:"7", sends:.digit("7")),
                .button(title:"8", sends:.digit("8")),
                .button(title:"9", sends:.digit("9")),
                .button(title:"⌫", sends:.backspace)
            ]),
            .hstack(spacing: 8, children: [
                .button(title:".", sends:.decimal),
                .button(title:"0", sends:.digit("0")),
                .button(title:"Clear", sends:.clear),
                .button(title:"Done", sends:.done)
            ])
        ])
    }

    public func register(endpoint: any FieldEndpoint, for id: FieldID) {
        if values[id] == nil { values[id] = .init() }
        registry[id] = WeakEndpoint(ref: endpoint)
        endpoint.apply(values[id]!)
        
        if activeId == id {
            endpoint.becomeActive()
            actionsMap[id]?.onBecomeActive?()
        }
    }

    public func unregister(id: FieldID) {
        registry[id] = nil
        actionsMap[id] = nil
        // Bemærk: vi fjerner ikke aktivt id automatisk; det sker når feltet resign'er
        // eller hvis viewet bestemmer at kalde setActive(nil)
    }

    public func setActions(_ actions: FieldsActions, for id: UUID) {
        actionsMap[id] = actions
    }

    public func setValue(_ value: NumericValue, for id: FieldID) {
        values[id] = value
        registry[id]?.ref?.apply(value)
    }

    public func value(for id: FieldID) -> NumericValue? { values[id] }

    public func setActive(_ id: FieldID?) {
        guard activeId != id else { return }
        
        if let prev = activeId, let ep = registry[prev]?.ref {
            ep.resignActive()
            actionsMap[prev]?.onResignActive?()
        }

        activeId = id
        
        guard let id else { return }
        if let ep = registry[id]?.ref {
            ep.becomeActive()
            actionsMap[id]?.onBecomeActive?()
            onScrollTo?(id)
        } else {
            onScrollTo?(id) // feltet mount'er måske senere
        }
    }

    // MARK: - NumpadKeySink
    public func handleKey(_ key: NumpadKey) {
        // Ignorer navigation i denne host
        switch key {
        case .next, .prev:
            return
        case .done:
            if let id = activeId, let handled = actionsMap[id]?.onDone?(), handled {
                return
            }
            setActive(nil)
            return
        default:
            break
        }

        guard let id = activeId,
              var v = values[id],
              let endpoint = registry[id]?.ref
        else { return }

        if let fieldView = endpoint as? FieldView {
            v = fieldView.currentValue
        }

        let result = endpoint.inputPolicy.apply(key, to: v)
        switch result {
        case .rejected:
            return
        case .updated(let nv):
            values[id] = nv
            endpoint.apply(nv)
            onValueChanged?(id, nv)
        }
    }
}
