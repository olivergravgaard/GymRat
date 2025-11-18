import Foundation
import SwiftUI

extension View {
    func fadedBottomSafeArea (height: CGFloat = 55) -> some View {
        self.modifier(FadedBottomSafeArea(height: height))
    }
    
    func fadedTopSafeArea (height: CGFloat = 55) -> some View {
        self.modifier(FadedTopSafeArea(height: height))
    }
}

struct FadedBottomSafeArea: ViewModifier {
    var height: CGFloat
    func body(content: Content) -> some View {
        content
            .safeAreaBar(edge: .bottom, spacing: 0) {
                Text(".")
                    .opacity(0)
                    .blendMode(.destinationOver)
                    .frame(height: height)
            }
    }
}

struct FadedTopSafeArea: ViewModifier {
    var height: CGFloat
    func body(content: Content) -> some View {
        content
            .safeAreaBar(edge: .top, spacing: 0) {
                Text(".")
                    .opacity(0)
                    .blendMode(.destinationOver)
                    .frame(height: height)
            }
    }
}

