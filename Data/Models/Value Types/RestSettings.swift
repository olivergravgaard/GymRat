import Foundation

enum RestState: String, Codable, Equatable {
    case idle
    case running
    case completed

}

nonisolated struct RestTemplate: Codable, Equatable, Sendable {
    var duration: Int 
    
    nonisolated static let defaultSettings = RestTemplate(
        duration: 0
    )
    
    nonisolated static func decode (from data: Data) -> RestTemplate {
        (try? JSONDecoder().decode(RestTemplate.self, from: data)) ?? .defaultSettings
    }
    
    nonisolated func encoded() -> Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }
}

nonisolated struct RestSession: Codable, Equatable, Sendable {
    var duration: Int
    var startedAt: Date?
    var endedAt: Date?
    var restState: RestState
        
    init (duration: Int, startedAt: Date?, endedAt: Date?, restState: RestState) {
        self.duration = duration
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.restState = restState
    }
    
    init (from restTemplate: RestTemplate) {
        self.duration = restTemplate.duration
        self.startedAt = nil
        self.endedAt = nil
        self.restState = .idle
    }
    
    nonisolated static let defaultSettings = RestSession(
        duration: 0,
        startedAt: nil,
        endedAt: nil,
        restState: .idle
    )
    
    nonisolated static func decode (from data: Data) -> RestSession {
        (try? JSONDecoder().decode(RestSession.self, from: data)) ?? .defaultSettings
    }
    
    nonisolated func encoded() -> Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }
}
