import Foundation
import SwiftUI

struct ExerciseSessionView: View {
    
    @EnvironmentObject var appComp: AppComposition
    
    @ObservedObject var editStore: ExerciseSessionEditStore
    
    @Binding var replaceExercisePayload: ReplaceExercisePayload?
    
    let numpadHost: NumpadHost
    let standaloneNumpadHost: FocusOnlyHost
    let proxy: ScrollViewProxy
    
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
                    
                    Text("\(editStore.setSessions.count) sets")
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
                    ), proxy: proxy) {
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
                                editStore.addSets(setType: setType, count: count)
                            } onUpdateRestTimers: { warmup, working in
                                editStore.updateRestTimers(warmup: warmup, working: working)
                            } onAddRestTimers: {
                                withAnimation(.snappy(duration: 0.3)) {
                                    editStore.addMissingRestSessions()
                                }
                                
                            }
                            onReplaceExercise: {
                                replaceExercisePayload = .init(exerciseId: editStore.exerciseChildDTO.id)
                            } onDeleteSelf: {
                                withAnimation(.snappy(duration: 0.3)) {
                                    editStore.deleteSelf()
                                }
                                editStore.deleteSelf()
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
                        .frame(width: 44, alignment: .center)
                    
                    Text("Previous")
                        .frame(width: 96, alignment: .center)
                    
                    Text("Weight")
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    Text("Reps")
                        .frame(width: 55, alignment: .center)
                    
                    Image(systemName: "checkmark")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 44, alignment: .center)
                }
                .font(.footnote)
                .fontWeight(.bold)
                .foregroundStyle(.gray)
                .frame(height: 12, alignment: .center)
            }
            .padding(.horizontal, 6)
            
            ForEach(editStore.setSessions) { setSession in
                SetSessionView(editStore: setSession, numpadHost: numpadHost, standaloneNumpadHost: standaloneNumpadHost)
                    .transition(.scale(scale: 0.8, anchor: .top).combined(with: .opacity))
            }
            
            Button {
                withAnimation(.snappy(duration: 0.3)) {
                    editStore.addSet(.regular)
                } completion: {
                    Task {
                        numpadHost.setOrder(await editStore.getGlobalFieldsOrder())
                    }
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
