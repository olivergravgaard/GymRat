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
    @State private var isCollapsed: Bool = false
    
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
                    .contentShape(.rect)
                    .onTapGesture {
                        withAnimation(.snappy(duration: 0.3, extraBounce: -0.1)) {
                            isCollapsed.toggle()
                        }
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
                    scrollProxy: .init(proxy: proxy, anchor: .top)
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
                        editStore: editStore,
                        standaloneNumpadHost: standaloneNumpadHost,
                        pageAnimation: .smooth(duration: 0.3)) {
                            replaceExercisePayload = .init(exerciseId: editStore.exerciseChildDTO.id)
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
            .padding(.horizontal)
            
            let layout = isCollapsed ? AnyLayout(ZStackLayout(alignment: .top)) : AnyLayout(VStackLayout(spacing: 16))
            
            layout {
                VStack (alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    ForEach(Array(editStore.exerciseChildDTO.notes.indices), id: \.self) { index in
                        CustomTextEditor(text: Binding(
                            get: { editStore.exerciseChildDTO.notes[index].note },
                            set: { editStore.updateNote(at: index, to: $0) }
                        ))
                        .frame(minHeight: 44)
                        .padding(8)
                        .background {
                            Rectangle()
                                .fill(Color.yellow.opacity(0.2))
                                .frame(maxWidth: .infinity)
                        }
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
                    }
                    .font(.footnote)
                    .fontWeight(.bold)
                    .foregroundStyle(.gray)
                    .frame(height: 12, alignment: .center)
                }
                .padding(.horizontal)
                .padding(.horizontal, 6)
                
                ForEach(editStore.setTemplates) { setTemplate in
                    SetTemplateView(editStore: setTemplate, numpadHost: numpadHost, standaloneNumpadHost: standaloneNumpadHost)
                        .transition(.scale(scale: 0.8, anchor: .top).combined(with: .opacity))
                        .padding(.horizontal)
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
                .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: isCollapsed ? 0 : nil)
            .clipShape(.rect)
            .clipped(antialiased: true)
            .allowsHitTesting(isCollapsed ? false : true)
        }
        .frame(maxWidth: .infinity)
        .transition(.blurReplace)
    }
}
