import SwiftUI

struct FieldCellRepresentable: UIViewRepresentable {
    typealias UIViewType = FieldView

    
    @Binding var text: String
    
    let id: FieldID
    let host: _NumpadHost
    let inputPolicy: _InputPolicy
    let config: FieldConfig

    final class Coordinator {
        let host: _NumpadHost
        let id: FieldID
        init(host: _NumpadHost, id: FieldID) { self.host = host; self.id = id }
    }
    func makeCoordinator() -> Coordinator { Coordinator(host: host, id: id) }

    func makeUIView(context: Context) -> FieldView {
        let v = FieldView(inputPolicy: inputPolicy, config: config)
        let initial = NumericValue(text: text, caret: text.utf16.count, selection: nil)
        v.configure(id: id, host: host, initial: initial, config: config)
        
        host.register(endpoint: v, for: id)
        host.setValue(initial, for: id)
        
        v.onTextChanged = { newText in
            if newText != text {
                DispatchQueue.main.async {
                    self.text = newText
                }
            }
        }
        
        return v
    }

    func updateUIView(_ uiView: FieldView, context: Context) {
        if uiView.currentValue.text != text {
            uiView.applyExternalText(text)
        }
    }

    static func dismantleUIView(_ uiView: FieldView, coordinator: Coordinator) {
        
    }
}
