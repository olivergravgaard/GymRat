import Foundation
import UIKit

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
    case custom(String)
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

public struct KeyboardButtonStyle: Equatable {
    public var fontSize: CGFloat
    public var weight: UIFont.Weight
    public var cornerRadius: CGFloat
    public var borderWidth: CGFloat
    public var fillColor: UIColor
    public var borderColor: UIColor
    public var titleColor: UIColor

    public init(fontSize: CGFloat = 22,
                weight: UIFont.Weight = .semibold,
                cornerRadius: CGFloat = 12,
                borderWidth: CGFloat = 0.5,
                fillColor: UIColor = .systemBackground,
                borderColor: UIColor = .separator,
                titleColor: UIColor = .label) {
        self.fontSize = fontSize
        self.weight = weight
        self.cornerRadius = cornerRadius
        self.borderWidth = borderWidth
        self.fillColor = fillColor
        self.borderColor = borderColor
        self.titleColor = titleColor
    }
}

public indirect enum KeyboardNode: Equatable {
    // Stacks
    case vstack(spacing: CGFloat, children: [KeyboardNode])
    case hstack(spacing: CGFloat, children: [KeyboardNode])
    case zstack(children: [KeyboardNode])
    case frame(width: CGFloat?, height: CGFloat?, child: KeyboardNode)
    case spacer(flex: Int)
    case aspectRatio(_ ratio: CGFloat, child: KeyboardNode)
    case overlay(alignment: CGPoint, child: KeyboardNode)
    case button(title: String, sends: NumpadKey, style: KeyboardButtonStyle = .init())
    case imageButton(imageName: String, sends: NumpadKey, style: KeyboardButtonStyle)
    case empty
}

public struct KFrame: Equatable {
    public var width: CGFloat?
    public var height: CGFloat?
    public var flex: Int?
    public init(width: CGFloat? = nil, height: CGFloat? = nil, flex: Int? = nil) {
        self.width = width
        self.height = height
        self.flex = flex
    }
}

public enum KAlignment: Equatable {
    case leading, trailing, top, bottom, center, fill
}

public enum KDistribution: Equatable {
    case fill, equalSpacing, equalCentering, equalSize
}



public struct KStackStyle: Equatable {
    public var spacing: CGFloat
    public var alignment: KAlignment
    public var distribution: KDistribution
    public var padding: UIEdgeInsets
    public var frame: KFrame?
    
    public init(
        spacing: CGFloat = 0,
        alignment: KAlignment = .center,
        distribution: KDistribution = .fill,
        padding: UIEdgeInsets = .zero,
        frame: KFrame? = nil
    ) {
        self.spacing = spacing
        self.alignment = alignment
        self.distribution = distribution
        self.padding = padding
        self.frame = frame
    }
}
