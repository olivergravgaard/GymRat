struct ExerciseCatalog {
    struct Def {
        let name: String
        let muscleGroup: String
    }
    
    static let previews: [Def] = [
        .init(name: "Bench Press", muscleGroup: "Chest"),
        .init(name: "Pull-up", muscleGroup: "Back"),
        .init(name: "Overhead Press", muscleGroup: "Shoulders"),
        .init(name: "Bicep Curl", muscleGroup: "Biceps"),
        .init(name: "Tricep Pushdown", muscleGroup: "Triceps"),
        .init(name: "Squat", muscleGroup: "Quads"),
        .init(name: "Deadlift", muscleGroup: "Hamstrings"),
        .init(name: "Hip Thrust", muscleGroup: "Glutes"),
        .init(name: "Standing Calf Raise", muscleGroup: "Calves"),
        .init(name: "Plank", muscleGroup: "Core"),
    ]

    static let defaults: [Def] = [
        // Chest
        .init(name: "Bench Press", muscleGroup: "Chest"),
        .init(name: "Incline Dumbbell Press", muscleGroup: "Chest"),
        .init(name: "Decline Bench Press", muscleGroup: "Chest"),
        .init(name: "Dumbbell Flyes", muscleGroup: "Chest"),
        .init(name: "Cable Crossover", muscleGroup: "Chest"),
        .init(name: "Push-ups", muscleGroup: "Chest"),
        .init(name: "Machine Chest Press", muscleGroup: "Chest"),
        .init(name: "Chest Dips", muscleGroup: "Chest"),
        .init(name: "Svend Press", muscleGroup: "Chest"),
        .init(name: "Incline Push-ups", muscleGroup: "Chest"),

        // Back
        .init(name: "Pull-up", muscleGroup: "Back"),
        .init(name: "Chin-up", muscleGroup: "Back"),
        .init(name: "Lat Pulldown", muscleGroup: "Back"),
        .init(name: "Barbell Row", muscleGroup: "Back"),
        .init(name: "Single-arm Dumbbell Row", muscleGroup: "Back"),
        .init(name: "T-Bar Row", muscleGroup: "Back"),
        .init(name: "Seated Cable Row", muscleGroup: "Back"),
        .init(name: "Inverted Row", muscleGroup: "Back"),
        .init(name: "Trap Bar Deadlift", muscleGroup: "Back"),
        .init(name: "Face Pull", muscleGroup: "Back"),

        // Shoulders
        .init(name: "Overhead Press", muscleGroup: "Shoulders"),
        .init(name: "Seated Dumbbell Press", muscleGroup: "Shoulders"),
        .init(name: "Arnold Press", muscleGroup: "Shoulders"),
        .init(name: "Lateral Raises", muscleGroup: "Shoulders"),
        .init(name: "Front Raises", muscleGroup: "Shoulders"),
        .init(name: "Reverse Flyes", muscleGroup: "Shoulders"),
        .init(name: "Cable Lateral Raises", muscleGroup: "Shoulders"),
        .init(name: "Upright Row", muscleGroup: "Shoulders"),
        .init(name: "Dumbbell Shrugs", muscleGroup: "Shoulders"),
        .init(name: "Behind-the-neck Press", muscleGroup: "Shoulders"),

        // Biceps
        .init(name: "Bicep Curl", muscleGroup: "Biceps"),
        .init(name: "Hammer Curl", muscleGroup: "Biceps"),
        .init(name: "Concentration Curl", muscleGroup: "Biceps"),
        .init(name: "Preacher Curl", muscleGroup: "Biceps"),
        .init(name: "Cable Curl", muscleGroup: "Biceps"),
        .init(name: "EZ Bar Curl", muscleGroup: "Biceps"),
        .init(name: "Zottman Curl", muscleGroup: "Biceps"),
        .init(name: "Incline Dumbbell Curl", muscleGroup: "Biceps"),
        .init(name: "21s Curl", muscleGroup: "Biceps"),
        .init(name: "Machine Bicep Curl", muscleGroup: "Biceps"),

        // Triceps
        .init(name: "Tricep Pushdown", muscleGroup: "Triceps"),
        .init(name: "Overhead Tricep Extension", muscleGroup: "Triceps"),
        .init(name: "Close-grip Bench Press", muscleGroup: "Triceps"),
        .init(name: "Dumbbell Kickback", muscleGroup: "Triceps"),
        .init(name: "Skull Crushers", muscleGroup: "Triceps"),
        .init(name: "Bench Dips", muscleGroup: "Triceps"),
        .init(name: "Rope Pushdown", muscleGroup: "Triceps"),
        .init(name: "Diamond Push-ups", muscleGroup: "Triceps"),
        .init(name: "Reverse Grip Pushdown", muscleGroup: "Triceps"),
        .init(name: "Machine Tricep Extension", muscleGroup: "Triceps"),

        // Quads
        .init(name: "Squat", muscleGroup: "Quads"),
        .init(name: "Front Squat", muscleGroup: "Quads"),
        .init(name: "Leg Press", muscleGroup: "Quads"),
        .init(name: "Bulgarian Split Squat", muscleGroup: "Quads"),
        .init(name: "Walking Lunge", muscleGroup: "Quads"),
        .init(name: "Step-ups", muscleGroup: "Quads"),
        .init(name: "Sissy Squat", muscleGroup: "Quads"),
        .init(name: "Hack Squat", muscleGroup: "Quads"),
        .init(name: "Goblet Squat", muscleGroup: "Quads"),
        .init(name: "Wall Sit", muscleGroup: "Quads"),

        // Hamstrings
        .init(name: "Deadlift", muscleGroup: "Hamstrings"),
        .init(name: "Romanian Deadlift", muscleGroup: "Hamstrings"),
        .init(name: "Lying Leg Curl", muscleGroup: "Hamstrings"),
        .init(name: "Seated Leg Curl", muscleGroup: "Hamstrings"),
        .init(name: "Good Morning", muscleGroup: "Hamstrings"),
        .init(name: "Single-leg Romanian Deadlift", muscleGroup: "Hamstrings"),
        .init(name: "Nordic Curl", muscleGroup: "Hamstrings"),
        .init(name: "Glute Ham Raise", muscleGroup: "Hamstrings"),
        .init(name: "Kettlebell Swing", muscleGroup: "Hamstrings"),
        .init(name: "Swiss Ball Leg Curl", muscleGroup: "Hamstrings"),

        // Glutes
        .init(name: "Hip Thrust", muscleGroup: "Glutes"),
        .init(name: "Glute Bridge", muscleGroup: "Glutes"),
        .init(name: "Cable Kickback", muscleGroup: "Glutes"),
        .init(name: "Reverse Lunge", muscleGroup: "Glutes"),
        .init(name: "Sumo Deadlift", muscleGroup: "Glutes"),
        .init(name: "Curtsy Lunge", muscleGroup: "Glutes"),
        .init(name: "Banded Glute Walk", muscleGroup: "Glutes"),
        .init(name: "Step-up to Knee Raise", muscleGroup: "Glutes"),
        .init(name: "Single-leg Hip Thrust", muscleGroup: "Glutes"),
        .init(name: "Barbell Glute Bridge", muscleGroup: "Glutes"),

        // Calves
        .init(name: "Standing Calf Raise", muscleGroup: "Calves"),
        .init(name: "Seated Calf Raise", muscleGroup: "Calves"),
        .init(name: "Donkey Calf Raise", muscleGroup: "Calves"),
        .init(name: "Single-leg Calf Raise", muscleGroup: "Calves"),
        .init(name: "Leg Press Calf Raise", muscleGroup: "Calves"),
        .init(name: "Farmer's Walk on Toes", muscleGroup: "Calves"),
        .init(name: "Box Jumps", muscleGroup: "Calves"),
        .init(name: "Skipping Rope", muscleGroup: "Calves"),
        .init(name: "Tiptoe Walk", muscleGroup: "Calves"),
        .init(name: "Sprint Drills", muscleGroup: "Calves"),

        // Core
        .init(name: "Plank", muscleGroup: "Core"),
        .init(name: "Side Plank", muscleGroup: "Core"),
        .init(name: "Hanging Leg Raise", muscleGroup: "Core"),
        .init(name: "Ab Wheel Rollout", muscleGroup: "Core"),
        .init(name: "Russian Twists", muscleGroup: "Core"),
        .init(name: "Bicycle Crunch", muscleGroup: "Core"),
        .init(name: "Mountain Climbers", muscleGroup: "Core"),
        .init(name: "Cable Woodchopper", muscleGroup: "Core"),
        .init(name: "Flutter Kicks", muscleGroup: "Core"),
        .init(name: "V-ups", muscleGroup: "Core")
    ]
}
