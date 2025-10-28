import SwiftUI
import Foundation

struct MorphMenuConfig {
    let alignment: Alignment
    let cornerRadius: CGFloat
    let extraBounce: CGFloat
    var animation: Animation = .bouncy(duration: 0.5, extraBounce: 0)
}

struct MorphMenuView<Label: View, Menu: View, Host: NumpadHosting>: View {
    
    // Arguments
    let numpadHost: Host
    let config: MorphMenuConfig
    let proxy: ScrollViewProxy?
    let label: () -> Label
    let menu: (_ close: @escaping (_ onClosed: @escaping () -> ()) -> ()) -> Menu
    
    // View properties
    @State private var id: UUID = UUID()
    @State private var isPresented: Bool = false
    @State private var isClosing: Bool = false
    @State private var progress: CGFloat = 0
    
    init (
        numpadHost: Host,
        config: MorphMenuConfig,
        proxy: ScrollViewProxy? = nil,
        @ViewBuilder label: @escaping () -> Label,
        @ViewBuilder menu: @escaping (_ close: @escaping (_ onClosed: @escaping () -> ()) -> ()) -> Menu
    ) {
        self.numpadHost = numpadHost
        self.config = config
        self.proxy = proxy
        self.label = label
        self.menu = menu
    }
    
    var body: some View {
        Button {
            if let proxy = proxy {
                withAnimation(.snappy(duration: 0.5), completionCriteria: .logicallyComplete) {
                    proxy.scrollTo(id, anchor: .top)
                } completion: {
                    open()
                }
            }else {
                open()
            }
        } label: {
            label()
                .morphMenu(
                    isPresented: $isPresented,
                    numpadHost: numpadHost,
                    isClosing: $isClosing,
                    alignment: config.alignment,
                    cornerRadius: config.cornerRadius,
                    extraBounce: config.extraBounce,
                    progress: progress) {
                        close {
                            
                        }
                    } onOpen: {
                        animate()
                    } label: {
                        label()
                    } popup: {
                        menu { onClosed in
                            close {
                                onClosed()
                            }
                        }
                    }
        }
        .id(id)
    }
    
    private func close (onClosed: @escaping () -> ()) {
        guard !isClosing else { return }
        numpadHost.setActive(nil)
        isClosing = true
        withAnimation(config.animation, completionCriteria: .logicallyComplete) {
            progress = 0
        } completion: {
            var trans = Transaction()
            trans.disablesAnimations = true
            withTransaction(trans) {
                isClosing = false
                isPresented = false
            }
            
            onClosed()
        }
    }
    
    private func open () {
        var trans = Transaction()
        trans.disablesAnimations = true
        withTransaction(trans) {
            isPresented = true
        }
    }
    
    private func animate () {
        withAnimation(config.animation) {
            progress = 1
        }
    }
}

struct MorphMenuModifier<Label: View, Popup: View, Host: NumpadHosting>: ViewModifier, Animatable {
    @Binding var isPresented: Bool
    @ObservedObject var numpadHost: Host
    @Binding var isClosing: Bool
    var alignment: Alignment
    var cornerRadius: CGFloat
    var extraBounce: CGFloat
    var progress: CGFloat
    let onClose: () -> ()
    let onOpen: () -> ()
    @ViewBuilder var label: Label
    @ViewBuilder var popup: Popup
    
    // View properties
    @State private var labelRect: CGRect = .zero
    @State private var contentSize: CGSize = .zero
    @State private var normalizedAlignment: Alignment = .center
    
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue}
    }
    
    func body (content: Content) -> some View {
        content
            .onAppear(perform: {
                normalizedAlignment = getAlignment()
            })
            .opacity(ogLabelOpacity)
            .onGeometryChange(for: CGRect.self, of: {
                $0.frame(in: .global)
            }, action: { newValue in
                labelRect = newValue
                normalizedAlignment = getAlignment()
            })
            .fullScreenCover(isPresented: $isPresented) {
                ZStack (alignment: .topLeading) {
                    Color.black.opacity(backgroundOpacity)
                        .onTapGesture {
                            guard progress == 1 else { return }
                            onClose()
                        }
                        .zIndex(0)
                    
                    GlassEffectContainer {
                        let widthDiff: Double = contentSize.width - labelRect.width
                        let heightDiff: Double = contentSize.height - labelRect.height
                        
                        let rWidth: Double = widthDiff * contentOpacity
                        let rHeight: Double = heightDiff * contentOpacity
                        
                        let popupWidth: CGFloat = labelRect.width + rWidth
                        let popupHeight: CGFloat =  labelRect.height + rHeight
                        
                        let labelWidth: CGFloat = contentSize.width >= labelRect.width ? labelRect.width : popupWidth
                        let labelHeight: CGFloat = contentSize.height >= labelRect.height ? labelRect.height : popupHeight
                        
                        ZStack (alignment: normalizedAlignment) {
                            popup
                                .compositingGroup()
                                .scaleEffect(contentScale)
                                .blur(radius: 14 * blurProgress)
                                .opacity(contentOpacity)
                                .onGeometryChange(for: CGSize.self) {
                                    $0.size
                                } action: { newValue in
                                    withAnimation (.smooth(duration: 0.35)) {
                                        contentSize = newValue
                                    }
                                }
                                .fixedSize()
                                .frame(
                                    width: popupWidth,
                                    height: popupHeight
                                )
                            
                            label
                                .compositingGroup()
                                .blur(radius: 14 * blurProgress)
                                .opacity(1 - labelOpacity)
                                .frame(width: labelWidth, height: labelHeight)
                        }
                        .compositingGroup()
                        .clipShape(.rect(cornerRadius: cornerRadius))
                        .glassEffect(.regular.interactive(false), in: .rect(cornerRadius: cornerRadius))
                        .zIndex(1)
                    }
                    .scaleEffect(
                        x: 1 - (blurProgress * 0.5),
                        y: 1 + (blurProgress * 1),
                        anchor: scaleAnchor
                    )
                    .offset(offset)
                    .opacity(ogContentOpacity)
                }
                .allowsHitTesting(!isClosing)
                .presentationBackground(.clear)
                .onGeometryChange(for: EdgeInsets.self) {
                    $0.safeAreaInsets
                } action: { newValue in
                    onOpen()
                }
                .ignoresSafeArea()
                .overlay {
                    Color.clear
                        .keyboardInset(host: numpadHost)
                        .ignoresSafeArea(edges: [.bottom])
                }
            }
    }
    
    var backgroundOpacity: CGFloat {
        return min(progress, 0.1)
    }
    
    var labelOpacity: CGFloat {
        min(progress / 0.35, 1)
    }
    
    var ogLabelOpacity: CGFloat {
        if isPresented {
            if isClosing {
                if progress > 0.1 {
                    return 0
                }else {
                    return (0.1 - progress) / 0.1
                }
            }else {
                return 1.0 - (progress * 100)
            }
        }else {
            return 1.0
        }
    }
    
    var ogContentOpacity: CGFloat {
        if isClosing {
            return max(0, min(1, (progress - 0.1) / (1.0 - 0.1)))
        }else {
            return 1
        }
    }
    
    var contentOpacity: CGFloat {
        max(progress - 0.35, 0) / 0.65
    }
    
    var contentScale: CGFloat {
        let minAspectScale = min(labelRect.width / contentSize.width, labelRect.height / contentSize.height)
        return minAspectScale + (1 - minAspectScale) * animatableData
    }
    
    var blurProgress: CGFloat {
        return progress > 0.5 ? (1 - progress) / 0.5 : progress / 0.5
    }
    
    func getAlignment() -> Alignment {
        var normalizedAlignment: Alignment = .center
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        var overlapsMinY: Bool {
            labelRect.maxY - contentSize.height <= 0
        }
        
        var overlapsMaxY: Bool {
            labelRect.minY + contentSize.height >= screenHeight
        }
        
        var overlapsMinX: Bool {
            labelRect.maxX - contentSize.width <= 0
        }
        
        var overlapsMaxX: Bool {
            labelRect.minX + contentSize.width >= screenWidth
        }
        
        switch alignment {
            case .bottom:
                if overlapsMinY {
                    return .top
                }
            case .bottomTrailing:
                if overlapsMinY {
                    if overlapsMinX {
                        return .topLeading
                    }
                    
                    return .topTrailing
                }else if overlapsMinX {
                    return .bottomLeading
                }else {
                    return alignment
                }
            
            case .bottomLeading:
                if overlapsMinY {
                    if overlapsMaxX {
                        return .topTrailing
                    }
                    
                    return .topLeading
                }else if overlapsMaxX {
                    return .bottomTrailing
                }else {
                    return alignment
                }
            case .leading:
                if overlapsMaxX {
                    return .trailing
                }
            
                return alignment
            case .trailing:
                if overlapsMinX {
                    return .leading
                }
                return alignment
            case .topLeading:
                if overlapsMaxY {
                    if overlapsMaxX {
                        return .bottomTrailing
                    }
                    
                    return .bottomLeading
                }else if overlapsMaxX {
                    return .topTrailing
                }else {
                    return alignment
                }
            case .top:
                if overlapsMaxY {
                    return .bottom
                }
            
                return alignment
            case .topTrailing:
                if overlapsMaxY {
                    if overlapsMinX {
                        return .bottomLeading
                    }
                    
                    return .bottomTrailing
                }else if overlapsMinX {
                    return .topLeading
                }else {
                    return alignment
                }
            
            default:
                return .center
        }
        
        return .center
    }
    
    var offset: CGSize {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var xExtra: CGFloat = 0
        var yExtra: CGFloat = 0
        
        var widthDiff = 0.0
        if contentSize.width > labelRect.width {
            widthDiff = contentSize.width - labelRect.width
        }else {
            widthDiff = -(labelRect.width - contentSize.width)
        }
        
        switch normalizedAlignment {
            case .bottom:
                x -= (widthDiff) / 2
                y -= contentSize.height - labelRect.height
                yExtra -= extraBounce
            case .bottomTrailing:
                x -= widthDiff
                y -= contentSize.height - labelRect.height
                yExtra -= extraBounce
            case .bottomLeading:
                y -= contentSize.height - labelRect.height
                yExtra -= extraBounce
            case .leading:
                y -= (contentSize.height - labelRect.height) / 2
                xExtra -= extraBounce
            case .center:
                x -= widthDiff / 2
                y -= (contentSize.height - labelRect.height) / 2
            case .trailing:
                x -= widthDiff
                y -= (contentSize.height - labelRect.height) / 2
                xExtra += extraBounce
            case .topLeading:
                yExtra += extraBounce
            case .top:
                x -= widthDiff / 2
                yExtra += extraBounce
            case .topTrailing:
                x -= widthDiff
                yExtra += extraBounce
            
        default: break
        }
        
        x *= contentOpacity
        y *= contentOpacity
        xExtra *= blurProgress
        yExtra *= blurProgress
        
        return .init(width: labelRect.minX + x + xExtra, height: labelRect.minY + y + yExtra)
    }
    
    var scaleAnchor: UnitPoint {
        switch normalizedAlignment {
        case .bottomLeading: .bottomLeading
        case .bottom: .bottom
        case .bottomTrailing: .bottomTrailing
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        case .topLeading: .topLeading
        case .top: .top
        case .topTrailing: .topTrailing
        default: .center
        }
    }
}

fileprivate extension View {
    func morphMenu<Label: View, Popup: View, Host: NumpadHosting>(
        isPresented: Binding<Bool>,
        numpadHost: Host,
        isClosing: Binding<Bool>,
        alignment: Alignment,
        cornerRadius: CGFloat,
        extraBounce: CGFloat,
        progress: CGFloat,
        onClose: @escaping () -> (),
        onOpen: @escaping () -> (),
        @ViewBuilder label: @escaping() -> Label,
        @ViewBuilder popup: @escaping () -> Popup
    ) -> some View {
        self.modifier(
            MorphMenuModifier(
                isPresented: isPresented,
                numpadHost: numpadHost,
                isClosing: isClosing,
                alignment: alignment,
                cornerRadius: cornerRadius,
                extraBounce: extraBounce,
                progress: progress,
                onClose: onClose,
                onOpen: onOpen,
                label: label,
                popup: popup
            )
        )
    }
}
