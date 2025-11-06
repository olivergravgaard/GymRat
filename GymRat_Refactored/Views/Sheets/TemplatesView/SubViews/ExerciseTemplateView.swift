import Foundation
import SwiftUI

struct ExerciseTemplateView: View {
    
    @EnvironmentObject var appComp: AppComposition
    
    @ObservedObject var editStore: ExerciseTemplateEditStore
    
    @Binding var replaceExercisePayload: ReplaceExercisePayload?
    
    let numpadHost: NumpadHost
    let standaloneNumpadHost: FocusOnlyHost
    let proxy: ScrollViewProxy
    
    @State private var cachedActiveField: UUID? = nil
    
    var body: some View {
        VStack (spacing: 16) {
            HStack (alignment: .firstTextBaseline) {
                VStack (alignment: .leading) {
                    HStack {
                        Text(appComp.exerciseLookupSource.name(for: editStore.exerciseChildDTO.exerciseId))
                            .font(.title3)
                            .fontWeight(.bold)
                            .lineLimit(1)
                        
                    }
                    
                    Text("\(editStore.setTemplates.count) sets")
                        .font(.footnote)
                        .foregroundStyle(.gray)
                        .fontWeight(.bold)
                }
                
                Spacer(minLength: 8)
                
                MorphMenuView(
                    numpadHost: standaloneNumpadHost,
                    config: .init(
                        alignment: .topTrailing,
                        cornerRadius: 12,
                        extraBounce: 8,
                        animation: .smooth(duration: 0.3)
                    ),
                    proxy: proxy,
                    ) {
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
                            settings: editStore.exerciseChildDTO.settings,
                            standaloneNumpadHost: standaloneNumpadHost,
                            pageAnimation: .smooth(duration: 0.3)) { (setType, count) in
                                withAnimation(.snappy(duration: 0.3)) {
                                    editStore.addSets(setType: setType, count: count)
                                }
                            } onUpdateRestTimers: { warmup, working in
                                editStore.updateRestTimers(warmup: warmup, working: working)
                            } onAddRestTimers: {
                                withAnimation(.snappy(duration: 0.3)) {
                                    editStore.addMissingRestTemplates()
                                }
                            }
                            onReplaceExercise: {
                                replaceExercisePayload = .init(exerciseId: editStore.exerciseChildDTO.id)
                            } onDeleteSelf: {
                                withAnimation(.snappy(duration: 0.3)) {
                                    editStore.deleteSelf()
                                }
                            } close: { onClosed in
                                close {
                                    onClosed()
                                    
                                    numpadHost.setCachedActiveId()
                                }
                            }
                    } onOpen: {
                        numpadHost.saveCachedActiveId()
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
                SetTemplateView(editStore: setTemplate, numpadHost: numpadHost, standaloneNumpadHost: standaloneNumpadHost)
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
        .transition(.blurReplace)
    }

}
