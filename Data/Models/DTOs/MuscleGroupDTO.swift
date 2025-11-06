import Foundation

struct MuscleGroupDTO: Identifiable & Hashable & Sendable {
    var id: UUID
    var version: Int
    var name: String
    var isPredefined: Bool
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
    
    nonisolated func fingerprint() -> Int {
        var h = Hasher()
        h.combine(id)
        h.combine(name)
        h.combine(isPredefined)
        return h.finalize()
    }
}
