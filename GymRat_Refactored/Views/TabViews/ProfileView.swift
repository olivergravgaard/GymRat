import SwiftUI

struct ProfileView: View {
    
    @State private var path = NavigationPath()
    
    var body: some View {
        NavigationStack (path: $path) {
            ScrollView(.vertical) {
                VStack(spacing: 16) {
                    StatsCard()
                    RecentWorkoutsCard()
                }
                .padding(.top, 16)
            }
            //.fadedBottomSafeArea()
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .top) {
                TopBar()
                    .frame(maxWidth: .infinity)
            }
            .ignoresSafeArea(edges: [.top])
            .safeAreaInset(edge: .bottom, alignment: .trailing) {
                Button {
                    
                } label: {
                    Image(systemName: "gear")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 22)
                        .foregroundStyle(.indigo)
                        .compositingGroup()
                        .frame(width: 55, height: 55)
                        .background {
                            Circle()
                                .fill(.clear)
                                .glassEffect(.regular.interactive(true), in: .circle)
                        }
                }
                .padding(.trailing)
            }
        }
    }
}

fileprivate struct InfoCard<Content: View>: View {
    
    @ViewBuilder var content: Content
    
    var body: some View {
        VStack (alignment: .leading, spacing: 12) {
            content
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.95, green: 0.95, blue: 0.97))
        }
        .padding(.horizontal)
        .compositingGroup()
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }
}

private struct StatsCard: View {
    
    let numpadhost: NumpadHost = .init()
    
    var body: some View {
        InfoCard {
            HStack (alignment: .center) {
                Text("Statistics")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                MorphMenuView(
                    numpadHost: numpadhost,
                    config: .init(
                        alignment: .topTrailing,
                        cornerRadius: 16,
                        extraBounce: 0,
                        animation: .smooth(duration: 0.3),
                        backgroundTapable: true
                    )) {
                        Text("This week")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.indigo)
                    } menu: { close in
                        
                    }

            }

            VStack(spacing: 12) {
                HStack {
                    StatCapsule(icon: "flame.fill",
                                title: "Streak",
                                value: "\(6) days")
                    
                    Spacer(minLength: 12)

                    StatCapsule(icon: "timer",
                                title: "Total time",
                                value: "4h 38m")
                }

                HStack {
                    StatCapsule(icon: "figure.strengthtraining.traditional",
                                title: "Workouts",
                                value: "7")
                    
                    Spacer(minLength: 12)

                    StatCapsule(icon: "dumbbell.fill",
                                title: "Sets",
                                value: "38")
                }
            }
            .padding(4)
        }
    }
}

private struct StatCapsule: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.indigo.opacity(0.12))
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(.indigo)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.gray)
                Text(value)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.95, green: 0.95, blue: 0.97).opacity(1))
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.1), radius: 2, y: 2)
    }
}

fileprivate struct RecentWorkoutsCard: View {
    var body: some View {
        InfoCard {
            HStack (alignment: .center) {
                Text("Recent workouts")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button {
                    
                } label: {
                    Text("View all")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.indigo)
                }
            }
            
            VStack (spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    RecentWorkoutCard()
                }
            }
            .padding(4)
        }
    }
}

fileprivate struct RecentWorkoutCard: View {
    var body: some View {
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
                    Text("Push v1")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer(minLength: 0)
                    
                    HStack (alignment: .center, spacing: 4) {
                        Image(systemName: "clock.fill")
                        Text("1h 2m 13s")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.gray)
                }
                
                Text("6 exercises / 24 sets")
                    .font(.caption2)
                    .foregroundStyle(.gray)
                
                ScrollView (.horizontal) {
                    HStack (spacing: 8) {
                        Text("Chest")
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
    }
}

fileprivate struct TopBar: View {
    var body: some View {
        HStack (alignment: .center) {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 72)
            
            VStack (alignment: .leading, spacing: 12) {
                Text("Oliver Gravgaard")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                HStack {
                    VStack (alignment: .leading) {
                        Text("99")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("workouts")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                    }
                    
                    Spacer(minLength: 0)
                    
                    VStack (alignment: .leading) {
                        Text("999")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("followers")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                    }
                    
                    Spacer(minLength: 0)
                    
                    VStack (alignment: .leading) {
                        Text("999")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("following")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                    }
                }
            }
            .padding(.horizontal)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
        .padding(.top, 55)
        .frame(maxWidth: .infinity)
        .frame(height: 165)
        .background {
            UnevenRoundedRectangle(cornerRadii: .init(bottomLeading: 16, bottomTrailing: 16))
                .fill(Color(red: 0.95, green: 0.95, blue: 0.97).opacity(0.1))
                .glassEffect(.regular.interactive(false), in: .rect(cornerRadii: .init(bottomLeading: 16, bottomTrailing: 16)))
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }
}

#Preview {
    ProfileView()
}
