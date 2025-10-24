import Foundation
import SwiftUI

struct ExerciseTemplateView: View {
    
    @EnvironmentObject var appComp: AppComposition
    
    @ObservedObject var editStore: ExerciseTemplateEditStore
    
    @Binding var replaceExercisePayload: ReplaceExercisePayload?
    
    let numpadHost: _NumpadHost
    
    var body: some View {
        VStack (spacing: 16) {
            HStack (alignment: .firstTextBaseline) {
                VStack (alignment: .leading) {
                    HStack {
                        Text(appComp.exerciseLookupSource.name(for: editStore.exerciseChildDTO.exerciseId))
                            .font(.title3)
                            .fontWeight(.bold)
                        
                    }
                    
                    Text("\(editStore.setTemplates.count) sets")
                        .font(.footnote)
                        .foregroundStyle(.gray)
                        .fontWeight(.bold)
                }
                
                Spacer(minLength: 8)
                
                MorphMenuView(
                    config: .init(
                        alignment: .topTrailing,
                        cornerRadius: 12,
                        extraBounce: 8,
                        animation: .smooth(duration: 0.3)
                    )) {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(.white)
                            .font(.footnote)
                            .fontWeight(.bold)
                            .frame(width: 55, height: 24)
                            .background {
                                RoundedRectangle(cornerRadius: 12).fill(.indigo)
                            }
                    } menu: { close in
                        EditExerciseChildMenu(
                            editStore: editStore,
                            replaceExercisePayload: $replaceExercisePayload,
                            pageAnimation: .smooth(duration: 0.3)) { onClosed in
                                close {
                                    onClosed()
                                }
                            }
                    }
            }
            
            HStack {
                Group {
                    Text("Set")
                        .frame(width: 55, alignment: .center)
                    
                    Text("Weight")
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    Text("Reps")
                        .frame(width: 55, alignment: .center)
                }
                .font(.footnote)
                .fontWeight(.bold)
                .foregroundStyle(.gray)
            }
            
            ForEach(editStore.setTemplates) { setTemplate in
                SetTemplateView(editStore: setTemplate, numpadHost: numpadHost)
                    .transition(.scale(scale: 0.8, anchor: .top).combined(with: .opacity))
            }
            
            Button {
                withAnimation(.snappy(duration: 0.3)) {
                    editStore.addSet(.regular)
                }
                
                Task {
                    numpadHost.setOrder(await editStore.getGlobalFieldsOrder())
                }
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.white)
                    .font(.footnote)
                    .fontWeight(.bold)
                    .rotationEffect(.init(degrees: 45))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 44, alignment: .center)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.indigo)
                    }
            }

        }
        .padding()
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.937, green: 0.937, blue: 0.937))
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.1), radius: 4, y: 4)
    }
}
