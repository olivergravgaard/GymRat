import Foundation

struct MuscleGroupCatalog {
    struct Def {
        let name: String
    }
    
    static let defaults: [Def] = [
        .init(name: "Chest"),
        .init(name: "Back"),
        .init(name: "Shoulders"),
        .init(name: "Biceps"),
        .init(name: "Triceps"),
        .init(name: "Quads"),
        .init(name: "Hamstrings"),
        .init(name: "Glutes"),
        .init(name: "Calves"),
        .init(name: "Core")
    ]
}
