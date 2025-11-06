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
    
    private var progress: CGFloat {
        guard let active = store.active else { return 0 }
        return CGFloat(active.performedSetsCount()) / CGFloat(active.totalSetsCount())
    }

    var body: some View {
        if let active = store.active {
            Button {
                Task {
                    await onOpen()
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.indigo.opacity(0.15))
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.indigo)
                    }
                    .frame(width: 44, height: 44)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(active.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.black)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.caption2.weight(.semibold))
                                ElapsedTimeLabel(startedAt: active.startedAt)
                            }
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.gray)
                        }
                        
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.indigo.opacity(0.15))
                                .frame(height: 8)
                            GeometryReader { geo in
                                Capsule()
                                    .fill(.indigo)
                                    .frame(width: max(8, geo.size.width * progress), height: 8)
                                    .animation(.snappy(duration: 0.25, extraBounce: 0), value: progress)
                            }
                            .frame(height: 8)
                        }
                        
                        HStack {
                            Text("\(active.performedSetsCount()) / \(active.totalSetsCount()) sets")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.indigo)
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(red: 0.937, green: 0.937, blue: 0.937))
                }
                .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
                .contentShape(.rect)

            }
            .contentShape(.rect)
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
            
        }
    }
}
