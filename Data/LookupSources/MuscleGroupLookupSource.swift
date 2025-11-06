import Foundation
import Combine

@MainActor
final class MuscleGroupLookupSource: ObservableObject {
    @Published private(set) var names: [UUID: String] = [:]
    private let impl: EntityLookupSource<String>
    
    init (provider: MuscleGroupProvider) {
        self.impl = .init(
            mapStream: {
                await provider.byIdMapStream()
            },
            project: {
                $0.name
            }
        )
        self.impl.$values.assign(to: &self.$names)
    }
    
    func name (for id: UUID) -> String {
        names[id] ?? "Unknown"
    }
}
