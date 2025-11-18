import Foundation
import Combine

struct ExerciseHistoryEntry: Identifiable, Equatable {
    var id: UUID { sessionId }
    
    let sessionId: UUID
    let sessionName: String
    let performedAt: Date
    let exerciseSession: ExerciseSessionDTO
}

@MainActor
final class ExerciseHistoryStore: ObservableObject {
    @Published private(set) var sessions: [ExerciseHistoryEntry] = []
    
    private let exerciseId: UUID
    private let sessionProvider: SessionProvider
    private var task: Task<Void, Never>?
    
    init (exerciseId: UUID, sessionProvider: SessionProvider) {
        self.exerciseId = exerciseId
        self.sessionProvider = sessionProvider
        
        self.start()
    }
    
    deinit {
        
    }
    
    private func start () {
        guard task == nil else { return }
        
        task = Task {
            for await sessions in await sessionProvider.streamAll() {
                if Task.isCancelled { break }
                
                let mappedSessions = Self.map(sessions: sessions, for: exerciseId)
                
                await MainActor.run {
                    self.sessions = mappedSessions
                }
            }
        }
    }
    
    private static func map (
        sessions: [WorkoutSessionDTO],
        for exerciseId: UUID
    ) -> [ExerciseHistoryEntry] {
        sessions.compactMap { session in
            guard var exerciseSession = session.exercises.first(where: { $0.exerciseId == exerciseId}) else {
                return nil
            }
            
            exerciseSession.sets.sort(by: { $0.order < $1.order })
            
            return .init(
                sessionId: session.id,
                sessionName: session.name,
                performedAt: session.endedAt ?? session.startedAt,
                exerciseSession: exerciseSession
            )
        }
        .sorted { $0.performedAt > $1.performedAt }
    }
}
