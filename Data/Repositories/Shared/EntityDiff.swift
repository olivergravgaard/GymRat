import Foundation

public struct EntityDiff<ID: Sendable & Hashable>: Sendable {
    public var inserted: [ID]
    public var updated: [ID]
    public var deleted: [ID]
    
    public nonisolated init (
        inserted: [ID] = [],
        updated: [ID] = [],
        deleted: [ID] = []
    ) {
        self.inserted = inserted
        self.updated = updated
        self.deleted = deleted
    }
}
