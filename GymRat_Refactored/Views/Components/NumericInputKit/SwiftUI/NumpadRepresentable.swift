import Foundation
import SwiftUI

struct NumpadRepresentable: UIViewRepresentable {
    let host: any NumpadHosting
    let activeId: FieldID?
    
    func makeUIView(context: Context) -> NumpadView {
        let v = NumpadView(host: host)
        v.applyTree(host.currentKeyboardTree())
        return v
    }
    
    func updateUIView(_ uiView: NumpadView,context: Context) {
        uiView.applyTree(host.currentKeyboardTree())
    }
}
