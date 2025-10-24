import Foundation
import Combine

@MainActor
final class ExerciseLookupSource: ObservableObject {
    @Published private(set) var names: [UUID: String] = [:]
    private let impl: EntityLookupSource<String>
    
    init (provider: ExerciseProvider) {
        self.impl = .init(
            mapStream: {
                await provider.byIdMapStream()
            },
            project: { DTO in
                DTO.name
            }
        )
        self.impl.$values.assign(to: &self.$names)
    }
    
    func name (for id: UUID) -> String {
        return names[id] ?? "Unknown"
    }
}
