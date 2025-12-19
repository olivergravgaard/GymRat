import Foundation

struct MuscleGroupDefinition: Sendable {
    let id: UUID
    let name: String
    let isBuiltin: Bool

    init(name: String) {
        self.id = Catalog.uuidV5(namespace: Catalog.muscleGroupNamespace, idString: name)
        self.name = name
        self.isBuiltin = true
    }
}

enum MuscleGroupCatalog {
    static let builtins: [MuscleGroupDefinition] = [
        .init(name: "Chest"),
        .init(name: "Back"),
        .init(name: "Shoulders"),
        .init(name: "Triceps"),
        .init(name: "Biceps"),
        .init(name: "Calves"),
        .init(name: "Forearems"),
        .init(name: "Core"),
        .init(name: "Neck"),
        .init(name: "Glutes"),
        .init(name: "Hamstrings"),
    ]
    
    static func findID (name: String) -> UUID? {
        return builtins.first(where: { $0.name.lowercased() == name.lowercased() })?.id
    }
}
