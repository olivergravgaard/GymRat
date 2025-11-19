import SwiftUI
import SwiftData
import Firebase

@main
struct GymRat_RefactoredApp: App {
    
    @AppStorage("app_theme") private var storedTheme: String = AppTheme.system.rawValue
    
    private var theme: AppTheme {
        AppTheme(rawValue: storedTheme) ?? .system
    }
    
    @StateObject private var comp: AppComposition = {
        try! AppComposition(inMemory: false)
    }()
    
    @StateObject private var authStore: AuthStore
    @StateObject private var profileStore: ProfileStore
    @StateObject private var connectivity = ConnectivtyMonitor()
    
    init () {
        FirebaseApp.configure()
        
        let authStore = AuthStore()
        _authStore = StateObject(wrappedValue: authStore)
        _profileStore = StateObject(wrappedValue: ProfileStore(authStore: authStore))
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authStore.user != nil {
                    if comp.bootState == .ready {
                        RootView(comp: comp)
                            .environmentObject(authStore)
                            .environmentObject(profileStore)
                            .preferredColorScheme(theme.colorScheme)
                    }else {
                        ProgressView()
                            .task {
                                await comp.boot()
                            }
                    }
                }else {
                    AuthView(authFormStore: AuthFormStore(authStore: authStore))
                }
            }
            .task {
                if connectivity.isOnline {
                    await authStore.validateSessionIfNeeded()
                }
            }
            .onChange(of: connectivity.isOnline) { _, isOnline in
                guard isOnline else { return }
                
                Task {
                    await authStore.validateSessionIfNeeded()
                }
            }
        }
    }
}
