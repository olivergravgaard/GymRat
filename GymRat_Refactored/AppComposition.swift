import SwiftUI
import SwiftData
import Combine
import FirebaseAuth

@MainActor
final class AppComposition: ObservableObject {
    enum BootState: Equatable {
        case idle, booting, ready
        case failed(String)
    }
    
    let schema: Schema
    
    let modelContainer: ModelContainer
    let modelContext: ModelContext
    
    private var cancellables = Set<AnyCancellable>()
    private var lastUserId: String?
    
    // User required stores
    let authStore: AuthStore
    let profileStore: ProfileStore
    
    // Repositories
    let muscleGroupRepository: MuscleGroupRepository
    let exerciseRepository: ExerciseRepository
    let templateRepository: TemplateRepository
    let sessionRepository: SessionRepository
    
    // Providers
    let muscleGroupProvider: MuscleGroupProvider
    let exerciseProvider: ExerciseProvider
    let templateProvider: TemplateProvider
    let sessionProvider: SessionProvider
    let sessionDraftStore: SessionDraftStore
    let sessionStarter: SessionStarter
    
    // Services
    let exerciseSyncService: ExerciseSyncService
    let workoutTemplateSyncService: WorkoutTemplateSyncService
    
    // Lookup Sources
    let muscleGroupLookupSource: MuscleGroupLookupSource
    let exerciseLookupSource: ExerciseLookupSource
    let exerciseMuscleGroupNameLookupSource: ExerciseMuscleGroupNameLookupSource
    
    @Published private(set) var bootState: BootState = .idle
    
    let isPreview: Bool
    
    init (inMemory: Bool = false) throws {
        
        isPreview = inMemory
        
        self.schema = Schema([
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
        
        // User required stores
        self.authStore = AuthStore()
        self.profileStore = ProfileStore(authStore: authStore)
        
        // Repositories
        self.muscleGroupRepository = MuscleGroupRepository(context: modelContext)
        self.exerciseRepository = ExerciseRepository(context: modelContext)
        self.templateRepository = TemplateRepository(context: modelContext)
        self.sessionRepository = SessionRepository(context: modelContext)
        
        // Providers
        self.muscleGroupProvider = MuscleGroupProvider(repo: muscleGroupRepository)
        self.exerciseProvider = ExerciseProvider(repo: exerciseRepository)
        self.templateProvider = TemplateProvider(repo: templateRepository)
        self.sessionProvider = SessionProvider(repo: sessionRepository)
        
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("ActiveWorkout.json")
        self.sessionDraftStore = SessionDraftStore(url: url)
        self.sessionStarter = SessionStarter(draftStore: sessionDraftStore)
        
        // Services
        self.exerciseSyncService = ExerciseSyncService(exerciseRepository: exerciseRepository, muscleGroupRepository: muscleGroupRepository)
        self.workoutTemplateSyncService = WorkoutTemplateSyncService(workoutTemplateRepo: templateRepository)
        
        // LookupSources
        self.muscleGroupLookupSource = MuscleGroupLookupSource(provider: muscleGroupProvider)
        self.exerciseLookupSource = ExerciseLookupSource(provider: exerciseProvider)
        self.exerciseMuscleGroupNameLookupSource = ExerciseMuscleGroupNameLookupSource(
            exerciseLookup: exerciseLookupSource,
            muscleGroupLookup: muscleGroupLookupSource
        )
        
        authStore.$user
            .map { $0?.uid }
            .removeDuplicates()
            .sink { [weak self] newUserId in
                guard let self else { return }
                
                Task { @MainActor in
                    await self.handleAuthUserChange(newUserId: newUserId)
                }
            }
            .store(in: &cancellables)
    }
    
    func boot () async {
        guard bootState == .idle else { return }
        bootState = .booting
        do {
            // MuscleGroup
            try await muscleGroupRepository.boot()
            try await seedBuiltinMuscleGroupsIfNeeded()
            await muscleGroupProvider.start()
            
            // Exercise
            try await exerciseRepository.boot()
            try await seedBuiltinExercisesIfNeeded()
            await exerciseProvider.boot()
            exerciseLookupSource.boot()
            
            // WorkoutTemplate
            try await templateRepository.boot()
            //try await seedDefaultTemplatesIfNeeded()
            await templateProvider.start()
            
            // Session
            _ = await self.sessionDraftStore.load()
            try await sessionRepository.boot()
            await sessionProvider.boot()
            
            await authStore.validateSessionIfNeeded()
            
            bootState = .ready
        }catch {
            print("ERROR APPCOMP BOOT: \(error.localizedDescription)")
            bootState = .failed(error.localizedDescription)
        }
    }
    
    func clearLocalData () {
        
        
        do {
            try deleteAll(Exercise.self)
            try deleteAll(WorkoutTemplate.self)
            try deleteAll(ExerciseTemplate.self)
            try deleteAll(SetTemplate.self)
            try deleteAll(WorkoutSession.self)
            try deleteAll(ExerciseSession.self)
            try deleteAll(SetSession.self)
            try deleteAll(ActiveSessionMarker.self)
            
            try modelContext.save()
            
            print("APPCOMP CLEARLOCALDATA: Success")
            
            bootState = .idle
        }catch {
            print("APPCOMP CLEARLOCALDATA: Failed trying to clear all data: \(error.localizedDescription)")
        }
    }
    
    private func handleAuthUserChange (newUserId: String?) async {
        let old = lastUserId
        let new = newUserId
        lastUserId = new
        
        if old != nil, new == nil {
            cancelSyncTasks()
            clearLocalData()
            resetRepositories()
            return
        }
        
        if old == nil, let uid = new {
            if bootState != .ready {
                await boot()
            }
            
            await runInitialSync(userId: uid)
        }
        
        if let old, let new, old != new {
            cancelSyncTasks()
            clearLocalData()
            resetRepositories()
            
            if bootState != .ready {
                await boot()
            }
            
            await runInitialSync(userId: new)
        }
    }
    
    private func deleteAll<T: PersistentModel>(_ type: T.Type) throws {
        let descriptor = FetchDescriptor<T>()
        let all = try modelContext.fetch(descriptor)
        all.forEach {
            modelContext.delete($0)
        }
    }
    
    func resetRepositories () {
        muscleGroupRepository.reset()
        exerciseRepository.reset()
        templateRepository.reset()
        sessionRepository.reset()
    }
    
    func cancelSyncTasks () {
        exerciseSyncService.cancelPendingSync()
        workoutTemplateSyncService.cancelPendingSync()
    }
    
    func runInitialSync(userId: String) async {
        do {
            try await exerciseSyncService.pullRemote(userId: userId)
            try await workoutTemplateSyncService.pullRemote(userId: userId)
        }catch {
            print("AppComposition: runInitialSync - failed to sync with database: \(error.localizedDescription)")
        }
    }
    
    private func seedBuiltinMuscleGroupsIfNeeded () async throws {
        let existing = await muscleGroupRepository.snapshotDTOs()
        guard existing.isEmpty else { return }
        
        let builtins = MuscleGroupCatalog.builtins
        
        for builtin in builtins {
            _ = try await muscleGroupRepository.create(
                id: builtin.id,
                name: builtin.name,
                isBuiltin: true
            )
        }
        
        print("Seeded \(builtins.count) default musclegroups")
    }
    
    private func seedBuiltinExercisesIfNeeded () async throws {
        let muscleGroups = await muscleGroupRepository.snapshotDTOs()
        let muscleGroupIDs = muscleGroups.map(\.id)
        
        let builtins = isPreview ? ExerciseCatalog.previews : ExerciseCatalog.builtins
        
        let existing = await exerciseRepository.getDTOs()
        
        var createdCount = 0
        var updatedCount = 0
        
        for builtin in builtins {
            guard let muscleGroupID = muscleGroupIDs.first(where: { $0 == builtin.muscleGroupID}) else {
                print("Muscle Group '\(builtin.muscleGroupID)' not found for exercise '\(builtin.name)' - skipping")
                continue
            }
            
            if let existingDTO = existing.first(where: { $0.id == builtin.id}) {
                if existingDTO.muscleGroupID != muscleGroupID {
                    try await exerciseRepository.changeMuscleGroup(id: existingDTO.id, to: muscleGroupID)
                    updatedCount += 1
                }
                
                if existingDTO.name != builtin.name {
                    try await exerciseRepository.rename(id: existingDTO.id, to: builtin.name)
                    updatedCount += 1
                }
                
                continue
            }else {
                print("Creating exercise")
                try await exerciseRepository
                    .create(
                        id: builtin.id,
                        name: builtin.name,
                        muscleGroupID: builtin.muscleGroupID,
                        origin: .builtin,
                        ownerId: nil
                    )
                createdCount += 1
            }
        }
        
        print("Exercise seeding: created \(createdCount), updated \(updatedCount)")
    }
    
    /*private func seedDefaultTemplatesIfNeeded () async throws {
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
                    settings: ExerciseSettings.defaultSettings,
                    notes: []
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
    }*/
}
