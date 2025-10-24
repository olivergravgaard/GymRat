import SwiftUI

struct CreateTemplateSheet: View {
    
    @StateObject private var templateFormStore: TemplateFormStore
    
    @Binding var isPresented: Bool
    
    init (
        isPresented: Binding<Bool>,
        templateProvider: TemplateProvider,
        muscleGroupProvider: MuscleGroupProvider
    ) {
        self._isPresented = isPresented
        self._templateFormStore = StateObject(
            wrappedValue: .init(
                mode: .create,
                templateProvider: templateProvider,
                muscleGroupProvider: muscleGroupProvider
            )
        )
    }
    
    var body: some View {
        ResizableSheet(animation: .smooth(duration: 0.55)) {
            VStack (spacing: 16) {
                HStack (alignment: .center, content: {
                    Text("Create template")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Spacer(minLength: 8)
                    
                    CloseButton {
                        isPresented = false
                    }
                })
                
                DefaultTextField(input: $templateFormStore.name, placeholder: "Template name")
                
                MultiHPicker(allCases: templateFormStore.muscleGroups, activeCases: $templateFormStore.selectedMuscleGroups, keyPath: \.name)
                
                Button {
                    Task {
                        await templateFormStore.save()
                        
                        if templateFormStore.nameStatus == .idle {
                            isPresented = false
                        }
                    }
                } label: {
                    Text("Create template")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(height: 55, alignment: .center)
                        .foregroundStyle(.white)
                        .background {
                            RoundedRectangle(cornerRadius: 12).fill(.indigo)
                        }
                        .opacity(templateFormStore.canSave ? 1 : 0.3)
                }
                .disabled(!templateFormStore.canSave)

                
                Spacer(minLength: 0)
            }
        }
    }
}
