import SwiftUI

struct TrashButton: View {
    
    let action: () -> Void
    var size: CGSize = .init(width: 44, height: 44)
    
    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: "trash.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .fontWeight(.bold)
                .foregroundStyle(.red)
                .padding()
        }
        .frame(width: size.width, height: size.height, alignment: .center)
        .background {
            Circle().fill(.red.opacity(0.1))
        }
        .glassEffect(.regular.interactive(), in: .circle)

    }
}

#Preview {
    TrashButton {
        print("Testing")
    }
}
