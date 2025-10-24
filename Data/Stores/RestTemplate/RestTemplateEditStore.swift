import Foundation
import Combine

final class RestTemplateEditStore: ObservableObject, Identifiable {
    var uid: UUID
    @Published var dto: RestTemplate
    
    let parentEditStore: SetTemplateEditStore
    
    init (dto: RestTemplate, parentEditStore: SetTemplateEditStore) {
        self.uid = UUID()
        self.dto = dto
        self.parentEditStore = parentEditStore
    }
    
    func setDuration (_ v: Int) {
        dto.duration = v
    }
}
