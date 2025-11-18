import Foundation
import Combine

@MainActor

final class RecentSessionsStore: ObservableObject {
    @Published private(set) var recentSessions: [WorkoutSessionDTO] = []
    
    private let provider: SessionProvider
    private var task: Task<Void, Never>?
    
    init (provider: SessionProvider) {
        self.provider = provider
        
        self.start()
    }
    
    deinit {
        Task { [weak self] in
            await self?.stop()
        }
    }
    
    func start () {
        guard task == nil else { return }
        task = Task {
            for await list in await provider.recent(3) {
                await MainActor.run {
                    self.recentSessions = list
                }
            }
        }
    }
    
    func stop () {
        task?.cancel()
        task = nil
    }
}
