import Foundation

public protocol FieldEndpoint: AnyObject {
    var id: FieldID { get }
    var inputPolicy: _InputPolicy { get }
    func apply(_ value: NumericValue)
    func becomeActive()
    func resignActive()
}

public protocol CurrentValueProvider: AnyObject {
    var currentValue: NumericValue { get }
}

public protocol _InputPolicy {
    func apply (_ key: NumpadKey, to value: NumericValue) -> EditResult
}
