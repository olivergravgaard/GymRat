import SwiftUI

struct DefaultTextField: View {
    
    @Binding var input: String
    let placeholder: String
    let style: CustomTextFieldStyle? = nil
    
    var body: some View {
        SimpleTextField(text: $input, placeholder: placeholder, style: style)
            .padding(.horizontal)
            .frame(maxWidth: .infinity)
            .frame(height: 55)
            .background(
                RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.937, green: 0.937, blue: 0.937))
            )
            .compositingGroup()
            .shadow(color: .black.opacity(0.1), radius: 4, y: 4)
    }
}
