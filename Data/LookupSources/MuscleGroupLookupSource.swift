import Foundation
import Combine

@MainActor
final class MuscleGroupLookupSource: ObservableObject {
    @Published private(set) var infos: [UUID: MuscleGroupInfo] = [:]
    private let impl: EntityLookupSource<MuscleGroupInfo>
    
    init (provider: MuscleGroupProvider) {
        self.impl = .init(
            mapStream: {
                await provider.byIdMapStream()
            },
            project: { DTO in
                MuscleGroupInfo(
                    name: DTO.name
                )
            }
        )
        self.impl.$values.assign(to: &self.$infos)
    }
    
    func info (for id: UUID) -> MuscleGroupInfo? {
        infos[id]
    }
    
    func name (for id: UUID) -> String {
        infos[id]?.name ?? "Unknown"
    }
}
