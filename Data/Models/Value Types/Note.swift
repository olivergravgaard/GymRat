import Foundation

nonisolated struct Note: Codable, Equatable, Sendable {
    var order: Int
    var note: String
    
    nonisolated static let defaultNote = Note(order: 0, note: "")
    
    nonisolated static func decode (from data: Data) -> Note {
        (try? JSONDecoder().decode(Note.self, from: data)) ?? .defaultNote
    }
    
    nonisolated func encoded() -> Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }
    
    nonisolated static func decodeMany(from data: Data) -> [Note] {
        (try? JSONDecoder().decode([Note].self, from: data)) ?? []
    }
    
    nonisolated static func encodeMany (_ notes: [Note]) -> Data {
        (try? JSONEncoder().encode(notes)) ?? Data()
    }
}
