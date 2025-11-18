//
//  NumpadHost.swift
//  GymRat_Refactored
//
//  Created by Oliver Gravgaard on 22/10/2025.
//

import Foundation
import Combine

@MainActor
public final class NumpadHost: ObservableObject, NumpadHosting {

    public var onScrollTo: ((FieldID) -> Void)?
    public var onValueChanged: ((FieldID, NumericValue) -> Void)?
    public private(set) var order: [FieldID] = []
    private var indexOf: [FieldID: Int] = [:]
    private var values: [FieldID: NumericValue] = [:]
    private struct WeakEndpoint { weak var ref: (any FieldEndpoint)? }
    private var registry: [FieldID: WeakEndpoint] = [:]
    @Published public private(set) var activeId: FieldID?
    @Published private(set) var cachedActiveId: FieldID?
    private var pendingFocusId: FieldID?
    private var actionsMap: [UUID: FieldsActions] = [:]
    public var supportsNavigation: Bool { true }

    public init() {}
    
    public func currentKeyboardTree() -> KeyboardNode {
        guard let id = activeId, let endpoint = registry[id]?.ref else {
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
                    .button(title:"FART", sends:.next)
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
    
    public func setOrder(
        _ ids: [FieldID],
        preserveActive: Bool = true,
        autoInsertActiveIfMissing: Bool = false,
        seedValuesForNew: Bool = true
    ) {
        if seedValuesForNew {
            for id in ids where values[id] == nil {
                print("Set to numericValue")
                values[id] = NumericValue()
            }
        }

        order = ids
        indexOf = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })

        if let a = activeId, indexOf[a] == nil {
            setActive(nil)
        }
    }

    public func boot(ids: [FieldID], initialValue: NumericValue = NumericValue()) {
        order = ids
        indexOf = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
        values = Dictionary(uniqueKeysWithValues: ids.map { ($0, initialValue) })
        registry.removeAll(keepingCapacity: true)
        activeId = nil
        pendingFocusId = nil
    }
    
    public func setActions (_ actions: FieldsActions, for id: UUID) {
        actionsMap[id] = actions
    }

    public func setValue(_ value: NumericValue, for id: FieldID) {
        values[id] = value
        registry[id]?.ref?.apply(value)
    }

    public func value(for id: FieldID) -> NumericValue? { values[id] }

    public func register(endpoint: any FieldEndpoint, for id: FieldID) {
        if values[id] == nil { values[id] = NumericValue() }
        registry[id] = WeakEndpoint(ref: endpoint)
        endpoint.apply(values[id]!)

        if pendingFocusId == id || activeId == id {
            pendingFocusId = nil
            endpoint.becomeActive()
            _ = actionsMap[id]?.onBecomeActive?()
        }
    }

    public func unregister(id: FieldID) {
        if let idx = indexOf[id] {
            order.remove(at: idx)
        }
        
        registry[id] = nil
        actionsMap[id] = nil
    }

    public func setActive(_ id: FieldID?) {
        guard activeId != id else {
            return
        }

        if let prev = activeId, let ep = registry[prev]?.ref {
            ep.resignActive()
            _ = actionsMap[prev]?.onResignActive?()
        }

        if let id, indexOf[id] == nil {
            return
        }

        activeId = id
        guard let id else { return }

        if let ep = registry[id]?.ref {
            ep.becomeActive()
            _ = actionsMap[id]?.onBecomeActive?()
            onScrollTo?(id)
        } else {
            pendingFocusId = id
            onScrollTo?(id)
        }
    }
    
    public func saveCachedActiveId () {
        guard let activeId = activeId else { return }
        cachedActiveId = activeId
        setActive(nil)
    }
    
    public func setCachedActiveId () {
        guard let cachedActiveId = cachedActiveId else { return }
        setActive(cachedActiveId)
        self.cachedActiveId = nil
    }

    public func focusNext() {
        guard let current = activeId else {
            if let first = order.first { setActive(first) }
            return
        }
        
        guard let idx = indexOf[current], idx + 1 < order.count else { return }
        let nextId = order[idx + 1]
        onScrollTo?(nextId)
        setActive(nextId)
    }

    public func focusPrev() {
        guard let current = activeId,
              let idx = indexOf[current],
              idx - 1 >= 0 else {
            if activeId == nil, let last = order.last { setActive(last) }
            return
        }
        let prevId = order[idx - 1]
        guard prevId != current else { return }
        setActive(prevId)
    }
    
    public func handleKey(_ key: NumpadKey) {
        switch key {
            case .next:
                if let id = activeId, let handled = actionsMap[id]?.onNext?(), handled {
                    return
                }
                
                focusNext()
                return
            case .prev:
                if let id = activeId, let handled = actionsMap[id]?.onPrev?(), handled {
                    return
                }
                
                focusPrev()
                return
            case .done:
                if let id = activeId, let handled = actionsMap[id]?.onDone?(), handled {
                    return
                }
                setActive(nil)
                return
            default: break
        }

        guard let id = activeId,
              var v = values[id],
              let endpoint = registry[id]?.ref else { return }

        if let fieldView = endpoint as? FieldView {
            v = fieldView.currentValue
        }

        let result = endpoint.inputPolicy.apply(key, to: v)

        switch result {
            case .rejected:
                print("Rejected")
                return
            case .updated(let nv):
                values[id] = nv
                endpoint.apply(nv)
                onValueChanged?(id, nv)
        }
    }
}
