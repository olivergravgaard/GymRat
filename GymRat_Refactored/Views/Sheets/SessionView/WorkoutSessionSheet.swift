import SwiftUI
import Foundation

struct WorkoutSessionSheet: View {
    @EnvironmentObject private var appComp: AppComposition
    @EnvironmentObject private var tabBarVisibility: TabBarVisibility
    
    @ObservedObject var editStore: WorkoutSessionEditStore
    
    @State private var showEditSessionSheet: Bool = false
    @State private var showAddExerciseSheet: Bool = false
    @State private var showReplaceExerciseSheet: Bool = false
    @State private var showFinishWorkoutSheet: Bool = false
    @State private var showCancelWorkoutSessionSheet: Bool = false
    
    @State private var reorderPayload: ReorderPayload?
    @State private var replaceExercisePayload: ReplaceExercisePayload?
    
    @Binding var isPresented: Bool
    
    @StateObject var numpadHost: NumpadHost = .init()
    @StateObject var standaloneNumpadHost: FocusOnlyHost = .init()
    
    @State private var propertyMenuProgress: CGFloat = 0
    @State private var hidePropertyMenu: Bool = false
    
    init (isPresented: Binding<Bool>, editStore: WorkoutSessionEditStore) {
        self._isPresented = isPresented
        self._editStore = ObservedObject(wrappedValue: editStore)
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack {
                    ForEach(editStore.exerciseSessions, id: \.id) { exerciseSession in
                        ExerciseSessionView(
                            editStore: exerciseSession,
                            replaceExercisePayload: $replaceExercisePayload,
                            numpadHost: numpadHost,
                            standaloneNumpadHost: standaloneNumpadHost
                        )
                    }
                }
                .padding()
            }
            .onAppear(perform: {
                tabBarVisibility.hide()
                
                Task {
                    numpadHost.setOrder(await editStore.getGlobalFieldsOrder())
                }
                
                numpadHost.onScrollTo = { id in
                    withAnimation (.snappy(duration: 0.2)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            })
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .top) {
                topBar()
                    .frame(maxWidth: .infinity)
            }
            .keyboardInset(host: numpadHost)
            .ignoresSafeArea(edges: [.bottom])
            .overlay (alignment: .bottom) {
                if !hidePropertyMenu {
                    HStack (alignment: .bottom, spacing: 16) {
                        TrashButton(
                            action: {
                                showCancelWorkoutSessionSheet = true
                            },
                            size: .init(
                                width: 55,
                                height: 55
                            )
                        )
                        
                        Button {
                            showFinishWorkoutSheet = true
                        } label: {
                            Text("Finish workout")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(.green)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(height: 55, alignment: .center)
                        }
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.green.opacity(0.1))
                        }
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
                        
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
                                                showAddExerciseSheet = true
                                            }
                                        } label: {
                                            Image(systemName: "xmark")
                                                .fontWeight(.medium)
                                                .rotationEffect(.init(degrees: 45))
                                                .foregroundStyle(.indigo)
                                        }
                                        .buttonStyle(.plain)
                                    }),
                                    .init(
                                        content: {
                                            Button {
                                                withAnimation {
                                                    propertyMenuProgress = 0
                                                } completion: {
                                                    Task {
                                                        let nameMap = await appComp.exerciseProvider.nameMapSnapshot()
                                                        let items = editStore.exerciseSessions
                                                            .sorted { $0.exerciseChildDTO.order < $1.exerciseChildDTO.order }
                                                            .map { exerciseSession in
                                                                let title = nameMap[exerciseSession.exerciseChildDTO.exerciseId] ?? "Unknown"
                                                                return ReorderItem(
                                                                    id: exerciseSession.id,
                                                                    title: title,
                                                                    order: exerciseSession.exerciseChildDTO.order
                                                                )
                                                            }
                                                        
                                                        await MainActor.run {
                                                            self.reorderPayload = ReorderPayload(items: items)
                                                        }
                                                    }
                                                }
                                            } label: {
                                                Image(systemName: "shuffle")
                                                    .fontWeight(.medium)
                                                    .foregroundStyle(.indigo)
                                            }
                                            .buttonStyle(.plain)
                                            
                                        }),
                                    .init(content: {
                                        Button {
                                            withAnimation {
                                                propertyMenuProgress = 0
                                            } completion: {
                                                showEditSessionSheet = true
                                            }
                                        } label: {
                                            Image(systemName: "pencil")
                                                .fontWeight(.medium)
                                                .foregroundStyle(.indigo)
                                        }
                                        .buttonStyle(.plain)
                                    })
                                ],
                                fixedAttribute: .spacing(16)
                            )
                        ) {
                            ZStack {
                                Group {
                                    Button {
                                        guard propertyMenuProgress == 0 else { return }
                                        
                                        withAnimation (.smooth(duration: 0.3)) {
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
                                        
                                        withAnimation (.smooth(duration: 0.3)) {
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
                    }
                    .padding(.horizontal)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.smooth(duration: 0.3), value: hidePropertyMenu)
            .onChange(of: numpadHost.activeId, { oldValue, newValue in
                guard (oldValue == nil || newValue == nil) else { return }
                
                withAnimation(.snappy(duration: 0.2)) {
                    hidePropertyMenu.toggle()
                }
            })
            .ignoresSafeArea(edges: [.top])
            .sheet(isPresented: $showAddExerciseSheet) {
                ExercisePickerSheet(
                    isPresented: $showAddExerciseSheet,
                    config: .init(title: "Add exercises"),
                    exerciseProvider: appComp.exerciseProvider,
                    muscleGroupProvider: appComp.muscleGroupProvider) { exercisesToAdd in
                        editStore.addExercises(exercisesToAdd)
                    } onCancel: {
                        showAddExerciseSheet = false
                    }
            }
            .sheet(item: $reorderPayload) { payload in
                ReorderSheet(
                    isPresented: .constant(true),
                    items: payload.items,
                    orderBase: 0) { item in
                        HStack {
                            Text(item.title).font(.subheadline).fontWeight(.semibold)
                            Spacer()
                        }
                        .frame(height: 44)
                    } onCommit: { newOrders in
                        editStore.updateExercisesOrder(newOrders)
                        Task {
                            numpadHost.setOrder(await editStore.getGlobalFieldsOrder())
                        }
                        reorderPayload = nil
                    } onCancel: {
                        reorderPayload = nil
                    }
                
            }
            .sheet(item: $replaceExercisePayload, content: { payload in
                ExercisePickerSheet(
                    isPresented: .constant(true),
                    config: .init(
                        title: "Replace Exercise",
                        allowMultiSelect: false,
                        maxSelection: 1,
                        preselected: [],
                        showSearch: true
                    ),
                    exerciseProvider: appComp.exerciseProvider,
                    muscleGroupProvider: appComp.muscleGroupProvider) { selected in
                        guard selected.count == 1, let replacementId = selected.first else { return }
                        editStore.replaceExercise(id: payload.exerciseId, with: replacementId, resetSets: false)
                        
                        replaceExercisePayload = nil
                    } onCancel: {
                        replaceExercisePayload = nil
                    }
            })
            .sheet(isPresented: $showFinishWorkoutSheet) {
                FinishWorkoutSessionSheet(
                    editStore: editStore) {
                        showFinishWorkoutSheet = false
                    } onCompleteUnfinishedSets: {
                        showFinishWorkoutSheet = false
                        
                        Task {
                            await editStore.markAllSetsAsPerformed()
                        }
                        
                    } onDiscardUnfinishedSets: {
                        showFinishWorkoutSheet = false
                        
                        Task {
                            await editStore.discardAllUnperformedSets()
                        }
                        
                    } onFinishWorkoutSession: {
                        showFinishWorkoutSheet = false
                        
                        print("Finished workout session")
                    }

            }
            .sheet(isPresented: $showCancelWorkoutSessionSheet) {
                CancelWorkoutSessionSheet {
                    showCancelWorkoutSessionSheet = false
                } onConfirm: {
                    showCancelWorkoutSessionSheet = false
                    
                    Task {
                        if await editStore.cancel() {
                            isPresented = false
                            tabBarVisibility.show()
                        }
                    }
                }

            }
        }
    }
    
    @ViewBuilder
    func topBar () -> some View {
        HStack (alignment: .top, spacing: 16) {
            HStack (alignment: .center, spacing: 8) {
                CloseButton {
                    isPresented = false
                    tabBarVisibility.show()
                }
                
                if let startedAt = editStore.sessionDTO?.startedAt {
                    ElapsedTimeLabel(startedAt: startedAt)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.black)
                }
            }
            
            Spacer(minLength: 0)
            
            VStack (alignment: .trailing, spacing: 2) {
                Text(editStore.sessionDTO?.name ?? "No name")
                    .font(.title)
                    .fontWeight(.bold)
                    .lineLimit(1)
                
                HStack (alignment: .center, spacing: 4) {
                    let muscleGroupIDs = editStore.sessionDTO?.muscleGroupIDs ?? []
                    ForEach(muscleGroupIDs, id: \.self) { mgId in
                        Text(appComp.muscleGroupLookupSource.name(for: mgId))
                            .font(.footnote)
                            .fontWeight(.bold)
                            .foregroundStyle(.gray)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
        .padding(.top, 55)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.interactive(false), in: .rect(cornerRadii: .init(bottomLeading: 12, bottomTrailing: 12)))
        .compositingGroup()
        .shadow(color: .black.opacity(0.1), radius: 4, y: 4)
    }
}
