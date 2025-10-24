import SwiftUI

struct DismissButton: View {
    
    let action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: "chevron.left")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .fontWeight(.bold)
                .foregroundStyle(.black)
                .padding()
        }
        .frame(width: 44, height: 44, alignment: .center)
        .tint(.red)
        .background {
            Circle().fill(Color(red: 0.937, green: 0.937, blue: 0.937))
        }

    }
}

#Preview {
    DismissButton {
        print("Testing")
    }
}
