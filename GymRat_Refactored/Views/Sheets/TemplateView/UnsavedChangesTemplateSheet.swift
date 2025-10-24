import Foundation
import SwiftUI

struct UnsavedChangesTemplateSheet: View {
    
    @Binding var isPresented: Bool
    let onConfirm: () -> Void
    let onDiscard: () -> Void
    
    var body: some View {
        ResizableSheet(animation: .smooth(duration: 0.35)) {
            VStack (spacing: 24) {
                Text("Unsaved changes")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .overlay(alignment: .trailing) {
                        CloseButton {
                            isPresented = false
                        }
                    }
                
                Text("You have unsaved changes. Are you sure you want to discard these changes?")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                VStack (spacing: 12) {
                    Button {
                        onDiscard()
                    } label: {
                        Text("Discard changes")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background {
                        ConcentricRectangle(corners: .concentric(minimum: 12), isUniform: true)
                            .fill(.red)
                            .shadow(color: .red.opacity(0.4), radius: 4, y: 4)
                    }
                    
                    Button {
                        onConfirm()
                    } label: {
                        Text("Save changes")
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
            }
            .frame(maxWidth: .infinity, minHeight: 149)
        }
    }
}
