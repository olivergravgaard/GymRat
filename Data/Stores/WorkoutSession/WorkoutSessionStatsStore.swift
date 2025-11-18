
import Foundation
import Combine

enum WorkoutSessionStatsRangeQuery: Equatable {
    case thisWeek
    case last7Days
    case custom(DateInterval)
    
    func resolveRange (calendar: Calendar = .current, now: Date = .now) -> DateInterval {
        switch self {
        case .thisWeek:
            let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            let end = calendar.date(byAdding: .day, value: 7, to: start)!
            return .init(start: start, end: end)
        case .last7Days:
            let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -6, to: now)!)
            let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
            return .init(start: start, end: end)
        case .custom(let dateInterval):
            return dateInterval
        }
    }
}

struct WorkoutSessionStatsSnapshot: Equatable {
    var workoutCount: Int = 0
    var totalSets: Int = 0
    var totalDuration: Int = 0
    var streakDays: Int = 0
}

@MainActor
final class WorkoutSessionStatsStore: ObservableObject {
    @Published private(set) var statsSnapshot: WorkoutSessionStatsSnapshot = .init()
    @Published var rangeQuery: WorkoutSessionStatsRangeQuery = .thisWeek {
        didSet {
            recompute()
        }
    }
    
    private let provider: SessionProvider
    private var task: Task<Void, Never>?
    private var allSessions: [WorkoutSessionDTO] = []
    
    init (sessionProvider: SessionProvider) {
        self.provider = sessionProvider
        
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
            for await list in await provider.streamAll() {
                if Task.isCancelled { break }
                
                await MainActor.run {
                    self.allSessions = list
                    self.recompute()
                }
            }
        }
    }
    
    func stop () {
        task?.cancel()
        task = nil
    }
    
    private func recompute (now: Date = .now, calendar: Calendar = .current) {
        let range = self.rangeQuery.resolveRange(calendar: calendar, now: now)
        
        let sessionsInRange = allSessions.filter { session in
            let d = (session.endedAt ?? session.startedAt)
            return d >= range.start && d < range.end
        }
        
        let workoutSessions = sessionsInRange.count
        let sets = sessionsInRange.reduce(0) {
            $0 + $1.totalSetsCount
        }
        let duration = sessionsInRange.reduce(0) {
            $0 + $1.duration
        }
        let streakEndAnchor = min(now, range.end)
        let streak = Self.computeStreakDays(
            allSessions: allSessions,
            upTo: streakEndAnchor,
            calendar: calendar
        )
        
        statsSnapshot = .init(
            workoutCount: workoutSessions,
            totalSets: sets,
            totalDuration: duration,
            streakDays: streak
        )
    }
    
    private static func computeStreakDays
    (
        allSessions: [WorkoutSessionDTO],
        upTo: Date,
        calendar: Calendar
    ) -> Int {
        let daysWithWorkout: Set<Date> = Set(
            allSessions.map { calendar.startOfDay(for: ($0.endedAt ?? $0.startedAt)) }
        )

        var streak = 0
        var cursor = calendar.startOfDay(for: upTo)

        while daysWithWorkout.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }
    
}
