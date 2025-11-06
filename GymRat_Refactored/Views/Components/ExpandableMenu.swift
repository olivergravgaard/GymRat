import SwiftUI
import Foundation

enum FixedAttribute {
    case spacing(CGFloat)
    case length(CGFloat)
    
    var value: CGFloat {
        switch self {
        case .spacing(let val), .length(let val):
            return val
        }
    }
}

enum MenuAlignment {
    case vertical(HorizontalAlignment)
    case horizontal(HorizontalAlignment)
    
    var axis: Axis {
        switch self {
        case .vertical( _):
            return .vertical
        case .horizontal( _):
            return .horizontal
        }
    }
    
    var alignment: HorizontalAlignment {
        switch self {
        case .vertical(let alignment), .horizontal(let alignment):
            return alignment
        }
    }
}

struct MenuItem: Identifiable {
    let id: UUID = .init()
    let content: () -> AnyView
    
    init<V: View> (@ViewBuilder content: @escaping () -> V) {
        self.content = { AnyView(content())}
    }
}

struct ExpandableMenuConfig {
    var placement: MenuAlignment
    var glassSpacing: CGFloat
    var tabSize: CGSize
    var items: [MenuItem]
    var fixedAttribute: FixedAttribute?
    var unionTabs: Bool = false
    
    var isFixed: Bool {
        return fixedAttribute != nil
    }
    
    var isHorizontal: Bool {
        return placement.axis == .horizontal
    }
    
    var isLeading: Bool {
        return placement.alignment == .leading
    }
    
    var totalItemsLength: CGFloat {
        let count = items.count + 1
        guard count > 1 else { return 0 }
        let totalItemsLength = CGFloat(count) * (isHorizontal ? tabSize.width : tabSize.height)
        return totalItemsLength
    }
}

struct ExpandableMenu<Label: View>: View, Animatable {
    var progress: CGFloat
    var config: ExpandableMenuConfig
    @ViewBuilder var label: Label
    
    @State private var containerRect: CGRect = .zero
    @State private var labelRect: CGRect = .zero
    
    @Namespace var nameSpace
    
    var containerLength: CGFloat {
        let count = config.items.count + 1
        guard count > 1 else { return 0 }
        var containerLength: CGFloat = 0
        
        if config.isFixed {
            switch config.fixedAttribute {
                case .spacing(let spacing):
                    let totalItemsLength = config.totalItemsLength
                    containerLength = totalItemsLength + (Double(count) - 1.0) * spacing
                case .length(let length):
                    containerLength = length
                case .none:
                    break
            }
        }else {
            switch config.placement.axis {
                case .horizontal:
                    containerLength = containerRect.width.isFinite ? containerRect.width : 0
                case .vertical:
                    containerLength = containerRect.height.isFinite ? containerRect.height : 0
            }
        }
        
        return containerLength
    }
    
    var spacing: CGFloat {
        let count = config.items.count + 1
        guard count > 1 else { return 0 }
        let totalItemsLength = config.totalItemsLength
        
        let notFixed: CGFloat = (containerLength - totalItemsLength) / CGFloat(count - 1)
        
        if config.isFixed {
            switch config.fixedAttribute {
                case .spacing(let s):
                    return s
                default:
                    return notFixed
            }
        }
        
        return notFixed
    }
    
    var scaleEffectSize: CGSize {
        switch config.placement.axis {
        case .horizontal:
            return CGSize(width: 1.0 + (scaleProgress * 0.3), height: 1.0 - (scaleProgress * 0.7))
        case .vertical:
            return CGSize(width: 1.0 + (scaleProgress * 0.7), height: 1.0 - (scaleProgress * 0.3))
        }
    }

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue}
    }
    
    var body: some View {
        GlassEffectContainer(spacing: config.glassSpacing) {
            AnyLayout(!config.isHorizontal ? AnyLayout(VStackLayout(spacing: spacing)) : AnyLayout(HStackLayout(spacing: spacing))) {
                if config.isLeading {
                    labelView()
                }
                
                ForEach(config.items) { item in
                    item.content()
                        .blur(radius: 15 * min(progress, scaleProgress))
                        .opacity(progress)
                        .frame(width: config.tabSize.width, height: config.tabSize.height)
                        .glassEffect(.regular.interactive(true), in: .capsule)
                        .visualEffect { [containerRect, labelRect, config] content, proxy in
                            content
                                .offset(
                                    offset(proxy: proxy,
                                           containerRect: containerRect,
                                           labelRect: labelRect,
                                           isHorizontal: config.placement.axis == .horizontal
                                          )
                                )
                        }
                        .contentShape(.rect)
                }
                
                if !config.isLeading {
                    labelView()
                }
                
            }
        }
        .scaleEffect(
            scaleEffectSize,
            anchor: .center
        )
        .frame(
            maxWidth: config.isHorizontal ? (config.isFixed ? containerLength : .infinity) : nil,
            maxHeight: !config.isHorizontal ? (config.isFixed ? containerLength : .infinity) : nil
        )
        .onGeometryChange(for: CGRect.self, of: {
            $0.frame(in: .named("container"))
        }, action: { newValue in
            containerRect = newValue
        })
        .coordinateSpace(name: "container")
    }
    
    @ViewBuilder
    func labelView () -> some View {
        label
            .frame(width: config.tabSize.width, height: config.tabSize.height)
            .glassEffect(.regular.interactive(true))
            .contentShape(.rect)
            .onGeometryChange(for: CGRect.self) {
                $0.frame(in: .named("container"))
            } action: { newValue in
                labelRect = newValue
            }
    }
    
    var scaleProgress: CGFloat {
        return max(progress > 0.5 ? (1 - progress) / 0.5 : (progress / 0.5), 0)
    }
    
    nonisolated private func offset (proxy: GeometryProxy, containerRect: CGRect, labelRect: CGRect, isHorizontal: Bool) -> CGSize {
        let minX = proxy.frame(in: .named("container")).minX
        let minY = proxy.frame(in: .named("container")).minY
        
        var x: CGFloat = 0
        var y: CGFloat = 0
        
        if isHorizontal {
            x = (labelRect.minX - minX) * (1 - progress)
        }else {
            y = (labelRect.minY - minY) * (1 - progress)
        }
        
        return .init(width: x, height: y)
    }
}

struct ExpandableMenuOverlay<Label: View>: View, Animatable {
    var progress: CGFloat
    var config: ExpandableMenuConfig
    @ViewBuilder var label: Label
    
    @State private var labelRect: CGRect = .zero
    @State private var layoutRect: CGRect = .zero
    
    var containerLength: CGFloat {
        let count = config.items.count + 1
        guard count > 1 else { return 0 }
        var containerLength: CGFloat = 0
        
        if config.isFixed {
            switch config.fixedAttribute {
                case .spacing(let spacing):
                    let totalItemsLength = config.totalItemsLength
                    containerLength = totalItemsLength + (Double(count) - 1.0) * spacing
                case .length(let length):
                    containerLength = length
                case .none:
                    break
            }
        }else {
            containerLength = 0
        }
        
        return containerLength
    }
    
    var spacing: CGFloat {
        let count = config.items.count + 1
        guard count > 1 else { return 0 }
        let totalItemsLength = config.totalItemsLength
        
        let notFixed: CGFloat = (containerLength - totalItemsLength) / CGFloat(count - 1)
        
        if config.isFixed {
            switch config.fixedAttribute {
                case .spacing(let s):
                    return s
                default:
                    return notFixed
            }
        }
        
        return notFixed
    }
    
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue}
    }
    
    var body: some View {
        labelView()
            .scaleEffect(1 - scaleProgress, anchor: .center)
            .overlay  {
                GlassEffectContainer (spacing: config.glassSpacing) {
                    AnyLayout(!config.isHorizontal ? AnyLayout(VStackLayout(spacing: spacing)) : AnyLayout(HStackLayout(spacing: spacing))) {
                        ForEach(config.items) { item in
                            item.content()
                                .blur(radius: 15 * min(progress, scaleProgress))
                                .opacity(progress)
                                .frame(width: config.tabSize.width, height: config.tabSize.height)
                                .glassEffect(.regular.interactive(true), in: .capsule)
                                .contentShape(.rect)
                                .visualEffect { [labelRect] content, proxy in
                                    content
                                        .offset(itemOffset(proxy: proxy, labelRect: labelRect))
                                }
                        }
                    }
                    .offset(layoutOffset)
                    .coordinateSpace(name: "layoutSpace")

            }
            .scaleEffect(progress, anchor: .center)
        }
    }
    
    @ViewBuilder
    func labelView () -> some View {
        label
            .frame(width: config.tabSize.width, height: config.tabSize.height)
            .glassEffect(.regular.interactive(true))
            .contentShape(.rect)
            .onGeometryChange(for: CGRect.self) {
                $0.frame(in: .global)
            } action: { newValue in
                labelRect = newValue
            }
    }
    
    var scaleProgress: CGFloat {
        return max(progress > 0.5 ? (1 - progress) / 0.5 : (progress / 0.5), 0)
    }
    
    var layoutOffset: CGSize {
        
        var x: CGFloat = 0
        var y: CGFloat = 0
        
        switch config.placement {
        case .vertical(let alignment):
            if alignment == .trailing{
                y = -containerLength / 2
            }else {
                y = containerLength / 2
            }
        case .horizontal(let alignment):
            if alignment == .trailing{
                x = -containerLength / 2
            }else {
                x = containerLength / 2
            }
        }
        
        return .init(width: x, height: y)
    }
    
    nonisolated private func itemOffset (proxy: GeometryProxy, labelRect: CGRect) -> CGSize {
        let minX = proxy.frame(in: .named("layoutSpace")).minX
        let maxX = proxy.frame(in: .named("layoutSpace")).maxX
        let minY = proxy.frame(in: .named("layoutSpace")).minY
        let maxY = proxy.frame(in: .named("layoutSpace")).maxY
        
        var x: CGFloat = 0
        var y: CGFloat = 0
        
        switch config.placement {
        case .vertical(let alignment):
            if alignment == .trailing {
                y = (-labelRect.maxY - maxY) * (1 - progress)
            }else {
                y = (labelRect.minY - minY) * (1 - progress)
            }
        case .horizontal(let alignment):
            if alignment == .trailing {
                x = (-labelRect.minX + minX) * (1 - progress)
            }else {
                x = (labelRect.maxX - maxX) * (1 - progress)
            }
        }
    
        return .init(width: x, height: y)
    }
}

