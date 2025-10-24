import Foundation
import Combine
import SwiftUI

@MainActor
final class SessionRibbonStore: ObservableObject {
    @Published var active: WorkoutSessionDTO?
    
    private let draftStore: SessionDraftStore
    private var task: Task<Void, Never>?
    
    init (draftStore: SessionDraftStore) {
        self.draftStore = draftStore
    }
    
    func start () {
        stop()
        task = Task {
            let initial = await draftStore.load()
            
            await MainActor.run {
                self.active = initial
            }
            
            for await dto in await draftStore.stream() {
                await MainActor.run {
                    self.active = dto
                }
            }
        }
    }
    
    func stop () {
        task?.cancel()
    }
}

struct SessionRibbonView: View {
    @EnvironmentObject var comp: AppComposition
    @ObservedObject var store: SessionRibbonStore

    var onOpen: @MainActor () async -> Void

    var body: some View {
        if let active = store.active {
            Button {
                Task {
                    await onOpen()
                }
            } label: {
                HStack (spacing: 8) {
                    HStack (spacing: 8) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(.vertical, 8)
                            .foregroundStyle(.indigo)
                        
                        Text(active.name)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.indigo)
                            .lineLimit(1)
                    }
                    
                    ElapsedTimeLabel(startedAt: active.startedAt)
                        .foregroundStyle(.indigo)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Text("\(performedSetsCount(active)) / \(totalSetsCount(active)) sets")
                        .foregroundStyle(.indigo)
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .frame(height: 32)
                .padding(.horizontal)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.indigo, lineWidth: 1)
                }
                .glassEffect(.regular.interactive(true), in: .rect(cornerRadius: 12))
                .frame(maxWidth: .infinity, alignment: .center)
            }

        }
    }

    private func totalSetsCount(_ s: WorkoutSessionDTO) -> Int {
        s.exercises.reduce(0) { $0 + $1.sets.count }
    }

    private func performedSetsCount(_ s: WorkoutSessionDTO) -> Int {
        s.exercises.flatMap(\.sets).reduce(into: 0) { $0 += ($1.performed == true) ? 1 : 0 }
    }
}
