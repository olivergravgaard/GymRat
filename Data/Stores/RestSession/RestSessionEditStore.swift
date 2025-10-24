import Foundation
import Combine

final class RestSessionEditStore: ObservableObject, Identifiable {
    var uid: UUID
    @Published var dto: RestSession
    
    let parentEditStore: SetSessionEditStore
    
    init (dto: RestSession, parentEditStore: SetSessionEditStore) {
        self.uid = UUID()
        self.dto = dto
        self.parentEditStore = parentEditStore
    }
    
    func setDuration (_ v: Int) {
        dto.duration = v
    }
}
