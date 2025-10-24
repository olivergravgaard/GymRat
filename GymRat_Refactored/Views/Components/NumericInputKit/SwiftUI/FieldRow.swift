import SwiftUI

struct FieldRow: View {
    let id: FieldID
    let host: _NumpadHost
    let inputPolicy: _InputPolicy
    let config: FieldConfig
    
    @Binding var text: String

    var body: some View {
        FieldCellRepresentable(
            text: $text,
            id: id,
            host: host,
            inputPolicy: inputPolicy,
            config: config
        )
        .id(id)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .contentShape(Rectangle())
    }
}
