import Foundation
import SwiftUI

struct CancelWorkoutSessionSheet: View {
    
    let onClose: () -> Void
    let onConfirm: () -> Void
    
    var body: some View {
        ResizableSheet(animation: .smooth(duration: 0.3)) {
            VStack (spacing: 24) {
                Text("Cancel Workout?")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .overlay (alignment: .trailing) {
                        CloseButton {
                            onClose()
                        }
                    }
                
                Text("Cancelling this workout can not be undone. Are you sure you want to continue?")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.gray)
                
                Button {
                    onConfirm()
                } label: {
                    Text("Cancel Workout")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(height: 44, alignment: .center)
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.red.opacity(0.1))
                        }
                }
            }
        }
    }
}
