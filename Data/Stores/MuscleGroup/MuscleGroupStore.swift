import Foundation
import Combine

@MainActor
final class MuscleGroupStore: ObservableObject {
    
    @Published private(set) var muscleGroups: [MuscleGroupDTO] = []
    
    private let provider: MuscleGroupProvider
    private var task: Task<Void, Never>?
    
    init (provider: MuscleGroupProvider) {
        self.provider = provider
        subscribe()
    }
    
    deinit  {
        task?.cancel()
    }
    
    private func subscribe () {
        task = Task {
            let stream = await provider.streamAll()
            for await list in stream {
                self.muscleGroups = list.sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
            }
        }
    }
}
