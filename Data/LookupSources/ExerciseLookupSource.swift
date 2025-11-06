import Foundation
import Combine

@MainActor
final class ExerciseLookupSource: ObservableObject {
    
    let provider: ExerciseProvider
    
    @Published private(set) var names: [UUID: String] = [:]
    @Published private(set) var muscleGroupIDs: [UUID: UUID] = [:]
    
    private var task: Task<Void, Never>?
    
    init (provider: ExerciseProvider) {
        self.provider = provider
    }
    
    deinit {
        task?.cancel()
    }
    
    func boot () {
        guard task == nil else { return }
        
        task = Task { [weak self] in
            guard let self else { return }
            
            await provider.boot()
            
            for await map in await provider.byIdMapStream() {
                var names: [UUID: String] = [:]
                var muscleGroupIDs: [UUID: UUID] = [:]
                
                for dto in map.values {
                    names[dto.id] = dto.name
                    muscleGroupIDs[dto.id] = dto.muscleGroupID
                }
                
                await MainActor.run {
                    self.names = names
                    self.muscleGroupIDs = muscleGroupIDs
                }
            }
        }
    }
    
    func name (for id: UUID) -> String {
        names[id] ?? "unknown"
    }
    
    func muscleGroupId (for exerciseId: UUID) -> UUID? {
        muscleGroupIDs[exerciseId]
    }
    
    func publisherForMuscleGroupIDMap () -> AnyPublisher<[UUID: UUID], Never> {
        $muscleGroupIDs.eraseToAnyPublisher()
    }
    
    func muscleGroupIdPublisher (for exerciseId: UUID) -> AnyPublisher<UUID?, Never> {
        $muscleGroupIDs.map { $0[exerciseId] }.eraseToAnyPublisher()
    }
}
