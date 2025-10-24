import SwiftUI

struct ExpandButton: View {
    
    @Binding var expanded: Bool
    
    var body: some View {
        Button {
            expanded.toggle()
        } label: {
            Image(systemName: "chevron.left")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .rotationEffect(.init(degrees: expanded ? -90 : 0))
                .fontWeight(.bold)
                .foregroundStyle(.black)
                .padding()
        }
        .frame(width: 44, height: 44, alignment: .center)
        .tint(.red)
        .glassEffect(.regular.interactive(), in: .circle)

    }
}

#Preview {
    @Previewable @State var expanded: Bool = false
    
    ExpandButton(expanded: $expanded)
}
