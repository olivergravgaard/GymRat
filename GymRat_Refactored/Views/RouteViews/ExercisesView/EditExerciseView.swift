import SwiftUI

struct EditExerciseView: View {
    
    @EnvironmentObject private var appComp: AppComposition
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var tabBarVisibility: TabBarVisibility
    
    @StateObject var editStore: ExerciseFormStore
    let originalDTO: ExerciseDTO
    
    @State private var propertyMenuProgress: CGFloat = 0
    @State private var showEditExerciseSheet: Bool = false
    
    var body: some View {
        ScrollView(.vertical) {
            
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top) {
            topBar()
                .frame(maxWidth: .infinity)
        }
        .ignoresSafeArea(edges: [.top])
        .onAppear {
            tabBarVisibility.hide()
        }
        .overlay (alignment: .bottomTrailing) {
            ExpandableMenu(
                progress: propertyMenuProgress,
                config: .init(
                    placement: .vertical(.trailing),
                    glassSpacing: 16,
                    tabSize: .init(width: 55, height: 55),
                    items: [
                        .init(content: {
                            Button {
                                withAnimation {
                                    propertyMenuProgress = 0
                                } completion: {
                                    showEditExerciseSheet = true
                                }
                            } label: {
                                Image(systemName: "pencil")
                                    .fontWeight(.medium)
                            }
                        })
                    ],
                    fixedAttribute: .spacing(16)
                )) {
                    ZStack {
                        Group {
                            Button {
                                guard propertyMenuProgress == 0 else { return }
                                
                                withAnimation {
                                    propertyMenuProgress = 1
                                }
                            } label: {
                                Image(systemName: "pencil")
                                    .foregroundStyle(.black)
                            }
                            .opacity(1 - propertyMenuProgress)
                            .disabled(propertyMenuProgress > 0)
                            
                            Button {
                                guard propertyMenuProgress == 1 else { return }
                                
                                withAnimation {
                                    propertyMenuProgress = 0
                                }
                            } label: {
                                Image(systemName: "xmark")
                                    .foregroundStyle(.indigo)
                            }
                            .opacity(propertyMenuProgress)
                            .disabled(propertyMenuProgress < 1)
                        }
                        .fontWeight(.medium)
                    }
                }
                .padding(.trailing)
        }
        .sheet(isPresented: $showEditExerciseSheet) {
            EditExerciseSheet(
                isPresented: $showEditExerciseSheet,
                exercise: originalDTO,
                exerciseProvider: appComp.exerciseProvider,
                muscleGroupProvider: appComp.muscleGroupProvider
            )
        }
    }
    
    @ViewBuilder
    func topBar () -> some View {
        HStack (alignment: .center){
            DismissButton {
                dismiss()
                tabBarVisibility.show()
            }
            
            Spacer(minLength: 8)
            
            VStack (alignment: .trailing, spacing: 2) {
                Text(originalDTO.name)
                    .font(.title)
                    .fontWeight(.bold)
                    .lineLimit(1)
                
                Text(appComp.muscleGroupLookupSource.name(for: originalDTO.muscleGroupID))
                    .font(.footnote)
                    .fontWeight(.bold)
                    .foregroundStyle(.gray)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
        .padding(.top, 55)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadii: .init(bottomLeading: 12, bottomTrailing: 12)))
        .compositingGroup()
        .shadow(color: .black.opacity(0.1), radius: 4, y: 4)
    }
}
