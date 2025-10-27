import Foundation
import SwiftUI

extension View {
    func keyboardInset(host: any NumpadHosting) -> some View {
        return self.safeAreaInset(edge: .bottom) {
            Group {
                if host.activeId != nil {
                    ConcentricRectangle(corners: .concentric(minimum: 12), isUniform: true)
                        .fill(.black.opacity(0.1))
                        .frame(height: 264)
                        .frame(maxWidth: .infinity)
                        .glassEffect(.clear.interactive(false), in: .containerRelative)
                        .overlay {
                            NumpadRepresentable(host: host, activeId: host.activeId)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .clipShape(ConcentricRectangle(corners: .concentric(minimum: 12), isUniform: true))
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal:   .move(edge: .bottom).combined(with: .opacity)
                                ))
                        }
                        .padding(8)
                        .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .move(edge: .bottom)))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.9, blendDuration: 0.15), value: host.activeId != nil)
        }
    }
}
