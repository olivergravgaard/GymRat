import SwiftUI

struct SimpleTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var style: CustomTextFieldStyle?
    
    @Environment(\.customTextFieldStyle) private var environmentStyle
    private var effectiveStyle: CustomTextFieldStyle {
        style ?? environmentStyle
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        @State var isFocused: Bool
        
        init (text: Binding<String>) {
            _text = text
            isFocused = false
        }
        
        func textFieldDidChangeSelection(_ textField: UITextField) {
            DispatchQueue.main.async {
                self.text = textField.text ?? ""
            }
        }
        
        func textFieldDidBeginEditing(_ textField: UITextField) {
            DispatchQueue.main.async {
                self.isFocused = true
            }
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            DispatchQueue.main.async {
                textField.resignFirstResponder()
            }

            return true
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.delegate = context.coordinator
        
        let style = effectiveStyle
        textField.tintColor = UIColor(style.caretColor)
        textField.textColor = UIColor(style.textColor)
        textField.font = style.textFont
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .font: style.placeholderFont,
                .foregroundColor: UIColor(style.placeholderColor)
            ]
        )
        textField.backgroundColor = .clear
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textField.adjustsFontSizeToFitWidth = false
        
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        
        let style = effectiveStyle
        uiView.tintColor = UIColor(style.caretColor)
        uiView.textColor = UIColor(style.textColor)
        uiView.font = style.textFont
        uiView.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .font: style.placeholderFont,
                .foregroundColor: UIColor(style.placeholderColor)
            ]
        )
    }
}
