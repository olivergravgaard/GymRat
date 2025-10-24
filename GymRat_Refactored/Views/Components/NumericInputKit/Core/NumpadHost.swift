//
//  NumpadHost.swift
//  GymRat_Refactored
//
//  Created by Oliver Gravgaard on 22/10/2025.
//

import Foundation
import Combine

@MainActor
public final class _NumpadHost: ObservableObject {

    public var onScrollTo: ((FieldID) -> Void)?
    public var onValueChanged: ((FieldID, NumericValue) -> Void)?
    public private(set) var order: [FieldID] = []
    private var indexOf: [FieldID: Int] = [:]
    private var values: [FieldID: NumericValue] = [:]
    private struct WeakEndpoint { weak var ref: (any FieldEndpoint)? }
    private var registry: [FieldID: WeakEndpoint] = [:]
    @Published private(set) var activeId: FieldID?
    private var pendingFocusId: FieldID?
    private var actionsMap: [UUID: FieldsActions] = [:]

    public init() {}
    
    public func setOrder(
        _ ids: [FieldID],
        preserveActive: Bool = true,
        autoInsertActiveIfMissing: Bool = true,
        seedValuesForNew: Bool = true
    ) {
        assert(Set(ids).count == ids.count, "setOrder: ids must be unique")
        if seedValuesForNew {
            for id in ids where values[id] == nil {
                values[id] = NumericValue()
            }
        }

        order = ids
        indexOf = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })

        if let a = activeId, indexOf[a] == nil {
            if autoInsertActiveIfMissing {
                order.append(a)
                indexOf[a] = order.count - 1
            } else if preserveActive {
                let newTarget = order.first
                activeId = nil
                if let t = newTarget { setActive(t) }
            } else {
                setActive(nil)
            }
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
            actionsMap[id]?.onBecomeActive?()
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
        guard activeId != id else { return }

        if let prev = activeId, let ep = registry[prev]?.ref {
            ep.resignActive()
            actionsMap[prev]?.onResignActive?()
        }

        if let id, indexOf[id] == nil {
            return
        }

        activeId = id
        guard let id else { return }

        if let ep = registry[id]?.ref {
            ep.becomeActive()
            actionsMap[id]?.onBecomeActive?()
            onScrollTo?(id)
        } else {
            pendingFocusId = id
            onScrollTo?(id)
        }
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
            return
        case .updated(let nv):
            values[id] = nv
            endpoint.apply(nv)
            onValueChanged?(id, nv)
        }
    }
}
