import Foundation

public protocol FieldEndpoint: AnyObject {
    var id: FieldID { get }
    var inputPolicy: InputPolicy { get }
    func apply(_ value: NumericValue)
    func becomeActive()
    func resignActive()
}

public protocol CurrentValueProvider: AnyObject {
    var currentValue: NumericValue { get }
}

public protocol InputPolicy {
    func apply (_ key: NumpadKey, to value: NumericValue) -> EditResult
}

public protocol NumpadKeySink: AnyObject {
    func handleKey (_ key: NumpadKey)
}

public protocol NumpadHosting: AnyObject, NumpadKeySink, ObservableObject {
    var activeId: FieldID? { get }
    func setActive (_ id: FieldID?)
    
    func register (endpoint: any FieldEndpoint, for id: FieldID)
    func unregister (id: FieldID)
    func setValue (_ value: NumericValue, for id: FieldID)
    func value (for id: FieldID) -> NumericValue?
    var onScrollTo: ((FieldID) -> Void)? { get set }
    var onValueChanged: ((FieldID, NumericValue) -> Void)? { get set }
    func setActions(_ actions: FieldsActions, for id: UUID)
    
    var supportsNavigation: Bool { get }
    func currentKeyboardTree () -> KeyboardNode
}

public protocol KeyboardTreeProviding {
    func keyboardTree (hostSupportsNavigation: Bool) -> KeyboardNode
}


