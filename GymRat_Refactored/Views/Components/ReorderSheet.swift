import Foundation
import SwiftUI
import QuartzCore

public struct ReorderItem<ID: Hashable>: Identifiable, Hashable {
    public let id: ID
    public var title: String
    public var order: Int
    public init(id: ID, title: String, order: Int) {
        self.id = id
        self.title = title
        self.order = order
    }
}

fileprivate struct WorkingItem<ID: Hashable>: Identifiable {
    var id: ID { item.id }
    var item: ReorderItem<ID>
    var frame: CGRect = .zero
}

struct ReorderSheet<ID: Hashable, RowContent: View>: View {
    @Binding var isPresented: Bool
    var items: [ReorderItem<ID>]
    var orderBase: Int = 0
    let row: (ReorderItem<ID>) -> RowContent
    let onCommit: (_ newOrder: [ID: Int]) -> Void
    let onCancel: () -> Void
    
    @State private var workingItems: [WorkingItem<ID>] = []
    @State private var draggingId: ID?
    @State private var ghostFrame: CGRect = .zero
    @State private var dragOffset: CGSize = .zero
    @State private var ghostScale: CGFloat = 1.0
    @State private var hasChanged: Bool = false
    
    @State private var scrollPos: ScrollPosition = .init()
    @State private var contentOffsetY: CGFloat = 0
    @State private var maxOffsetY: CGFloat = 0
    @State private var topZone: CGRect = .zero
    @State private var bottomZone: CGRect = .zero
    
    @State private var displayLink: CADisplayLink?
    @State private var displayLinkTarget: DisplayLinkTarget?
    @State private var autoDir: CGFloat = 0
    
    @State private var edgeInsets: EdgeInsets = .init()
    
    @State private var framesVersion: Int = 0
    private let epsilon: CGFloat = 0.75
    
    init (
        isPresented: Binding<Bool>,
        items: [ReorderItem<ID>],
        orderBase: Int = 0,
        @ViewBuilder row: @escaping (ReorderItem<ID>) -> RowContent,
        onCommit: @escaping (_ newOrders: [ID: Int]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._isPresented = isPresented
        self.items = items
        self.orderBase = orderBase
        self.row = row
        self.onCommit = onCommit
        self.onCancel = onCancel
        
        self._workingItems = State(initialValue: items.sorted { $0.order < $1.order}.map { WorkingItem(item: $0) })
    }
    
    var body: some View {
           ScrollView(.vertical) {
               VStack(spacing: 8) {
                   ForEach($workingItems) { $workingItem in
                       row(workingItem.item)
                           .padding(.horizontal, 16)
                           .frame(height: 48)
                           .frame(maxWidth: .infinity, alignment: .leading)
                           .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
                           .overlay(alignment: .trailing) {
                               Image(systemName: "line.3.horizontal")
                                   .padding(.trailing, 16)
                                   .opacity(0.6)
                                   .gesture(dragGesture(for: workingItem.item.id))
                           }
                           .opacity(draggingId == workingItem.id ? 0.0 : 1.0)
                           .onGeometryChange(for: CGRect.self) {
                               $0.frame(in: .named("REORDER_SPACE"))
                           } action: { newFrame in
                               var t = Transaction(); t.disablesAnimations = true
                               withTransaction(t) {
                                   if abs(newFrame.minY - workingItem.frame.minY) > epsilon ||
                                      abs(newFrame.maxY - workingItem.frame.maxY) > epsilon {
                                       workingItem.frame = newFrame
                                       framesVersion &+= 1
                                   }
                               }
                           }
                   }
               }
               .padding(.bottom, 55)
               .padding(.horizontal)
               .transaction { $0.animation = nil }
               .animation(nil, value: framesVersion)
           }
           .onGeometryChange(for: EdgeInsets.self, of: {
               $0.safeAreaInsets
           }, action: { newValue in
               edgeInsets = newValue
               
               print("top: \(edgeInsets.top), bottom: \(edgeInsets.bottom)")
           })
           .safeAreaInset(edge: .top) {
               topBar()
           }
           .safeAreaInset(edge: .bottom, content: {
               bottomBar()
           })
           .interactiveDismissDisabled()
           .scrollIndicators(.hidden)
           .scrollPosition($scrollPos)
           .coordinateSpace(name: "REORDER_SPACE")
           .transaction { $0.animation = nil }
           .onScrollGeometryChange(for: CGFloat.self, of: {
               $0.contentOffset.y + $0.contentInsets.top
           }) { _, y in
               contentOffsetY = y
           }
           .onScrollGeometryChange(for: CGFloat.self, of: {
               $0.contentSize.height - $0.containerSize.height
           }) { _, maxY in
               maxOffsetY = maxY
           }
           .overlay(alignment: .topLeading) {
               if let id = draggingId, let src = workingItems.first(where: { $0.id == id }) {
                   row(src.item)
                       .padding(.horizontal, 16)
                       .frame(width: ghostFrame.width, height: ghostFrame.height, alignment: .leading)
                       .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
                       .scaleEffect(ghostScale)
                       .offset(x: ghostFrame.minX, y: ghostFrame.minY)
                       .offset(dragOffset)
                       .allowsHitTesting(false)
                       .transition(.identity)
               }
           }
           .overlay(alignment: .top) {
               Rectangle().fill(.clear).frame(height: 55)
                   .onGeometryChange(for: CGRect.self, of: {
                       $0.frame(in: .named("REORDER_SPACE"))
                   }) { r in
                       var t = Transaction(); t.disablesAnimations = true
                       withTransaction(t) { topZone = r }
                   }
                   .allowsHitTesting(false)
           }
           .overlay(alignment: .bottom) {
               Rectangle().fill(.clear).frame(height: 165)
                   .onGeometryChange(for: CGRect.self, of: {
                       $0.frame(in: .named("REORDER_SPACE"))
                   }) { r in
                       var t = Transaction(); t.disablesAnimations = true
                       withTransaction(t) { bottomZone = r }
                   }
                   .allowsHitTesting(false)
           }
    }
    
    @ViewBuilder
    private func topBar () -> some View {
        HStack {
            VStack (alignment: .leading, spacing: 2) {
                Text("Reorder Exercises")
                    .font(.title)
                    .fontWeight(.bold)
                    .lineLimit(1)
                
                Text("\(workingItems.count) exercises")
                    .font(.footnote)
                    .fontWeight(.bold)
                    .foregroundStyle(.gray)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 8)
            
            CloseButton {
                onCancel()
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadii: .init(bottomLeading: 12, bottomTrailing: 12)))
        .compositingGroup()
        .shadow(color: .black.opacity(0.1), radius: 4, y: 4)
    }
    
    
    @ViewBuilder
    private func bottomBar () -> some View {
        Button {
            let mapping = Dictionary(uniqueKeysWithValues:
                workingItems.enumerated().map { (idx, w) in (w.item.id, idx + orderBase) }
            )
            
            onCommit(mapping)
            isPresented = false
        } label: {
            Text("Save changes")
                .foregroundStyle(.white)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.indigo)
                }
        }
        .buttonStyle(.plain)
        .disabled(!hasChanged)
        .padding(.horizontal)
    }
    
    private func dragGesture (for id: ID) -> some Gesture {
        LongPressGesture(minimumDuration: 0.35)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("REORDER_SPACE")))
            .onChanged { phase in
                switch phase {
                    case .second(let began, let drag):
                        if began, draggingId == nil {
                            draggingId = id
                            if let frame = workingItems.first(where: { $0.id == id })?.frame {
                                ghostFrame = frame
                            }
                            ghostScale = 1.05
                        }
                        if let drag {
                            dragOffset = .init(width: 0, height: drag.translation.height)
                            updateAutoScroll(for: drag.location)
                        }
                    default: break
                }
            }
            .onEnded { _ in
                stopDisplayLink()
                ghostScale = 1.0
                dragOffset = .zero
                var trans = Transaction()
                trans.disablesAnimations = true
                withTransaction(trans) {
                    ghostFrame = .zero
                }
                draggingId = nil
            }
        
    }
    
    private func updateAutoScroll (for point: CGPoint) {
        let atTop = topZone.contains(point)
        let atBottom = bottomZone.contains(point)
        let dir: CGFloat = atTop ? -1 : (atBottom ? 1 : 0)
        if dir != autoDir {
            autoDir = dir
            if dir == 0 {
                stopDisplayLink()
            }else {
                startDisplayLink()
            }
        }
        if dir == 0 {
            swapIfNeeded(at: point)
        }
    }
    
    private func startDisplayLink () {
        guard displayLink == nil else { return }
        let target = DisplayLinkTarget { dt in
            self.tick(dt: dt)
        }
        let link = CADisplayLink(target: target, selector: #selector(DisplayLinkTarget.onTick(_:)))
        link.add(to: .main, forMode: .common)
        displayLinkTarget = target
        displayLink = link
    }
    
    private func stopDisplayLink () {
        displayLink?.invalidate()
        displayLink = nil
        displayLinkTarget = nil
    }
    
    private func tick (dt: CFTimeInterval) {
        guard autoDir != 0 else { return }
        let speed: CGFloat = 280
        let dy = autoDir * speed * CGFloat(dt)
        let nextY = max(0, min(maxOffsetY, contentOffsetY + dy))
        var trans = Transaction()
        trans.disablesAnimations = true
        withTransaction(trans) {
            scrollPos.scrollTo(y: nextY)
        }
        let ghostCenterY = ghostFrame.midY + dragOffset.height + dy
        swapIfNeeded(at: CGPoint(x: ghostFrame.midX, y: ghostCenterY))
    }
    
    final class DisplayLinkTarget {
        private var lastTimestamp: CFTimeInterval?
        private let handler: (CFTimeInterval) -> Void
        
        init (handler: @escaping (CFTimeInterval) -> Void) {
            self.handler = handler
        }
        
        @objc func onTick (_ link: CADisplayLink) {
            let now = link.timestamp
            let delta = (lastTimestamp == nil) ? (1.0 / 60.0) : now - (lastTimestamp ?? now)
            lastTimestamp = now
            handler(delta)
        }
    }
    
    private func swapIfNeeded (at point: CGPoint) {
        guard let draggingId, let from = workingItems.firstIndex(where: { $0.id == draggingId }) else { return }
        
        var target = workingItems.firstIndex(where: { $0.frame.minY <= point.y && $0.frame.maxY >= point.y })
        if target == nil {
            if let first = workingItems.first?.frame, point.y < first.minY {
                target = 0
            }else if let last = workingItems.last?.frame, point.y > last.maxY {
                target = workingItems.count - 1
            }
        }
        
        guard let to = target, to != from else { return }
        
        withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.9)) {
            workingItems.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
        
        hasChanged = true
    }
    
}
