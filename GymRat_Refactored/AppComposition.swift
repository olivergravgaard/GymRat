import SwiftUI
import SwiftData
import Combine

@MainActor
final class AppComposition: ObservableObject {
    enum BootState: Equatable {
        case idle, booting, ready
        case failed(String)
    }
    
    let modelContainer: ModelContainer
    let modelContext: ModelContext
    
    // Repositories
    let muscleGroupRepository: MuscleGroupRepository
    let exerciseRepository: ExerciseRepository
    let templateRepository: TemplateRepository
    let sessionRepository: SessionRepository
    
    // Providers
    let muscleGroupProvider: MuscleGroupProvider
    let exerciseProvider: ExerciseProvider
    let templateProvider: TemplateProvider
    let sessionDraftStore: SessionDraftStore
    let sessionStarter: SessionStarter
    
    // Lookup Sources
    let muscleGroupLookupSource: MuscleGroupLookupSource
    let exerciseLookupSource: ExerciseLookupSource
    let exerciseMuscleGroupNameLookupSource: ExerciseMuscleGroupNameLookupSource
    
    @Published private(set) var bootState: BootState = .idle
    
    let isPreview: Bool
    
    init (inMemory: Bool = false) throws {
        
        isPreview = inMemory
        
        let schema = Schema([
            MuscleGroup.self,
            Exercise.self,
            WorkoutTemplate.self,
            ExerciseTemplate.self,
            SetTemplate.self,
            WorkoutSession.self,
            ExerciseSession.self,
            SetSession.self,
            ActiveSessionMarker.self
        ])
        
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        self.modelContainer = try ModelContainer(for: schema, configurations: [config])
        self.modelContext = ModelContext(modelContainer)
        
        // Repositories
        self.muscleGroupRepository = MuscleGroupRepository(context: modelContext)
        self.exerciseRepository = ExerciseRepository(context: modelContext)
        self.templateRepository = TemplateRepository(context: modelContext)
        self.sessionRepository = SessionRepository(context: modelContext)
        
        // Providers
        self.muscleGroupProvider = MuscleGroupProvider(repo: muscleGroupRepository)
        self.exerciseProvider = ExerciseProvider(repo: exerciseRepository)
        self.templateProvider = TemplateProvider(repo: templateRepository)
        
        
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("ActiveWorkout.json")
        self.sessionDraftStore = SessionDraftStore(url: url)
        self.sessionStarter = SessionStarter(draftStore: sessionDraftStore)
        
        // LookupSources
        self.muscleGroupLookupSource = MuscleGroupLookupSource(provider: muscleGroupProvider)
        self.exerciseLookupSource = ExerciseLookupSource(provider: exerciseProvider)
        self.exerciseMuscleGroupNameLookupSource = ExerciseMuscleGroupNameLookupSource(
            exerciseLookup: exerciseLookupSource,
            muscleGroupLookup: muscleGroupLookupSource
        )
    }
    
    func boot () async {
        guard case .idle = bootState else { return }
        bootState = .booting
        do {
            // MuscleGroup
            try await muscleGroupRepository.boot()
            try await seedDefaultMuscleGroupsIfNeeded()
            await muscleGroupProvider.start()
            
            // Exercise
            try await exerciseRepository.boot()
            try await seedDefaultExercisesIfNeeded()
            await exerciseProvider.boot()
            exerciseLookupSource.boot()
            
            // WorkoutTemplate
            try await templateRepository.boot()
            try await seedDefaultTemplatesIfNeeded()
            await templateProvider.start()
            
            // Session
            _ = await self.sessionDraftStore.load()
            
            bootState = .ready
        }catch {
            print("\(error.localizedDescription)")
            bootState = .failed(error.localizedDescription)
        }
    }
    
    private func seedDefaultMuscleGroupsIfNeeded () async throws {
        let existing = await muscleGroupRepository.snapshotDTOs()
        guard existing.isEmpty else { return }
        
        let defs = MuscleGroupCatalog.defaults
        
        for def in defs {
            _ = try await muscleGroupRepository.create(name: def.name, isPredefined: true)
        }
        
        print("Seeded \(defs.count) default musclegroups")
    }
    
    private func seedDefaultExercisesIfNeeded () async throws {
        let existing = await exerciseRepository.snapshotDTOs()
        guard existing.isEmpty else { return }
        
        let muscleGroups  = await muscleGroupRepository.snapshotDTOs()
        let mgByName = Dictionary(uniqueKeysWithValues: muscleGroups.map { ($0.name, $0.id) })
        
        let defs = isPreview ? ExerciseCatalog.previews : ExerciseCatalog.defaults
        
        for def in defs {
            guard let mgId = mgByName[def.muscleGroup] else {
                print("Muscle group '\(def.muscleGroup)' not found for exercise '\(def.name)' — skipping.")
                continue
            }
            
            _ = try await exerciseRepository.create(name: def.name, muscleGroupID: mgId)
        }
        
        print("Seeded \(defs.count) default exercises.")
    }
    
    private func seedDefaultTemplatesIfNeeded () async throws {
        let existing  = await templateRepository.snapshotDTOs()
        guard existing.isEmpty else {
            return
        }
        
        let muscleGroups = await muscleGroupRepository.snapshotDTOs()
        let exercises = await exerciseRepository.snapshotDTOs()
        
        let mgByName = Dictionary(uniqueKeysWithValues: muscleGroups.map { ($0.name, $0) })
        let exByName = Dictionary(uniqueKeysWithValues: exercises.map { ($0.name, $0) })
        
        let defs = isPreview ? TemplateCatalog.previews : TemplateCatalog.defaults
        
        for def in defs {
            let mgDTOs = def.muscleGroups.compactMap { mgByName[$0] }
            guard !mgDTOs.isEmpty else {
                print("Skipping template '\(def.name)' — missing muscle groups.")
                continue
            }

            let exDTOs = def.exercises.compactMap { exByName[$0] }
            guard !exDTOs.isEmpty else {
                print("Skipping template '\(def.name)' — missing exercises.")
                continue
            }
            
            let exerciseTemplates: [ExerciseTemplateDTO] = exDTOs.enumerated().map { (idx, ex) in
                let setTemplates = (1..<4).map { i in
                    SetTemplateDTO(
                        id: UUID(),
                        order: i,
                        weightTarget: nil,
                        minReps: nil,
                        maxReps: nil,
                        setType: .regular,
                        restTemplate: nil
                    )
                }
                
                return ExerciseTemplateDTO(
                    id: UUID(),
                    exerciseId: ex.id,
                    order: idx,
                    sets: setTemplates,
                    settings: ExerciseSettings.defaultSettings
                )
            }
            
            let dto = WorkoutTemplateDTO(
                id: UUID(),
                version: 0,
                name: def.name,
                muscleGroupsIDs: mgDTOs.map(\.id),
                exerciseTemplates: exerciseTemplates
            )
            
            try await templateRepository.create(dto: dto)
            
            print("Seeded \(defs.count) default templates.")
        }
    }
}
