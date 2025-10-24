import SwiftUI
import Combine

struct RootView: View {
    
    @ObservedObject var comp: AppComposition
    @StateObject private var tabActions: TabActionCenter = .init()
    @StateObject private var tabBarVisibility: TabBarVisibility = .init()
    @StateObject private var exerciseFilterStore: ExerciseFilterStore
    @StateObject private var templateFilterStore: TemplateFilterStore
    
    @StateObject private var sessionEditStore: WorkoutSessionEditStore
    @StateObject private var ribbonStore: SessionRibbonStore
    @State private var showSessionSheet: Bool = false
    
    @State private var activeTabItem: TabItem = .home
    
    //@StateObject private var numpadHost: _NumpadHost = .init()
    
    init (comp: AppComposition) {

        self._comp = ObservedObject(initialValue: comp)
        self._exerciseFilterStore = StateObject(
            wrappedValue: .init(
                exerciseProvider: comp.exerciseProvider,
                muscleGroupProvider: comp.muscleGroupProvider
            )
        )
        self._templateFilterStore = StateObject(
            wrappedValue: .init(
                templateProvider: comp.templateProvider
            )
        )
        
        self._sessionEditStore = StateObject(
            wrappedValue: .init(
                draftStore: comp.sessionDraftStore,
                repo: comp.sessionRepository
            )
        )
        
        self._ribbonStore = StateObject(
            wrappedValue: .init(
                draftStore: comp.sessionDraftStore
            )
        )
    }
    
    var body: some View {
        TabView(selection: $activeTabItem) {
            Tab.init(value: .home) {
                HomeView()
                    .toolbarVisibility(.hidden, for: .tabBar)
            }
            
            Tab.init(value: .exercises) {
                ExercisesView(filterStore: exerciseFilterStore)
                    .toolbarVisibility(.hidden, for: .tabBar)
            }
            
            Tab.init(value: .templates) {
                TemplatesView(filterStore: templateFilterStore)
                    .toolbarVisibility(.hidden, for: .tabBar)
            }
            
            Tab.init(value: .profile) {
                ProfileView()
                    .toolbarVisibility(.hidden, for: .tabBar)
            }
        }
        .environmentObject(comp)
        .environmentObject(tabActions)
        .environmentObject(tabBarVisibility)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            TabBarView()
                .padding(.horizontal)
                .offset(y: tabBarVisibility.isVisible ? 0 : 55)
                .opacity(tabBarVisibility.isVisible ? 1 : 0)
                .disabled(tabBarVisibility.isVisible ? false : true)
                .animation(.bouncy(duration: 0.3), value: tabBarVisibility.isVisible)
        }
        .fullScreenCover(isPresented: $showSessionSheet) {
            WorkoutSessionSheet(
                isPresented: $showSessionSheet,
                editStore: sessionEditStore,
            )
            .environmentObject(comp)
            .environmentObject(tabBarVisibility)
        }
        .task {
            ribbonStore.start()
        }
    }
    
    
    @ViewBuilder
    func TabBarView () -> some View {
        GlassEffectContainer (spacing: 10) {
            HStack(spacing: 10) {
                GeometryReader {
                    TabBar(size: $0.size, activeTabItem: $activeTabItem)
                        .overlay {
                            HStack (spacing: 0) {
                                ForEach(TabItem.allCases, id: \.rawValue) { tabItem in
                                    VStack (spacing: 4){
                                        Image(systemName: tabItem.symbol)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(height: 16)
                                        
                                        Text(tabItem.rawValue)
                                            .font(.system(size: 10))
                                            .fontWeight(.medium)
                                    }
                                    .symbolVariant(.fill)
                                    .foregroundStyle(activeTabItem == tabItem ? .indigo : .gray)
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .animation(.easeIn(duration: 0.25), value: activeTabItem)
                        }
                        .frame(maxWidth: .infinity)
                        .glassEffect(.regular.interactive(), in: .capsule)
                }
                
                Button {
                    tabActions.perform(for: activeTabItem)
                } label: {
                    ZStack {
                        ForEach(TabItem.allCases, id: \.rawValue) { tabItem in
                            Image(systemName: tabItem.actionSymbol)
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(.indigo)
                                .blurFade(activeTabItem == tabItem)
                        }
                    }
                    .frame(width: 55, height: 55)
                    .opacity(tabActions.hasAction(for: activeTabItem) ? 1 : 0)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .capsule)
                .animation(.smooth(duration: 0.55, extraBounce: 0), value: activeTabItem)
            }
        }
        .frame(height: 55)
        .safeAreaInset(edge: .top) {
            SessionRibbonView(store: ribbonStore) {
                if let dto = ribbonStore.active {
                    sessionEditStore.boot(dto: dto)
                    showSessionSheet = true
                }
            }
        }
    }
    
    
}

@MainActor
final class TabActionCenter: ObservableObject {
    typealias Action = @MainActor () async -> Void
    @Published private var actions: [TabItem: Action] = [:]
    
    func register (_ tabItem: TabItem, action: @escaping Action) {
        actions[tabItem] = action
    }
    
    func unregister (_ tabItem: TabItem) {
        actions.removeValue(forKey: tabItem)
    }
    
    func hasAction (for tabItem: TabItem) -> Bool {
        actions[tabItem] != nil
    }
    
    func perform (for tabItem: TabItem) {
        guard let action = actions[tabItem] else { return }
        Task {
            await action()
        }
    }
}

@MainActor
final class TabBarVisibility: ObservableObject {
    @Published var isVisible: Bool = true
    
    func show () {
        guard !isVisible else { return }
        withAnimation {
            isVisible = true
        }
    }
    
    func hide () {
        guard isVisible else { return }
        
        withAnimation {
            isVisible = false
        }
    }
}
