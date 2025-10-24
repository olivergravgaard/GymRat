import SwiftData
import Foundation

@Model
final class ActiveSessionMarker {
    var id: UUID
    var sessionId: UUID
    
    init (sessionId: UUID) {
        self.id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        self.sessionId = sessionId
    }
}
