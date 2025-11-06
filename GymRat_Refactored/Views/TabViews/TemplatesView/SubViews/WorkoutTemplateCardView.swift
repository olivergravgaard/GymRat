import SwiftUI

struct WorkoutTemplateCardView: View {
    @EnvironmentObject var appComp: AppComposition
    
    let numpadHost: FocusOnlyHost
    let proxy: ScrollViewProxy
    let workoutTemplate: WorkoutTemplateDTO
    let onEdit: () -> Void
    let onStart: () -> Void
    
    var estimatedDuration: String {
        formatTime(workoutTemplate.estimatedDuration())
    }
    
    @State private var swipeProgress: CGFloat = 0
    
    var body: some View {
        MorphMenuView(
            numpadHost: numpadHost,
            config: .init(
                alignment: .center,
                cornerRadius: 12,
                extraBounce: 0,
                animation: .smooth(duration: 0.5)
            ),
            proxy: proxy
        ) {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.indigo.opacity(0.15))
                        .frame(width: 44)
                        .frame(maxHeight: .infinity)
                        .overlay(
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.title3)
                                .foregroundColor(.indigo)
                        )
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text(workoutTemplate.name)
                                .font(.headline)
                                .foregroundStyle(.black)
                            
                            Spacer()
                            
                            HStack (spacing: 4) {
                                Text(estimatedDuration)
                                Image(systemName: "clock")
                            }
                            .font(.caption)
                            .foregroundStyle(.gray)
                        }
                        
                        HStack(spacing: 8) {
                            Image(systemName: "dumbbell.fill")
                            Text("\(workoutTemplate.exerciseTemplates.count) exercises / \(workoutTemplate.totalSets) sets")
                        }
                        .font(.caption)
                        .foregroundStyle(.gray)
                    }
                }
                .frame(height: 44)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(workoutTemplate.muscleGroupsIDs, id: \.self) { muscleGroupId in
                            Text(appComp.muscleGroupLookupSource.name(for: muscleGroupId))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.indigo)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.indigo.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding()
            .background(Color(red: 0.937, green: 0.937, blue: 0.937))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.black.opacity(0.01)))
            .shadow(color: .black.opacity(0.06), radius: 10, y: 6)
            .swipeActions(
                config: .init(
                    leadingPadding: 0,
                    trailingPadding: 16,
                    spacing: 16,
                    occupiesFullWidth: true
                ),
                progress: $swipeProgress) {
                    SwipeAction(
                        symbolImage: "trash",
                        tint: .red,
                        background: .red.opacity(0.2),
                        size: CGSize(width: 55, height: 55),
                    ) { close in
                            close {
                                print("Something")
                            }
                        }
                    
                    SwipeAction(
                        symbolImage: "chevron.right",
                        tint: .green,
                        background: .green.opacity(0.2),
                        size: CGSize(width: 55, height: 55),
                    ) { close in
                            close {
                                print("Starting")
                            }
                        }
                }
        } menu: { close in
            ScrollView(.vertical, showsIndicators: false) {
                VStack (spacing: 8) {
                    ForEach(workoutTemplate.exerciseTemplates, id: \.id) { exerciseTemplate in
                        HStack(alignment: .center, spacing: 6) {
                            Text("3 x \(appComp.exerciseLookupSource.name(for: exerciseTemplate.exerciseId))")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Spacer(minLength: 8)
                            
                            Text(appComp.exerciseMuscleGroupNameLookupSource.muscleGroupName(for: exerciseTemplate.exerciseId) ?? "nan")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 32)
            }
            .safeAreaInset(edge: .top) {
                VStack (alignment: .leading, spacing: 16) {
                    HStack (alignment: .center) {
                        Text(workoutTemplate.name)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.black)
                            .lineLimit(1)
                        
                        Spacer(minLength: 8)
                        
                        HStack (spacing: 4) {
                            Text(estimatedDuration)
                            Image(systemName: "clock")
                        }
                        .font(.caption)
                        .foregroundStyle(.gray)
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(workoutTemplate.muscleGroupsIDs, id: \.self) { muscleGroupId in
                                Text(appComp.muscleGroupLookupSource.name(for: muscleGroupId))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.indigo)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(Color.indigo.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding()
                .background {
                    UnevenRoundedRectangle(cornerRadii: .init(bottomLeading: 12, bottomTrailing: 12))
                        .fill(Color(red: 0.937, green: 0.937, blue: 0.937))
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack (spacing: 8) {
                    Button {
                        close {
                            onEdit()
                        }
                    } label: {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.indigo.opacity(0.15))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .overlay {
                                Text("Edit")
                                    .font(.subheadline)
                                    .foregroundStyle(.indigo)
                                    .fontWeight(.bold)
                            }
                    }
                    
                    Button {
                        close {
                            onStart()
                        }
                    } label: {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.indigo)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .overlay {
                                Text("Start workout")
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                                    .fontWeight(.bold)
                            }
                    }
                }
                .padding()
                .background {
                    UnevenRoundedRectangle(cornerRadii: .init(topLeading: 12, topTrailing: 12))
                        .fill(Color(red: 0.937, green: 0.937, blue: 0.937))
                }

            }
            .frame(width: UIScreen.size.width - 32)
            .frame(maxHeight: UIScreen.size.height - 32)
        }
    }
}
