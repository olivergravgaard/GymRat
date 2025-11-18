import Foundation
import Combine

struct MonthSection: Identifiable {
    let id: String
    let title: String
    let year: Int
    let month: Int
    let workoutSessions: [WorkoutSessionDTO]
}

@MainActor
final class AllWorkoutSessionsStore: ObservableObject {
    @Published private(set) var groupedWorkoutSessions: [MonthSection] = []
    private var allSessions: [WorkoutSessionDTO] = []
    
    @Published var searchText: String = ""
    @Published var dateInterval: DateInterval?
    
    private let provider: SessionProvider
    private var task: Task<Void, Never>?
    private let calendar = Calendar.current
    
    private var cancellables: Set<AnyCancellable> = []

    
    init (sessionProvider: SessionProvider) {
        self.provider = sessionProvider
        self.bindFilters()
        self.start()
    }
    
    deinit {
        Task { [weak self] in
            await self?.stop()
        }
    }
    
    private func bindFilters () {
        $searchText
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .removeDuplicates()
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.recompute()
            }
            .store(in: &cancellables)
        
        $dateInterval
            .removeDuplicates { lhs, rhs in
                switch (lhs, rhs) {
                case (nil, nil):
                    return true
                    
                case let (l?, r?):
                    return l.start == r.start && l.end == r.end
                default:
                    return false
                }
            }
            .sink { [weak self] _ in
                guard let self else { return }
                self.recompute()
            }
            .store(in: &cancellables)
    }
    
    private func start () {
        guard task == nil else { return }
        
        task = Task {
            for await list in await provider.streamAll() {
                if Task.isCancelled { break }
                await MainActor.run {
                    if list != self.allSessions {
                        self.allSessions = list
                        self.recompute()
                    }
                }
            }
        }
    }
    
    private func stop () {
        task?.cancel()
        task = nil
    }
    
    private func recompute () {
        let filterd = applyFilters(on: allSessions)
        groupedWorkoutSessions = groupByMonth(filterd)
    }
    
    private func applyFilters (on sessions: [WorkoutSessionDTO]) -> [WorkoutSessionDTO] {
        var result = sessions
        
        if let interval = dateInterval {
            result = result.filter({ session in
                let d = session.endedAt ?? session.startedAt
                return d >= interval.start && d <= interval.end
            })
        }
        
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            result = result.filter({ session in
                return session.name.lowercased().contains(q)
            })
        }
        
        print("Filtered: \(result.count)")
        
        return result
    }
    
    private struct YearMonth: Hashable {
        let year: Int
        let month: Int
    }

    private func groupByMonth(_ sessions: [WorkoutSessionDTO]) -> [MonthSection] {
        guard !sessions.isEmpty else {
            return []
        }
        
        print("Grouping on \(sessions.count)")

        let grouped = Dictionary(grouping: sessions) { session -> YearMonth in
            let date = session.endedAt ?? session.startedAt
            let comps = calendar.dateComponents([.year, .month], from: date)
            return YearMonth(year: comps.year ?? 0, month: comps.month ?? 0)
        }

        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "LLLL yyyy"

        let sections = grouped.compactMap { (key, value) -> MonthSection? in
            guard let date = calendar.date(from: DateComponents(year: key.year, month: key.month)) else {
                return nil
            }

            let title = formatter.string(from: date).capitalized

            return MonthSection(
                id: "\(key.year)-\(key.month)",
                title: title,
                year: key.year,
                month: key.month,
                workoutSessions: value.sorted {
                    let d1 = $0.endedAt ?? $0.startedAt
                    let d2 = $1.endedAt ?? $1.startedAt
                    return d1 > d2           // nyeste først
                }
            )
        }

        return sections.sorted { lhs, rhs in
            if lhs.year == rhs.year {
                return lhs.month > rhs.month
            } else {
                return lhs.year > rhs.year
            }
        }
    }

}
