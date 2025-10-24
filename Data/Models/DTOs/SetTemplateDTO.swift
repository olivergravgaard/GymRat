import Foundation

struct SetTemplateDTO: SetChildDTO {
    var id: UUID
    var order: Int
    var weightTarget: Double?
    var minReps: Int?
    var maxReps: Int?
    var setType: SetType
    var restTemplate: RestTemplate?
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

