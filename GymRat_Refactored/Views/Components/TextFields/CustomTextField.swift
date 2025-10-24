import SwiftUI

struct CustomTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    
    var style: CustomTextFieldStyle?
    
    var isFocused: FocusState<Bool>.Binding
    
    @Environment(\.customTextFieldStyle) private var environmentStyle
    private var effectiveStyle: CustomTextFieldStyle {
        style ?? environmentStyle
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        var isFocused: FocusState<Bool>.Binding
        
        init (text: Binding<String>, isFocused: FocusState<Bool>.Binding) {
            _text = text
            self.isFocused = isFocused
        }
        
        func textFieldDidBeginEditing(_ textField: UITextField) {
            DispatchQueue.main.async {
                self.isFocused.wrappedValue = true
            }
        }
        
        func textFieldDidChangeSelection(_ textField: UITextField) {
            DispatchQueue.main.async {
                self.text = textField.text ?? ""
            }
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFocused: isFocused)
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
        
        if isFocused.wrappedValue == true {
            if !uiView.isFirstResponder {
                uiView.becomeFirstResponder()
            }
        }
        else {
            if uiView.isFirstResponder {
                uiView.resignFirstResponder()
            }
        }
        
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

struct CustomTextFieldStyle {
    var caretColor: Color = Color.black
    var textColor: Color = Color.black
    var textFont: UIFont = UIFont.systemFont(ofSize: 16, weight: .medium)
    var placeholderColor: Color = Color.gray
    var placeholderFont: UIFont = UIFont.systemFont(ofSize: 14, weight: .regular)
}

private struct CustomTextFieldStyleKey: EnvironmentKey {
    static let defaultValue = CustomTextFieldStyle()
}

extension EnvironmentValues {
    var customTextFieldStyle: CustomTextFieldStyle {
        get { self[CustomTextFieldStyleKey.self] }
        set { self[CustomTextFieldStyleKey.self] = newValue }
    }
}

