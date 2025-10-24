import Foundation
import Combine

struct ExercisePickerConfig: Equatable {
    var title: String
    var allowMultiSelect: Bool = true
    var maxSelection: Int? = nil
    var preselected: Set<UUID> = []
    var showSearch: Bool = true
}

@MainActor
final class ExercisePickerStore: ObservableObject {
    @Published var searchText: String = ""
    @Published private(set) var sections: [SectionedByMuscleGroup] = []
    @Published private(set) var selected: Set<UUID>
    
    private let filterStore: ExerciseFilterStore
    private let config: ExercisePickerConfig
    private var bag = Set<AnyCancellable>()
    
    init (
        config: ExercisePickerConfig,
        exerciseProvider: ExerciseProvider,
        muscleGroupProvider: MuscleGroupProvider
    ) {
        self.config = config
        self.filterStore = ExerciseFilterStore(exerciseProvider: exerciseProvider, muscleGroupProvider: muscleGroupProvider)
        self.selected = config.preselected
        
        $searchText
            .removeDuplicates()
            .assign(to: &filterStore.$searchText)
        
        filterStore.$sections
            .removeDuplicates()
            .sink { [weak self] in
                self?.sections = $0
            }
            .store(in: &bag)
    }
    
    func isSelected (_ id: UUID) -> Bool {
        selected.contains(id)
    }
    
    func toggle (_ id: UUID) {
        if isSelected(id) {
            selected.remove(id)
            return
        }
        
        if let max = config.maxSelection, selected.count >= max, !config.allowMultiSelect {
            selected = [id]
            return
        }
        
        if let max = config.maxSelection, selected.count >= max { return }
        if !config.allowMultiSelect {
            selected = [id]
            return
        }
        
        selected.insert(id)
    }
    
    func selectAll (in section: SectionedByMuscleGroup) {
        guard config.allowMultiSelect else { return }
        let ids = section.items.map(\.id)
        if let max = config.maxSelection {
            let remaining = max - selected.count
            guard remaining > 0 else { return }
            selected.formUnion(ids.prefix(remaining))
        }else {
            selected.formUnion(ids)
        }
    }
    
    func clearAll () {
        selected.removeAll()
    }
    
    var selectionValid: Bool {
        selected.count > 0
    }
    
    var selectionCount: Int {
        selected.count
    }
}
