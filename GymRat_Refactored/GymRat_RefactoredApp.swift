import SwiftUI
import SwiftData
import Firebase
import FirebaseAuth

@main
struct GymRat_RefactoredApp: App {
    
    @AppStorage("app_theme") private var storedTheme: String = AppTheme.system.rawValue
    
    private var theme: AppTheme {
        AppTheme(rawValue: storedTheme) ?? .system
    }
    
    @StateObject private var appComp: AppComposition
    @StateObject private var connectivity = ConnectivtyMonitor()
    
    init () {
        FirebaseApp.configure()
        
        _appComp = StateObject(wrappedValue: try! AppComposition(inMemory: false))
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if let user = appComp.authStore.user {
                    if appComp.bootState == .ready {
                        RootView(comp: appComp)
                            .id(user.uid)
                            .environmentObject(appComp)
                            .preferredColorScheme(theme.colorScheme)
                    }else {
                        ProgressView()
                            .task {
                                await appComp.boot()
                            }
                    }
                }else {
                    AuthView(authFormStore: AuthFormStore(authStore: appComp.authStore))
                }
            }
            .environmentObject(appComp)
        }
    }
}
