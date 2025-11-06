import SwiftUI
import UIKit

extension View {
    func swipeToTrigger<ActionView: View> (
        leftSwipeConfig: SwipeToTriggerConfig<ActionView>?,
        rightSwipeConfig: SwipeToTriggerConfig<ActionView>?,
        occupiesFullWidth: Bool = false
    ) -> some View {
        self.modifier(
            SwipeToTriggerViewModifier(
                leftSwipeConfig: leftSwipeConfig,
                rightSwipeConfig: rightSwipeConfig,
                occupuiesFullWidth: occupiesFullWidth
            )
        )
    }
}

nonisolated enum Direction {
    case left
    case right
}

struct SwipeToTriggerConfig<ActionView: View> {
    
    var direction: Direction
    var isDeletion: Bool
    var threshold: CGFloat
    var backgroundColor: Color
    @ViewBuilder var actionView: () -> ActionView
    var onTrigger: () -> ()
}

fileprivate struct SwipeToTriggerViewModifier<ActionView: View>: ViewModifier{
    
    var leftSwipeConfig: SwipeToTriggerConfig<ActionView>?
    var rightSwipeConfig: SwipeToTriggerConfig<ActionView>?
    var occupiesFullWidth: Bool
    
    // View properties
    var sharedData = SwipeActionSharedData.shared
    @State private var thisId: String = UUID().uuidString
    @State private var offsetX: CGFloat = 0
    @State private var contentSize: CGSize = .zero
    
    @State private var activeDirection: Direction? = nil
    @State private var opacity: CGFloat = 1
    @State private var armed: Bool = false
    @State private var fired: Bool = false
    
    init (leftSwipeConfig: SwipeToTriggerConfig<ActionView>?, rightSwipeConfig: SwipeToTriggerConfig<ActionView>?, occupuiesFullWidth: Bool) {
        self.leftSwipeConfig = leftSwipeConfig
        self.rightSwipeConfig = rightSwipeConfig
        self.occupiesFullWidth = occupuiesFullWidth
    }
    
    func body(content: Content) -> some View {
        content
            .overlay (alignment: .center) {
                GeometryReader {
                    let size = CGSize(width: $0.size.width, height: $0.size.height)
                    Rectangle()
                        .containerRelativeFrame(occupiesFullWidth ? .horizontal : .init())
                        .foregroundStyle(.clear)
                        .onAppear(perform: {
                            contentSize = size
                        })
                        .overlay (alignment: .trailing) {
                            if let leftSwipeConfig = leftSwipeConfig {
                                ZStack (alignment: .leading) {
                                    Color.clear
                                        .containerRelativeFrame(.init([.horizontal, .vertical]))
                                    
                                    leftSwipeConfig.actionView()
                                        .visualEffect {[offsetX, armed, activeDirection] content, proxy in
                                            let x = armed ? 0 : -offsetX + (proxy.size.width * min(abs(offsetX) / proxy.size.width, 1)) * -1
                                            return content.offset(x: activeDirection == .left ? x : 0)
                                        }
                                }
                                .containerRelativeFrame(.init([.horizontal, .vertical]))
                                .background {
                                    Rectangle()
                                        .fill(leftSwipeConfig.backgroundColor)
                                }
                                .visualEffect { content, proxy in
                                    content
                                        .offset(x: proxy.size.width)
                                }
                            }
                        }
                        .overlay (alignment: .leading) {
                            if let rightSwipeConfig = rightSwipeConfig {
                                ZStack (alignment: .trailing) {
                                    Color.clear
                                        .containerRelativeFrame(.init([.horizontal, .vertical]))
                                    
                                    rightSwipeConfig.actionView()
                                        .visualEffect {[offsetX, armed, activeDirection] content, proxy in
                                            let x = armed ? 0 : -offsetX + (proxy.size.width * min(abs(offsetX) / proxy.size.width, 1))
                                            return content.offset(x: activeDirection == .right ? x : 0)
                                        }
                                }
                                .containerRelativeFrame(.init([.horizontal, .vertical]))
                                .background {
                                    Rectangle()
                                        .fill(rightSwipeConfig.backgroundColor)
                                }
                                .visualEffect { content, proxy in
                                    content
                                        .offset(x: -proxy.size.width)
                                }
                            }
                        }
                        .visualEffect { content, proxy in
                            content.offset(x: occupiesFullWidth ? (size.width - proxy.size.width) / 2 : 0)
                        }
                }
            }
            .compositingGroup()
            .offset(x: offsetX)
            .opacity(opacity)
            .mask {
                Rectangle()
                    .containerRelativeFrame(occupiesFullWidth ? .horizontal : .init())
            }
            .gesture (
                PanGesture(
                    onBegan: {
                        onGestureBegin()
                    },
                    onChange: { value in
                        onGestureChanged(translation: value.translation)
                    },
                    onEnded: { value in
                        onGestureEnded(translation: value.translation, velocity: value.velocity)
                    }
                )
            )
            .animation(.snappy(duration: 0.3), value: armed)
            .animation(.snappy(duration: 0.3), value: offsetX)
            .onChange(of: fired) { _, newValue in
                if newValue == true {
                    let config = activeDirection == .left ? leftSwipeConfig : rightSwipeConfig
                    guard let config else { return }
                    
                    withAnimation(.snappy(duration: 1.0)) {
                        if config.isDeletion {
                            offsetX = config.direction == .left ? -contentSize.width : contentSize.width
                            opacity = 0
                        }else {
                            offsetX = 0
                        }
                    } completion: {
                        config.onTrigger()
                        
                        fired = false
                    }
                }
            }
            .sensoryFeedback(.impact(weight: .heavy), trigger: armed)
    }
    
    private func onGestureBegin () {
        sharedData.activeSwipeAction = thisId
    }
    
    private func onGestureChanged(translation: CGSize) {
        
        let x: CGFloat = translation.width
        var normalizedThreshold: CGFloat = 0
        var activeConfig: SwipeToTriggerConfig<ActionView>? = nil
        
        if x > 0 {
            guard let rightSwipeConfig else { return }
            activeDirection = .right
            activeConfig = rightSwipeConfig
            normalizedThreshold = min(rightSwipeConfig.threshold, 1) * contentSize.width
        }else if x < 0 {
            guard let leftSwipeConfig else { return }
            activeDirection = .left
            activeConfig = leftSwipeConfig
            normalizedThreshold = min(leftSwipeConfig.threshold, 1) * contentSize.width * -1
        }
        
        guard let activeConfig = activeConfig else { return }
        
        if activeConfig.isDeletion {
            offsetX = x
        }else {
            offsetX = min(normalizedThreshold, x)
        }
    
        if abs(x) >= abs(normalizedThreshold) && !armed {
            armed = true
        } else if abs(x) < abs(normalizedThreshold) && armed {
            armed = false
        }
    }
    
    private func onGestureEnded (translation: CGSize, velocity: CGSize) {
        if armed {
            switch activeDirection {
                case .left:
                    if velocity.width <= 100 {
                        fired = true
                    }else {
                        reset()
                    }
                case .right:
                    if velocity.width >= 0 {
                        fired = true
                        
                    }else {
                        reset()
                    }
                case nil:
                    return
            }
        }else {
            reset()
        }
    }
    
    private func reset () {
        withAnimation(.snappy(duration: 0.2)) {
            activeDirection = nil
            armed = false
            offsetX = 0
            sharedData.activeSwipeAction = nil
        }
    }
}

struct SwipeToTriggerDemoView: View {
    var body: some View {
        VStack {
            HStack {
                
            }
            .frame(maxWidth: .infinity)
            .frame(height: 55)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.blue)
            }
            .swipeToTrigger(
                leftSwipeConfig: .init(
                    direction: .left,
                    isDeletion: true,
                    threshold: 0.5,
                    backgroundColor: .red,
                    actionView: {
                        Text("Delete")
                            .padding(.horizontal)
                    },
                    onTrigger: {
                        print("Deleted")
                    }
                ),
                rightSwipeConfig: .init(
                    direction: .right,
                    isDeletion: false,
                    threshold: 0.3,
                    backgroundColor: .clear,
                    actionView: {
                        Text("Add rest")
                            .padding(.horizontal)
                    },
                    onTrigger: {
                        print("Added resd")
                    }
                ), occupiesFullWidth: true
            )
        }
        .padding()
    }
}

#Preview {
    SwipeToTriggerDemoView()
}
