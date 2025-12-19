import Foundation

struct ExerciseDefinition: Sendable {
    let id: UUID
    let name: String
    let muscleGroupID: UUID
    let isBuiltin: Bool
    
    init(name: String, muscleGroupID: UUID) {
        self.id = Catalog.uuidV5(namespace: Catalog.exerciseNamespace, idString: "\(name).\(muscleGroupID)")
        self.name = name
        self.muscleGroupID = muscleGroupID
        self.isBuiltin = true
    }
}

enum ExerciseCatalog {
    static let builtins: [ExerciseDefinition] = [
        .init(name: "Bench Press", muscleGroupID: MuscleGroupCatalog.findID(name: "Chest")!),
        .init(name: "Pull-up", muscleGroupID: MuscleGroupCatalog.findID(name: "Back")!),
        .init(name: "Overhead Press", muscleGroupID: MuscleGroupCatalog.findID(name: "Shoulders")!),
        .init(name: "Bicep Curl", muscleGroupID: MuscleGroupCatalog.findID(name: "Biceps")!)
    ]

    static let previews: [ExerciseDefinition] = [
        .init(name: "Bench Press", muscleGroupID: MuscleGroupCatalog.findID(name: "Chest")!),
        .init(name: "Pull-up", muscleGroupID: MuscleGroupCatalog.findID(name: "Back")!),
        .init(name: "Overhead Press", muscleGroupID: MuscleGroupCatalog.findID(name: "Shoulders")!),
        .init(name: "Bicep Curl", muscleGroupID: MuscleGroupCatalog.findID(name: "Biceps")!)
    ]
}



