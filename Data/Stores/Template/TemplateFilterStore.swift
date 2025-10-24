import Foundation
import Combine

@MainActor
final class TemplateFilterStore: ObservableObject {
    @Published var searchText: String = ""
    @Published private(set) var filteredTemplates: [WorkoutTemplateDTO] = []
    @Published private(set) var allTemplates: [WorkoutTemplateDTO] = []
    
    private let templateProvider: TemplateProvider
    private var cancellabes = Set<AnyCancellable>()
    private var taskTemplates: Task<Void, Never>?

    private let worker = DispatchQueue(label: "TemplateFilterStore.worker", qos: .userInitiated)
    
    init (templateProvider: TemplateProvider) {
        self.templateProvider = templateProvider
        subscribeProviders()
        setupPipeline()
    }
    
    deinit {
        taskTemplates?.cancel()
    }
    
    private func subscribeProviders() {
        taskTemplates = Task { [weak self] in
            guard let self else { return }
            await templateProvider.start()
            for await list in await templateProvider.streamAll() {
                self.allTemplates = list
            }
        }
    }
    
    private func setupPipeline () {
        Publishers.CombineLatest(
            $searchText
                .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .removeDuplicates(),
            
            $allTemplates
                .removeDuplicates(by: Self.sameIDsAndVersion)
        )
        .receive(on: worker)
        .map { (search, all) -> [WorkoutTemplateDTO] in
            return Self.applyFilters(search: search, all: all)
        }
        .receive(on: RunLoop.main)
        .removeDuplicates(by: Self.sameIDsAndVersion)
        .sink { [weak self] filtered in
            self?.filteredTemplates = filtered
        }
        .store(in: &cancellabes)
    }
    
    nonisolated private static func applyFilters(search: String, all: [WorkoutTemplateDTO]) -> [WorkoutTemplateDTO] {
        let filtered: [WorkoutTemplateDTO]
        if search.isEmpty {
            filtered = all
        } else {
            filtered = all.filter { $0.name.localizedCaseInsensitiveContains(search) }
        }

        return filtered.sorted {
            let cmp = $0.name.localizedCaseInsensitiveCompare($1.name)
            
            if cmp == .orderedSame {
                return $0.id.uuidString < $1.id.uuidString
            }
            
            return cmp == .orderedAscending
        }
    }
    
    nonisolated private static func sameIDsAndVersion (_ lhs: [WorkoutTemplateDTO], _ rhs: [WorkoutTemplateDTO]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).allSatisfy { $0.id == $1.id && $0.version == $1.version }
    }
}
