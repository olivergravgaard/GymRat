import SwiftUI
import SwiftData

@main
struct GymRat_RefactoredApp: App {
    
    @AppStorage("app_theme") private var storedTheme: String = AppTheme.system.rawValue
    
    private var theme: AppTheme {
        AppTheme(rawValue: storedTheme) ?? .system
    }
    
    @StateObject private var comp: AppComposition = {
        try! AppComposition(inMemory: false)
    }()
    
    var body: some Scene {
        WindowGroup {
            if comp.bootState == .ready {
                RootView(comp: comp)
                    .preferredColorScheme(theme.colorScheme)
            }else {
                ProgressView()
                    .task {
                        await comp.boot()
                    }
            }
        }
    }
}
