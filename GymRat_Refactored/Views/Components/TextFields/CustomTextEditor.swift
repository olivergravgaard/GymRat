import SwiftUI

struct CustomTextEditorConfig {
    var font: UIFont
    var fontColor: UIColor
}

struct CustomTextEditor: UIViewRepresentable {
    @Binding var text: String
    
    class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        
        init (text: Binding<String>) {
            _text = text
        }
    }
    
    func makeCoordinator () -> Coordinator {
        Coordinator(text: $text)
    }
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        
        textView.delegate = context.coordinator
        
        textView.backgroundColor = .clear
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }
}
