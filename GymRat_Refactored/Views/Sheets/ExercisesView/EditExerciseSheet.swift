import SwiftUI

struct EditExerciseSheet: View {
    
    @StateObject private var exerciseFormStore: ExerciseFormStore
    
    @Binding var isPresented: Bool
    
    init (
        isPresented: Binding<Bool>,
        exercise: ExerciseDTO,
        exerciseProvider: ExerciseProvider,
        muscleGroupProvider: MuscleGroupProvider
    ) {
        self._isPresented = isPresented
        self._exerciseFormStore = StateObject(
            wrappedValue: .init(
                mode: .edit(exercise: exercise),
                exerciseProvider: exerciseProvider,
                muscleGroupProvider: muscleGroupProvider
            )
        )
    }
    
    var body: some View {
        ResizableSheet(animation: .smooth(duration: 0.55)) {
            VStack (spacing: 16) {
                HStack (alignment: .center, content: {
                    Text("Edit exercise")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Spacer(minLength: 8)
                    
                    CloseButton {
                        isPresented = false
                    }
                })
                
                DefaultTextField(input: $exerciseFormStore.name, placeholder: "Template name")
                
                SingleHPicker(allCases: exerciseFormStore.muscleGroups, activeCase: $exerciseFormStore.selectedMuscleGroup, keyPath: \.name)
                
                Button {
                    Task {
                        await exerciseFormStore.save()
                        
                        if exerciseFormStore.nameStatus == .idle {
                            isPresented = false
                        }
                    }
                } label: {
                    Text("Save")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(height: 55, alignment: .center)
                        .foregroundStyle(.white)
                        .background {
                            RoundedRectangle(cornerRadius: 12).fill(.indigo)
                        }
                        .opacity(exerciseFormStore.canSave ? 1 : 0.3)
                }
                .disabled(!exerciseFormStore.canSave)

                
                Spacer(minLength: 0)
            }
        }
    }
}
