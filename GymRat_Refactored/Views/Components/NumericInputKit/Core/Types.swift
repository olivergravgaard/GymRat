import Foundation

public typealias FieldID = UUID

public nonisolated struct NumericValue: Sendable, Equatable {
    public var text: String
    public var caret: Int
    public var selection: Range<Int>?

    public init(text: String = "", caret: Int = 0, selection: Range<Int>? = nil) {
        self.text = text
        self.caret = caret
        self.selection = selection
    }
}

public struct FieldsActions {
    public var onNext: (() -> Bool)?
    public var onPrev: (() -> Bool)?
    public var onDone: (() -> Bool)?
    public var onBecomeActive: (() -> Bool)?
    public var onResignActive: (() -> Bool)?
    
    public init(
        onNext: (() -> Bool)? = nil,
        onPrev: (() -> Bool)? = nil,
        onDone: (() -> Bool)? = nil,
        onBecomeActive: (() -> Bool)? = nil,
        onResignActive: (() -> Bool)? = nil
    )
    {
        self.onNext = onNext
        self.onPrev = onPrev
        self.onDone = onDone
        self.onBecomeActive = onBecomeActive
        self.onResignActive = onResignActive
    }
}

public enum NumpadKey: Equatable, Sendable {
    case digit(Character)
    case decimal
    case minus
    case backspace
    case deleteForward
    case clear
    case selectAll
    case next
    case prev
    case done
}

public enum EditResult: Sendable, Equatable {
    case updated(NumericValue)
    case rejected
}

extension String {
    @inline(__always)
    func indexFromUTF16(_ utf16: Int) -> String.Index {
        let u = self.utf16
        let i = u.index(u.startIndex, offsetBy: utf16)
        return String.Index(i, within: self)!
    }
    @inline(__always)
    var utf16Count: Int { utf16.count }
}
