import SwiftUI

struct PropertiesButton: View {
    
    let action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: "ellipsis")
                .resizable()
                .aspectRatio(contentMode: .fit)
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
    PropertiesButton {
        print("Testing")
    }
}
