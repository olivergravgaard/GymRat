import SwiftUI
import Combine

enum ExerciseFormMode: Equatable {
    case create
    case edit(exercise: ExerciseDTO)
}

@MainActor
final class ExerciseFormStore: ObservableObject {
    enum NameStatus: Equatable {
        case idle, checking, valid
        case invalid(String)
    }

    // Inputs
    @Published var name: String = ""
    @Published var selectedMuscleGroup: MuscleGroupDTO?

    // Outputs
    @Published private(set) var nameStatus: NameStatus = .idle
    @Published private(set) var muscleGroups: [MuscleGroupDTO] = []
    @Published private(set) var isSaving: Bool = false

    // Deps
    private let exerciseProvider: ExerciseProvider
    private let muscleGroupProvider: MuscleGroupProvider
    private let mode: ExerciseFormMode

    // Internals
    private var cancellables = Set<AnyCancellable>()
    private var validateTask: Task<Void, Never>?
    private var groupsTask: Task<Void, Never>?
    private var exercisesTask: Task<Void, Never>?

    private var initialSelectedMuscleGroupId: UUID?
    private var normalizedExistingNames: Set<String> = []

    init(
        mode: ExerciseFormMode,
        exerciseProvider: ExerciseProvider,
        muscleGroupProvider: MuscleGroupProvider
    ) {
        self.mode = mode
        self.exerciseProvider = exerciseProvider
        self.muscleGroupProvider = muscleGroupProvider

        if case .edit(let exercise) = mode {
            self.name = exercise.name
            self.initialSelectedMuscleGroupId = exercise.muscleGroupID
        }

        bindNameValidation()
        subscribeExercises()
        subscribeMuscleGroups()
    }

    private func subscribeExercises() {
        exercisesTask = Task { [weak self] in
            guard let self else { return }
            await exerciseProvider.boot()
            for await list in await exerciseProvider.streamAll() {
                self.normalizedExistingNames = Set(list.map { Self.normalize($0.name) })
            }
        }
    }

    private func subscribeMuscleGroups() {
        groupsTask = Task { [weak self] in
            guard let self else { return }
            for await list in await muscleGroupProvider.streamAll() {
                self.muscleGroups = list.sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                
                if let want = self.initialSelectedMuscleGroupId, self.selectedMuscleGroup == nil {
                    self.selectedMuscleGroup = self.muscleGroups.first { $0.id == want }
                }
            }
        }
    }

    private func bindNameValidation() {
        $name
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .removeDuplicates()
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] trimmed in
                guard let self else { return }
                self.validateTask?.cancel()
                self.validateTask = Task { [weak self] in
                    await self?.validateName(trimmed)
                }
            }
            .store(in: &cancellables)
    }

    private func validateName(_ trimmed: String) async {
        guard !trimmed.isEmpty else { nameStatus = .idle; return }
        guard trimmed.count >= 2 else { nameStatus = .invalid("Name too short"); return }

        if case .edit(let exercise) = mode,
           Self.normalize(exercise.name) == Self.normalize(trimmed) {
            nameStatus = .valid
            return
        }

        if normalizedExistingNames.contains(Self.normalize(trimmed)) {
            nameStatus = .invalid("Name already exists")
            return
        }

        nameStatus = .valid
    }
    
    var canSave: Bool {
        if case .valid = nameStatus, selectedMuscleGroup != nil, !isSaving { return true }
        return false
    }

    func save() async {
        guard canSave, let mg = selectedMuscleGroup else { return }
        isSaving = true
        defer { isSaving = false }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            switch mode {
            case .create:
                _ = try await exerciseProvider.create(name: trimmed, muscleGroupID: mg.id)
                name = ""
                selectedMuscleGroup = nil
                nameStatus = .idle

            case .edit(let exercise):
                if trimmed != exercise.name {
                    try await exerciseProvider.rename(id: exercise.id, to: trimmed)
                }
                
                if mg.id != exercise.muscleGroupID {
                    try await exerciseProvider.changeMuscleGroup(id: exercise.id, to: mg.id)
                }
                
                nameStatus = .idle
                
                print("Done editingee")
            }
        } catch {
            nameStatus = .invalid(error.localizedDescription)
        }
    }

    nonisolated private static func normalize(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
         .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    deinit {
        validateTask?.cancel()
        groupsTask?.cancel()
        exercisesTask?.cancel()
    }
}
