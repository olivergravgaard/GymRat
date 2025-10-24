struct TemplateCatalog {
    struct Def {
        let name: String
        let muscleGroups: [String]
        let exercises: [String]
    }
    
    static let previews: [Def] = [
        .init(
            name: "Push V1",
            muscleGroups: [
                "Chest",
                "Shoulders",
                "Triceps"
            ],
            exercises: [
                "Bench Press",
                "Overhead Press",
                "Tricep Pushdown",
                "Bench Press",
                "Overhead Press",
                "Tricep Pushdown",
                "Bench Press",
                "Overhead Press",
                "Tricep Pushdown",
                "Bench Press",
                "Overhead Press",
                "Tricep Pushdown",
                "Bench Press",
                "Overhead Press",
                "Tricep Pushdown",
                "Bench Press",
                "Overhead Press",
                "Tricep Pushdown",
                "Bench Press",
                "Overhead Press",
                "Tricep Pushdown",
                "Bench Press",
                "Overhead Press",
                "Tricep Pushdown",
                "Bench Press",
                "Overhead Press",
                "Tricep Pushdown",
                "Bench Press",
                "Overhead Press",
                "Tricep Pushdown",
                "Bench Press",
                "Overhead Press",
                "Tricep Pushdown"
            ]
        )
    ]
    
    static let defaults: [Def] = [
        .init(
            name: "Push V1",
            muscleGroups: [
                "Chest",
                "Shoulders",
                "Triceps"
            ],
            exercises: [
                "Bench press",
                "Overhead Press",
                "Tricep Pushdown"
            ]
        ),
        .init(
            name: "Pull V1",
            muscleGroups: [
                "Back",
                "Biceps"
            ],
            exercises: [
                "Pull-up",
                "T-Bar Row",
                "Bicep Curl",
                "21s Curl"
            ]
        )
    ]
}
