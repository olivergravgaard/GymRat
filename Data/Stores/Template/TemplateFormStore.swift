import SwiftUI
import Combine

enum TemplateFormMode: Equatable {
    case create
    case edit(template: WorkoutTemplateDTO)
}

@MainActor
final class TemplateFormStore: ObservableObject {
    enum NameStatus: Equatable {
        case idle, checking, valid
        case invalid(String)
    }

    // Inputs
    @Published var name: String = ""
    @Published var selectedMuscleGroups: [MuscleGroupDTO] = []

    // Outputs
    @Published private(set) var nameStatus: NameStatus = .idle
    @Published private(set) var muscleGroups: [MuscleGroupDTO] = []
    @Published private(set) var isSaving: Bool = false

    // Deps
    private let templateProvider: TemplateProvider
    private let muscleGroupProvider: MuscleGroupProvider
    private let mode: TemplateFormMode

    // Internals
    private var cancellables = Set<AnyCancellable>()
    private var validateTask: Task<Void, Never>?
    private var groupsTask: Task<Void, Never>?
    private var templatesTask: Task<Void, Never>?

    private var initialSelectedMuscleGroupsIds: [UUID] = []
    private var normalizedExistingNames: Set<String> = []

    init(
        mode: TemplateFormMode,
        templateProvider: TemplateProvider,
        muscleGroupProvider: MuscleGroupProvider
    ) {
        self.mode = mode
        self.templateProvider = templateProvider
        self.muscleGroupProvider = muscleGroupProvider

        if case .edit(let template) = mode {
            self.name = template.name
            self.initialSelectedMuscleGroupsIds = template.muscleGroupsIDs
        }

        bindNameValidation()
        subscribeTemplates()
        subscribeMuscleGroups()
    }

    private func subscribeTemplates() {
        templatesTask = Task { [weak self] in
            guard let self else { return }
            await templateProvider.start()
            for await list in await templateProvider.streamAll() {
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
                
                if selectedMuscleGroups.isEmpty {
                    selectedMuscleGroups = self.muscleGroups.filter {
                        self.initialSelectedMuscleGroupsIds.contains($0.id)
                    }
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

        if case .edit(let template) = mode,
           Self.normalize(template.name) == Self.normalize(trimmed) {
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
        if case .valid = nameStatus, selectedMuscleGroups.isEmpty == false, !isSaving { return true }
        return false
    }

    func save() async {
        guard canSave, selectedMuscleGroups.isEmpty == false else { return }
        isSaving = true
        defer { isSaving = false }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            switch mode {
            case .create:
                _ = try await templateProvider.create(name: trimmed, muscleGroupsIDs: selectedMuscleGroups.map { $0.id })
                name = ""
                selectedMuscleGroups.removeAll()
                nameStatus = .idle

            case .edit(let template):
                if trimmed != template.name {
                    try await templateProvider.rename(id: template.id, to: trimmed)
                }
                
                let originalMuscleGroups = Set(template.muscleGroupsIDs)
                let updatedMuscleGroups = Set(selectedMuscleGroups.map(\.id))
                
                if originalMuscleGroups != updatedMuscleGroups {
                    try await templateProvider.changeMuscleGroups(id: template.id, to: Array(updatedMuscleGroups))
                }
                
                nameStatus = .idle
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
        templatesTask?.cancel()
    }
}
