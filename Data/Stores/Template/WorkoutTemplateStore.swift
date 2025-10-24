import Foundation
import Combine

@MainActor
final class TemplateCatalogStore: ObservableObject {
    @Published private(set) var templates: [WorkoutTemplateDTO] = []
    
    private let provider: TemplateProvider
    private var task: Task<Void, Never>?
    
    init (provider: TemplateProvider) {
        self.provider = provider
        subscribe()
    }
    
    deinit {
        task?.cancel()
    }
    
    private func subscribe () {
        task = Task {
            let stream = await provider.streamAll()
            for await list in stream {
                self.templates = list
            }
        }
    }
}
