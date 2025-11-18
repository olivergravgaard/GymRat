import SwiftUI
import Foundation

struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        
    }
}

struct HistoryView: View {
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appComp: AppComposition
    @EnvironmentObject var tabbarVisibility: TabBarVisibility
    
    @StateObject var allWorkoutSessionsStore: AllWorkoutSessionsStore
    
    @State private var path = NavigationPath()
    
    let testHost: FocusOnlyHost = .init()
    
    init (sessionProvider: SessionProvider) {
        self._allWorkoutSessionsStore = StateObject(wrappedValue: .init(sessionProvider: sessionProvider))
    }
    
    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.vertical) {
                LazyVStack (spacing: 24) {
                    ForEach(allWorkoutSessionsStore.groupedWorkoutSessions) { monthSection in
                        groupedByMonthSection(monthSection, scrollProxy: scrollProxy)
                    }
                }
            }
            .onAppear {
                tabbarVisibility.hide()
            }
            .onDisappear {
                tabbarVisibility.show()
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(
                edge: .top,
                content: {
                    HStack {
                        DismissButton {
                            dismiss()
                        }
                        
                        Spacer(minLength: 8)
                        
                        Text("History")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
                    .padding()
                    .fadedBackground(direction: .topToBottom, ignoreEdgeSet: [.top], fadeStart: 0.5)

            })
            .safeAreaInset(edge: .bottom, alignment: .center) {
                SearchField(placeholder: "Search for session...", input: $allWorkoutSessionsStore.searchText)
                    .padding(.horizontal)
                    .padding(.top, 55)
                    .fadedBackground(direction: .bottomToTop, ignoreEdgeSet: [.bottom], fadeStart: 0.1)
            }
        }
    }
    
    @ViewBuilder
    func groupedByMonthSection (_ monthSection: MonthSection, scrollProxy: ScrollViewProxy) -> some View {
        VStack (alignment: .leading, spacing: 12) {
            Text(monthSection.title)
                .font(.title)
                .fontWeight(.semibold)
            
            VStack (spacing: 16) {
                ForEach(monthSection.workoutSessions, id: \.id) { workoutSession in
                    MorphMenuView(
                        numpadHost: testHost ,
                        config: .init(
                            alignment: .center,
                            cornerRadius: 16,
                            extraBounce: 0
                        ), scrollProxy: .init(proxy: scrollProxy, anchor: .center)) {
                            NavigationLink {
                                ReviewWorkoutSessionView(workoutSession: workoutSession)
                            } label: {
                                workoutCard(workoutSession)
                                    .id(workoutSession.id)
                            }
                        } menu: { close in
                            VStack  {
                                Button {
                                    close {
                                        do {
                                            try appComp.sessionRepository.delete(id: workoutSession.id)
                                        }catch {
                                            print(error.localizedDescription)
                                        }
                                    }
                                } label: {
                                    Text("Delete")
                                }
                                .buttonStyle(.plain)

                            }
                            .frame(width: 200, height: 200)
                        }
                }
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    func workoutCard (_ workoutSession: WorkoutSessionDTO) -> some View {
        VStack (alignment: .leading, spacing: 8) {
            Text("\(formatDate(workoutSession.endedAt ?? .now))")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.black)
                .padding(.leading, 8)
            
            HStack (alignment: .center, spacing: 12) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.indigo)
                    .frame(width: 28)
                    .compositingGroup()
                    .frame(width: 55)
                    .frame(height: 55)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.indigo.opacity(0.2))
                    }
                
                VStack (alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(workoutSession.name)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .foregroundStyle(.black)
                        
                        Spacer(minLength: 0)
                        
                        HStack (alignment: .center, spacing: 4) {
                            Image(systemName: "clock.fill")
                            Text("\(formatTime(workoutSession.duration))")
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.gray)
                    }
                    
                    Text("\(workoutSession.exercises.count) exercises / \(workoutSession.totalSetsCount) sets")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                    
                    ScrollView (.horizontal) {
                        HStack (spacing: 8) {
                            ForEach(workoutSession.muscleGroupIDs, id: \.self) { muscleGroupId in
                                Text("\(appComp.muscleGroupLookupSource.name(for: muscleGroupId))")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.indigo)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background {
                                        Capsule()
                                            .fill(.indigo.opacity(0.2))
                                    }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.95, green: 0.95, blue: 0.97).opacity(1))
            }
            .compositingGroup()
            .shadow(color: .black.opacity(0.1), radius: 2, y: 2)
            .swipeToTrigger(
                leftSwipeConfig: .init(
                    direction: .left,
                    isDeletion: true,
                    threshold: 0.6,
                    backgroundColor: .red.opacity(0.2),
                    actionView: {
                        Image(systemName: "trash")
                    },
                    onTrigger: {
                        do {
                            try appComp.sessionRepository.delete(id: workoutSession.id)
                        }catch {
                            print(error.localizedDescription)
                        }
                    }
                ),
                rightSwipeConfig: nil,
                occupiesFullWidth: true
            )
        }
    }
}
