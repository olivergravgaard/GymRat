import Combine
import Foundation

@MainActor
final class EntityLookupSource<Value>: ObservableObject {
    @Published private(set) var values: [UUID: Value] = [:]
    private var task: Task<Void, Never>?
    
    init<DTO>(
        mapStream: @escaping () async -> AsyncStream<[UUID: DTO]>,
        project: @escaping (DTO) -> Value
    ) {
        task = Task { [weak self] in
            guard let self else { return }
            for await map in await mapStream() {
                var next: [UUID: Value] = [:]
                next.reserveCapacity(map.count)
                for (id, dto) in map {
                    next[id] = project(dto)
                }
                self.values = next
            }
        }
    }
    
    deinit {
        task?.cancel()
    }
    
    func value (for id: UUID) -> Value? { values[id] }
    subscript(id: UUID) -> Value? { values[id] }
    
    func publisher (for id: UUID) -> AnyPublisher<Value?, Never> {
        $values.map { $0[id] }.eraseToAnyPublisher()
    }
}
