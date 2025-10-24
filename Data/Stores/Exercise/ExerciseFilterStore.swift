import Foundation
import Combine

struct SectionedByMuscleGroup: Identifiable, Equatable {
    let id: UUID
    let title: String
    let items: [ExerciseDTO]
}

@MainActor
final class ExerciseFilterStore: ObservableObject {
    @Published var searchText: String = ""

    @Published private(set) var sections: [SectionedByMuscleGroup] = []
    @Published private(set) var muscleGroupNamesById: [UUID: String] = [:]
    @Published private(set) var allExercises: [ExerciseDTO] = []

    private let exerciseProvider: ExerciseProvider
    private let muscleGroupProvider: MuscleGroupProvider
    private var cancellables = Set<AnyCancellable>()
    private var taskExercises: Task<Void, Never>?
    private var taskMuscleGroups: Task<Void, Never>?

    private let worker = DispatchQueue(label: "ExerciseFilterStore.worker", qos: .userInitiated)

    init(exerciseProvider: ExerciseProvider,
         muscleGroupProvider: MuscleGroupProvider)
    {
        self.exerciseProvider = exerciseProvider
        self.muscleGroupProvider = muscleGroupProvider
        subscribeProviders()
        setupPipeline()
    }

    deinit {
        taskExercises?.cancel()
        taskMuscleGroups?.cancel()
    }

    private func subscribeProviders() {
        taskExercises = Task { [weak self] in
            guard let self else { return }
            await exerciseProvider.start()
            for await list in await exerciseProvider.streamAll() {
                self.allExercises = list
            }
        }

        taskMuscleGroups = Task { [weak self] in
            guard let self else { return }
            for await map in await muscleGroupProvider.byIdMapStream() {
                self.muscleGroupNamesById = map.reduce(into: [:]) { $0[$1.key] = $1.value.name }
            }
        }
    }

    private func setupPipeline() {
        Publishers.CombineLatest3(
            $searchText
                .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .removeDuplicates(),
            $allExercises
                .removeDuplicates(by: Self.sameIDsAndVersion),
            $muscleGroupNamesById
                .removeDuplicates(by: Self.sameNameMap)
        )
        .receive(on: worker)
        .map { (search, all, nameMap) -> [SectionedByMuscleGroup] in
            let filtered = Self.applyFilters(search: search, all: all)
            return Self.groupAndSort(filtered: filtered, nameMap: nameMap)
        }
        .receive(on: RunLoop.main)
        .removeDuplicates(by: Self.sameSectionsByVersion)
        .sink { [weak self] output in
            self?.sections = output
        }
        .store(in: &cancellables)
    }

    nonisolated private static func applyFilters (search: String, all: [ExerciseDTO]) -> [ExerciseDTO] {
        let filtered: [ExerciseDTO] = search.isEmpty ? all : all.filter { $0.name.localizedCaseInsensitiveContains(search) }

        return filtered.sorted {
            let cmp = $0.name.localizedCaseInsensitiveCompare($1.name)
            if cmp == .orderedSame { return $0.id.uuidString < $1.id.uuidString }
            return cmp == .orderedAscending
        }
    }
    
    nonisolated private static func groupAndSort (
        filtered: [ExerciseDTO],
        nameMap: [UUID: String]
    ) -> [SectionedByMuscleGroup] {
        var buckets: [UUID: [ExerciseDTO]] = [:]
        
        for exercise in filtered {
            buckets[exercise.muscleGroupID, default: []].append(exercise)
        }
        
        var sections: [SectionedByMuscleGroup] = []
        sections.reserveCapacity(buckets.count)
        
        for (muscleGroupId, exercises) in buckets {
            let title = nameMap[muscleGroupId] ?? "Unknown"
            let sortedExercises = exercises.sorted {
                let cmp = $0.name.localizedCaseInsensitiveCompare($1.name)
                if cmp == .orderedSame { return $0.id.uuidString < $1.id.uuidString }
                return cmp == .orderedAscending
            }
            sections.append(.init(id: muscleGroupId, title: title, items: sortedExercises))
        }
        
        sections.sort {
            let cmp = $0.title.localizedCaseInsensitiveCompare($1.title)
            if cmp == .orderedSame { return $0.id.uuidString < $1.id.uuidString }
            return cmp == .orderedAscending
        }
        
        return sections
    }

    nonisolated private static func sameIDsAndVersion(lhs: [ExerciseDTO], rhs: [ExerciseDTO]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).allSatisfy { $0.id == $1.id && $0.version == $1.version }
    }
    
    nonisolated private static func sameNameMap (_ lhs: [UUID: String], _ rhs: [UUID: String]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        
        for (k, v) in lhs {
            if rhs[k] != v {
                return false
            }
        }
        return true
    }
    
    nonisolated private static func sameSectionsByVersion(_ lhs: [SectionedByMuscleGroup], _ rhs: [SectionedByMuscleGroup]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for (ls, rs) in zip(lhs, rhs) {
            if ls.id != rs.id || ls.title != rs.title { return false }
            guard ls.items.count == rs.items.count else { return false }
            for (li, ri) in zip(ls.items, rs.items) {
                if li.id != ri.id || li.version != ri.version { return false }
            }
        }
        
        return true
    }
}
