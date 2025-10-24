import Foundation
import SwiftUI

struct NumpadRepresentable: UIViewRepresentable {
    let host: _NumpadHost
    func makeUIView(context: Context) -> NumpadView {
        NumpadView(
            host: host
        )
    }
    
    func updateUIView(_ uiView: NumpadView,context: Context) {
        
    }
}
