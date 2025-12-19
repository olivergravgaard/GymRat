import SwiftUI
import Foundation
import FirebaseAuth

struct ReorderPayload: Identifiable {
    let id = UUID()
    let items: [ReorderItem<UUID>]
}

struct ReplaceExercisePayload: Identifiable {
    let id = UUID()
    let exerciseId: UUID
}

struct EditTemplateView: View {
    @EnvironmentObject private var appComp: AppComposition
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var tabBarVisibility: TabBarVisibility
    
    @StateObject var editStore: WorkoutTemplateEditStore
    let originalDTO: WorkoutTemplateDTO
    
    @State private var propertyMenuProgress: CGFloat = 0
    @State private var showEditTemplateSheet: Bool = false
    @State private var showAddExerciseSheet: Bool = false
    @State private var showUnsavedChangesSheet: Bool = false
    @State private var reorderPayload: ReorderPayload?
    @State private var showOverwriteSessionSheet: Bool = false
    
    @State private var replaceExercisePayload: ReplaceExercisePayload?
    
    @StateObject var numpadHost: NumpadHost = .init()
    @StateObject var standaloneNumpadHost: FocusOnlyHost = .init()
    
    @State private var hidePropertyMenu: Bool = false
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack {
                    ForEach(editStore.exerciseTemplates, id: \.id) { exerciseTemplate in
                        ExerciseTemplateView(
                            editStore: exerciseTemplate,
                            replaceExercisePayload: $replaceExercisePayload,
                            numpadHost: numpadHost,
                            standaloneNumpadHost: standaloneNumpadHost,
                            proxy: proxy
                        )
                    }
                }
            }
            .onAppear {
                tabBarVisibility.hide()
                
                Task {
                    numpadHost.setOrder(await editStore.getGlobalFieldsOrder())
                }
                
                numpadHost.onScrollTo = { id in
                    withAnimation (.snappy(duration: 0.2)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .top) {
                topBar()
                    .frame(maxWidth: .infinity)
            }
            .keyboardInset(host: numpadHost)
            .ignoresSafeArea(edges: [.bottom])
            .overlay (alignment: .bottomTrailing) {
                if !hidePropertyMenu {
                    HStack (alignment: .bottom, spacing: 16) {
                        if editStore.isDirty {
                            Button {
                                Task {
                                    try await editStore.save(using: originalDTO)
                                }
                            } label: {
                                Capsule().fill(.green.opacity(0.3))
                                    .frame(width: 144, height: 55)
                                    .overlay(alignment: .center) {
                                        Text("Save")
                                            .foregroundStyle(.green)
                                            .font(.caption)
                                            .fontWeight(.bold)
                                    }
                            }
                            .glassEffect(.regular.interactive(true), in: .capsule(style: .continuous))

                        }
                        
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
                                                Task { @MainActor in
                                                    let result = try await appComp.sessionStarter.start(from: originalDTO, behavior: .ask)
                                                    
                                                    switch result {
                                                    case .started( _):
                                                        dismiss()
                                                        tabBarVisibility.show()
                                                    case .conflict( _):
                                                        showOverwriteSessionSheet = true
                                                    }
                                                }
                                            }
                                        } label: {
                                            Image(systemName: "play.circle.fill")
                                                .fontWeight(.medium)
                                                .foregroundStyle(.indigo)
                                        }
                                        
                                    }),
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
                                                        let items = editStore.exerciseTemplates
                                                            .sorted { $0.exerciseChildDTO.order < $1.exerciseChildDTO.order }
                                                            .map { exerciseTemplate in
                                                                let title = nameMap[exerciseTemplate.exerciseChildDTO.exerciseId] ?? "Unknown"
                                                                return ReorderItem(
                                                                    id: exerciseTemplate.id,
                                                                    title: title,
                                                                    order: exerciseTemplate.exerciseChildDTO.order
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
                                                showEditTemplateSheet = true
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
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                    }
            }
            .animation(.smooth(duration: 0.3), value: hidePropertyMenu)
            .onChange(of: numpadHost.activeId, { oldValue, newValue in
                guard (oldValue == nil || newValue == nil) else { return }
                
                withAnimation {
                    hidePropertyMenu.toggle()
                }
            })
            .ignoresSafeArea(edges: [.top])
            .sheet(isPresented: $showEditTemplateSheet) {
                EditTemplateSheet(
                    isPresented: $showEditTemplateSheet,
                    template: originalDTO,
                    templateProvider: appComp.templateProvider,
                    muscleGroupProvider: appComp.muscleGroupProvider,
                    workoutTemplateSyncService: appComp.workoutTemplateSyncService,
                    userId: appComp.authStore.user?.uid
                )
            }
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
                        reorderPayload = nil
                    } onCancel: {
                        reorderPayload = nil
                    }
                
            }
            .sheet(isPresented: $showUnsavedChangesSheet) {
                UnsavedChangesTemplateSheet(
                    isPresented: $showUnsavedChangesSheet) {
                        withAnimation {
                            showUnsavedChangesSheet = false
                        } completion: {
                            Task {
                                try await editStore.save(using: originalDTO)
                                await Task.yield()
                            }
                            
                            dismiss()
                            tabBarVisibility.show()
                        }
                        
                    } onDiscard: {
                        withAnimation {
                            showUnsavedChangesSheet = false
                        } completion: {
                            dismiss()
                            tabBarVisibility.show()
                        }
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
            .sheet(isPresented: $showOverwriteSessionSheet) {
                OverwriteSessionSheet(
                    isPresented: $showOverwriteSessionSheet) {
                        Task { @MainActor in
                            await appComp.sessionDraftStore.clear()
                            let result = try await appComp.sessionStarter.start(from: originalDTO)
                            
                            switch result {
                            case .started(_):
                                showOverwriteSessionSheet = false
                                dismiss()
                                tabBarVisibility.show()
                            case .conflict(_):
                                print("Something went wrong?")
                            }
                        }
                    } onClose: {
                        showOverwriteSessionSheet = false
                    }
                
            }
        }
    }
    
    @ViewBuilder
    func topBar () -> some View {
        HStack (alignment: .top){
            DismissButton {
                if editStore.isDirty {
                    showUnsavedChangesSheet = true
                }else {
                    dismiss()
                    tabBarVisibility.show()
                }
            }
            
            Spacer(minLength: 8)
            
            VStack (alignment: .trailing, spacing: 2) {
                Text(originalDTO.name)
                    .font(.title)
                    .fontWeight(.bold)
                    .lineLimit(1)
                
                HStack (alignment: .center, spacing: 4) {
                    ForEach(originalDTO.muscleGroupsIDs, id: \.self) { mgId in
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
