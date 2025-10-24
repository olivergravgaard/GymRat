import SwiftData
import Foundation

@Model
final class SetTemplate: Equatable, Identifiable {
    var id: UUID
    @Relationship var exerciseTemplate: ExerciseTemplate
    var order: Int
    var weightTarget: Double?
    var minReps: Int?
    var maxReps: Int?
    var setType: SetType
    
    @Attribute(.externalStorage) private var restTemplateData: Data?
    var restTemplate: RestTemplate? {
        get {
            guard let restTemplateData else { return nil }
            return RestTemplate.decode(from: restTemplateData)
        } set {
            guard let newValue else {
                restTemplateData = nil
                return
            }
            
            restTemplateData = newValue.encoded()
        }
    }
    
    init (exerciseTemplate: ExerciseTemplate, order: Int) {
        self.id = UUID()
        self.exerciseTemplate = exerciseTemplate
        self.order = order
        self.weightTarget = nil
        self.minReps = nil
        self.maxReps = nil
        self.setType = .regular
        self.restTemplateData = nil
    }
    
    init (from dto: SetTemplateDTO, exerciseTemplate: ExerciseTemplate) {
        self.id = UUID()
        self.exerciseTemplate = exerciseTemplate
        self.order = dto.order
        self.weightTarget = dto.weightTarget
        self.minReps = dto.minReps
        self.maxReps = dto.maxReps
        self.setType = dto.setType
        self.restTemplateData = dto.restTemplate?.encoded() ?? nil
    }
}
