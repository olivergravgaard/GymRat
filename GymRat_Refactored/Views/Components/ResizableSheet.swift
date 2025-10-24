import Foundation
import SwiftUI

struct ResizableSheet<Content: View>: View {
    var animation: Animation
    @ViewBuilder var content: Content
    
    @State private var sheetHeight: CGFloat = 0
    
    var body: some View {
        ZStack {
            content
                .padding([.top, .leading, .trailing])
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGSize.self) {
                    $0.size
                } action: { newValue in
                    if sheetHeight == .zero {
                        sheetHeight = min(newValue.height, windowSize.height - 110)
                    }else {
                        withAnimation(animation) {
                            sheetHeight = min(newValue.height, windowSize.height - 110)
                        }
                    }
                }

        }
        .modifier(SheetHeightModifier(height: sheetHeight))
    }
    
    var windowSize: CGSize {
        if let size = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.size {
            return size
        }
        
        return .zero
    }
}

fileprivate struct SheetHeightModifier: ViewModifier, Animatable {
    var height: CGFloat
    var animatableData: CGFloat {
        get { height}
        set { height = newValue}
    }
    
    func body(content: Content) -> some View {
        content
            .presentationDetents(height == .zero ? [.medium] : [.height(height)])
            .interactiveDismissDisabled()
    }
}

