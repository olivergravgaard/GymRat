import Foundation

// MARK: - Value objects
nonisolated struct ExerciseSettings: Codable, Equatable, Sendable {
    var metricType: MetricType
    var useRestTimer: Bool
    var setRestDuration: Int
    var useWarmupRestTimer: Bool
    var warmupRestDuration: Int

    nonisolated static let defaultSettings = ExerciseSettings(
        metricType: .kg,
        useRestTimer: true,
        setRestDuration: 120,
        useWarmupRestTimer: true,
        warmupRestDuration: 60
    )
}

extension ExerciseSettings {
    nonisolated static func decode(from data: Data) -> ExerciseSettings {
        (try? JSONDecoder().decode(ExerciseSettings.self, from: data)) ?? .defaultSettings
    }

    nonisolated func encoded() -> Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }
}
