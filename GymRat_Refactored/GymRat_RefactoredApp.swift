import SwiftUI
import SwiftData

@main
struct GymRat_RefactoredApp: App {
    
    @StateObject private var comp: AppComposition = {
        try! AppComposition(inMemory: false)
    }()
    
    var body: some Scene {
        WindowGroup {
            if comp.bootState == .ready {
                RootView(comp: comp)
            }else {
                ProgressView()
                    .task {
                        await comp.boot()
                    }
            }
        }
    }
}
