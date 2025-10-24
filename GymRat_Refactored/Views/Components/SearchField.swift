import SwiftUI

struct SearchField: View {
    
    var placeholder: String = "Search"
    @Binding var input: String
    
    @FocusState private var isFocused: Bool
    @State private var shouldShow: Bool = false
    
    init (placeholder: String, input: Binding<String>) {
        self.placeholder = placeholder
        _input = input
    }
    
    var body: some View {
        ZStack (alignment: .trailing) {
            GeometryReader { geo in
                let size = geo.size.width
                CustomTextField(text: $input, placeholder: placeholder, isFocused: $isFocused)
                    .focused($isFocused)
                    .padding(.horizontal, 48)
                    .frame(maxHeight: .infinity)
                    .frame(maxWidth: shouldShow ? size - (44 + 8) : .infinity)
                    .glassEffect(.regular.interactive(false), in: .capsule)
                    .overlay (alignment: .trailing) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .resizable()
                                .scaledToFit()
                                .font(.caption)
                                .frame(maxHeight: 16)
                                .foregroundStyle(isFocused ? .black : .gray)
                                .padding(.leading, 16)
                            Spacer(minLength: 0)
                            Button {
                                DispatchQueue.main.async {
                                    input = ""
                                }
                            } label: {
                                Image(systemName: "delete.backward.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .font(.caption)
                                    .frame(maxHeight: 16)
                                    .foregroundStyle(input.isEmpty ? .black.opacity(0.5) : .black)
                                    .padding(.trailing, 16)
                            }
                            .disabled(input.isEmpty)
                        }
                    }
            }
            
            if shouldShow {
                Button {
                    isFocused = false
                } label: {
                    Image(systemName: "xmark")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding()
                        .foregroundStyle(.black)
                }
                .frame(width: 44, height: 44)
                .glassEffect(.regular.interactive(true), in: .circle)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .scale(scale: 0.0, anchor: .trailing).combined(with: .opacity)))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .onChange(of: isFocused) { oldValue, newValue in
            if oldValue != newValue {
                withAnimation(.spring(duration: 0.35, bounce: 0.1, blendDuration: 0.25)) {
                    shouldShow = newValue
                }
            }
        }
    }
}

#Preview {
    @Previewable @State  var text: String = ""
    SearchField(placeholder: "Search text", input: $text)
}
