import Foundation
import SwiftUI

struct OverwriteSessionSheet: View {
    
    @Binding var isPresented: Bool
    let onConfirm: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        ResizableSheet(animation: .smooth(duration: 0.35)) {
            VStack (spacing: 24) {
                Text("Are you sure?")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .overlay(alignment: .trailing) {
                        CloseButton {
                            onClose()
                        }
                    }
                
                Text("There is already an active WorkoutSession in progress. Are you sure you want to continue?")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.gray)
                    
                Button {
                    onConfirm()
                } label: {
                    Text("Start workout")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background {
                    ConcentricRectangle(corners: .concentric(minimum: 12), isUniform: true)
                        .fill(.indigo)
                        .shadow(color: .indigo.opacity(0.4), radius: 4, y: 4)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 149)
        }
    }
}
