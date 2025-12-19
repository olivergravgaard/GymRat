import SwiftUI
import FirebaseAuth

struct CreateExerciseSheet: View {
    @StateObject private var exerciseFormStore: ExerciseFormStore
    
    @Binding var isPresented: Bool
    
    init (
        isPresented: Binding<Bool>,
        exerciseProvider: ExerciseProvider,
        muscleGroupProvider: MuscleGroupProvider,
        exerciseSyncService: ExerciseSyncService,
        userId: String?
    ) {
        self._isPresented = isPresented
        self._exerciseFormStore = StateObject(
            wrappedValue: .init(
                mode: .create,
                exerciseProvider: exerciseProvider,
                muscleGroupProvider: muscleGroupProvider,
                exerciseSyncService: exerciseSyncService,
                userId: userId
            )
        )
    }
    
    var body: some View {
        ResizableSheet(animation: .smooth(duration: 0.55)) {
            VStack (spacing: 16) {
                HStack (alignment: .center, content: {
                    Text("Create exercise")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Spacer(minLength: 8)
                    
                    CloseButton {
                        isPresented = false
                    }
                })
                
                DefaultTextField(input: $exerciseFormStore.name, placeholder: "Exercise name")
                
                SingleHPicker(allCases: exerciseFormStore.muscleGroups, activeCase: $exerciseFormStore.selectedMuscleGroup, keyPath: \.name)
                
                Button {
                    Task {
                        await exerciseFormStore.save()
                        
                        if exerciseFormStore.nameStatus == .idle {
                            isPresented = false
                        }
                    }
                } label: {
                    Text("Create exercise")
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
