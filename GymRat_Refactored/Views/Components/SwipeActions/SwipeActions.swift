import SwiftUI
import UIKit

struct SwipeAction: Identifiable {
    var id: String = UUID().uuidString
    var symbolImage: String
    var tint: Color
    var background: Color
    var font: Font = .title3
    var size: CGSize = .init(width: 44, height: 44)
    var shape: some Shape = .circle
    var action: (_ close: @escaping (_ onClosed: @escaping () -> ()) -> ()) -> Void
}

@resultBuilder
struct SwipeActionBuilder {
    static func buildBlock(_ components: SwipeAction...) -> [SwipeAction] {
        return components
    }
}

struct SwipeActionConfig {
    var leadingPadding: CGFloat = 0
    var trailingPadding: CGFloat = 10
    var spacing: CGFloat = 10
    var occupiesFullWidth: Bool = true
}

extension View {
    @ViewBuilder
    func swipeActions (
        config: SwipeActionConfig = .init(),
        progress: Binding<CGFloat>? = nil,
        @SwipeActionBuilder swipeActions: () -> [SwipeAction]
    ) -> some View {
        self
            .modifier(
                CustomSwipeActionModifier(
                    config: config,
                    swipeActions: swipeActions(),
                    externalProgress: progress
                )
            )
    }
}

@MainActor
@Observable
class SwipeActionSharedData {
    static let shared = SwipeActionSharedData()
    
    var activeSwipeAction: String?
}

fileprivate struct CustomSwipeActionModifier: ViewModifier {
    var config: SwipeActionConfig
    var swipeActions: [SwipeAction]
    var externalProgress: Binding<CGFloat>?
    
    //@State private var resetPositionTrigger: Bool = false
    @State private var offsetX: CGFloat = 0
    @State private var lastStoredOffsetX: CGFloat = 0
    @State private var bounceOffset: CGFloat = 0
    @State private var progress: CGFloat = 0
    
    @State private var currentScrollOffset: CGFloat = 0
    @State private var storedScrollOffset: CGFloat?
    
    var sharedData = SwipeActionSharedData.shared
    @State private var currentId: String = UUID().uuidString
    
    func body(content: Content) -> some View {
        content
            .overlay {
                Rectangle()
                    .foregroundStyle(.clear)
                    .containerRelativeFrame(config.occupiesFullWidth ? .horizontal : .init())
                    .overlay (alignment: .trailing) {
                        SwipeActionsView()
                    }
            }
            .compositingGroup()
            .offset(x: offsetX)
            .offset(x: bounceOffset)
            .mask {
                Rectangle()
                    .containerRelativeFrame(config.occupiesFullWidth ? .horizontal : .init())
            }
            .gesture(
                PanGesture(onBegan: {
                    gestureDidBegan()
                }, onChange: { value in
                    gestureDidChange(translation: value.translation)
                }, onEnded: { value in
                    gestureDidEnded(translation: value.translation, velocity: value.velocity)
                })
            )
            .onGeometryChange(for: CGFloat.self) {
                $0.frame(in: .scrollView).minY
            } action: { newValue in
                if let storedScrollOffset, storedScrollOffset != newValue {
                    withAnimation (.snappy(duration: 0.3)) {
                        reset()
                    }
                }
            }
            .onChange(of: sharedData.activeSwipeAction) { oldValue, newValue in
                if newValue != currentId && offsetX != 0 {
                    withAnimation(.snappy(duration: 0.3)) {
                        reset()
                    }
                }
            }
            .onChange(of: progress) { _, newValue in
                externalProgress?.wrappedValue = newValue
            }
            .onChange(of: externalProgress?.wrappedValue ?? -1) { _, newVal in
                guard newVal >= 0 else { return }
                setProgressExternally(newVal)
            }

    }
    
    @ViewBuilder
    func SwipeActionsView () -> some View {
        ZStack {
            ForEach(swipeActions.indices, id: \.self) { index in
                let swipeAction = swipeActions[index]
                
                GeometryReader { proxy in
                    let size = proxy.size
                    let spacing = config.spacing * CGFloat(index)
                    let offset = (CGFloat(index) * size.width) + spacing
                    
                    Button {
                        swipeAction.action { onClosed in
                            withAnimation(.snappy(duration: 0.3)) {
                                reset()
                            } completion: {
                                onClosed()
                            }
                        }
                    } label: {
                        Image(systemName: swipeAction.symbolImage)
                            .font(swipeAction.font)
                            .foregroundStyle(swipeAction.tint)
                            .frame(width: size.width, height: size.height)
                            .background(swipeAction.background, in: swipeAction.shape)
                    }
                    .offset(x: offset * progress)
                }
                .frame(width: swipeAction.size.width, height: swipeAction.size.height)
            }
        }
        .visualEffect { content, proxy in
            content
                .offset(x: proxy.size.width)
        }
        .offset(x: config.leadingPadding)
    }
    
    private func gestureDidBegan () {
        storedScrollOffset = lastStoredOffsetX
        sharedData.activeSwipeAction = currentId
    }
    
    private func gestureDidChange (translation: CGSize) {
        offsetX = min(max(translation.width + lastStoredOffsetX, -maxOffsetWidth), 0)
        let p = clamp01(-offsetX / maxOffsetWidth)
        progress = p
        externalProgress?.wrappedValue = p
        bounceOffset = min(translation.width - (offsetX - lastStoredOffsetX), 0) / 10
    }
    
    private func gestureDidEnded (translation: CGSize, velocity: CGSize) {
        let endTarget = velocity.width + offsetX
        
        withAnimation(.snappy(duration: 0.3, extraBounce: 0)) {
            if -endTarget > (maxOffsetWidth * 0.6) {
                offsetX = -maxOffsetWidth
                bounceOffset = 0
                progress = 1
                externalProgress?.wrappedValue = 1
            }else {
                withAnimation(.snappy(duration: 0.3)) {
                    reset()
                }
            }
        }
        
        lastStoredOffsetX = offsetX
    }
    
    private func reset () {
        offsetX = 0
        lastStoredOffsetX = 0
        progress = 0
        externalProgress?.wrappedValue = 0
        bounceOffset = 0
        
        storedScrollOffset = nil
    }
    
    private func setProgressExternally(_ p: CGFloat) {
        let pClamped = clamp01(p)
        let newOffset = -maxOffsetWidth * pClamped
        if abs(newOffset - offsetX) < 0.5 { return }
        withAnimation(.snappy(duration: 0.2, extraBounce: 0)) {
            offsetX = newOffset
            progress = pClamped
            bounceOffset = 0
            lastStoredOffsetX = offsetX
        }
    }
    
    private func clamp01(_ v: CGFloat) -> CGFloat {
        min(max(v, 0), 1)
    }
    
    var maxOffsetWidth: CGFloat {
        let totalActionSize: CGFloat = swipeActions.reduce(.zero) { acc, swipeAction in
            acc + swipeAction.size.width
        }
        
        let spacing = config.spacing * CGFloat(swipeActions.count - 1)
        
        return totalActionSize + spacing + config.leadingPadding + config.trailingPadding
    }
}

struct PanGestureValue {
    var translation: CGSize = .zero
    var velocity: CGSize = .zero
}

struct PanGesture: UIGestureRecognizerRepresentable {
    
    var onBegan: () -> Void
    var onChange: (PanGestureValue) -> Void
    var onEnded: (PanGestureValue) -> Void
    
    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }
    
    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let gesture = UIPanGestureRecognizer()
        gesture.delegate = context.coordinator
        return gesture
    }
    
    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        
    }
    
    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let state = recognizer.state
        let translation = recognizer.translation(in: recognizer.view).toSize
        let velocity = recognizer.velocity(in: recognizer.view).toSize
        
        let gestureValue = PanGestureValue(translation: translation, velocity: velocity)
        
        switch state {
            case .began:
                onBegan()
            case .changed:
                onChange(gestureValue)
            case .ended, .cancelled:
                onEnded(gestureValue)
            default: break
        }
    }
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if let panGesture = gestureRecognizer as? UIPanGestureRecognizer {
                let velocity = panGesture.velocity(in: panGesture.view)
                
                if abs(velocity.x) > abs(velocity.y) {
                    return true
                }else {
                    return false
                }
            }
            
            return false
        }
    }
}

extension CGPoint {
    var toSize: CGSize {
        return CGSize(width: x, height: y)
    }
}
