import SwiftUI

struct CloseButton: View {
    
    let action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: "xmark")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .fontWeight(.bold)
                .foregroundStyle(.black)
                .padding()
        }
        .frame(width: 44, height: 44, alignment: .center)
        .glassEffect(.regular.interactive(), in: .circle)

    }
}

#Preview {
    CloseButton {
        print("Testing")
    }
}
