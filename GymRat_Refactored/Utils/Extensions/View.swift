import Foundation
import SwiftUI

extension View {
    @ViewBuilder
    func blurFade (_ status: Bool) -> some View {
        self
            .compositingGroup()
            .blur(radius: status ? 0 : 10)
            .opacity(status ? 1 : 0)
    }
}

extension View {
    func fadedBackground (direction: FadeDirection, ignoreEdgeSet: Edge.Set, fadeStart: CGFloat = 0.5) -> some View {
        self.modifier(FadedBackgroundModifier(direction: direction, ignoreEdgeSet: ignoreEdgeSet, fadeStart: fadeStart))
    }
}

enum FadeDirection {
    case bottomToTop
    case topToBottom
    case leadingToTrailing
    case trailingToLeading
}

struct FadedBackgroundModifier: ViewModifier {

    
    let direction: FadeDirection
    let ignoreEdgeSet: Edge.Set
    let fadeStart: CGFloat
    
    func body(content: Content) -> some View {
        content
            .background {
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(1), location: 0.0),
                        .init(color: .white.opacity(1), location: fadeStart),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: startPoint,
                    endPoint: endPoint
                )
                .ignoresSafeArea(edges: ignoreEdgeSet)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
        }
    }
    
    
    
    var startPoint: UnitPoint {
        switch self.direction {
        case .bottomToTop:
                .bottom
        case .topToBottom:
                .top
        case .leadingToTrailing:
                .leading
        case .trailingToLeading:
                .trailing
        }
    }
    
    var endPoint: UnitPoint {
        switch self.direction {
        case .bottomToTop:
                .top
        case .topToBottom:
                .bottom
        case .leadingToTrailing:
                .trailing
        case .trailingToLeading:
                .leading
        }
    }
}


