import Foundation

struct MuscleGroupDTO: Identifiable & Hashable & Sendable {
    var id: UUID
    var name: String
    var isBuiltin: Bool
    
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
        h.combine(isBuiltin)
        return h.finalize()
    }
}
