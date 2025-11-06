import SwiftUI

// MARK: - Profile View

struct ProfileDemoView: View {
    @State private var selectedDate = Date()
    @State private var recent: [WorkoutSummary] = WorkoutSummary.mock.prefix(3).map { $0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                ProfileHeaderCard(name: "Oliver Gravgaard")

                CalendarCard(selected: $selectedDate)

                RecentWorkoutsCard(workouts: recent) { workout in
                    // Handle open workout detail
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Header

private struct ProfileHeaderCard: View {
    var name: String

    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(.secondarySystemBackground))
            .overlay {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.indigo.opacity(0.12))
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(.indigo)
                    }
                    .frame(width: 64, height: 64)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(name)
                            .font(.title3).bold()
                            .foregroundStyle(.primary)

                        HStack(spacing: 8) {
                            StatPill(icon: "flame.fill", label: "Streak", value: "7")
                            StatPill(icon: "timer", label: "This week", value: "3h 42m")
                        }
                    }

                    Spacer()

                    Button {
                        // settings
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.secondary)
                            .padding(10)
                            .background(.thinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
            }
            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
            .frame(maxWidth: .infinity, minHeight: 92)
    }
}

private struct StatPill: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.indigo)
            Text("\(label): \(value)")
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(.indigo)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.indigo.opacity(0.12), in: Capsule())
    }
}

// MARK: - Calendar

private struct CalendarCard: View {
    @Binding var selected: Date
    private let calendar = Calendar.current

    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(.secondarySystemBackground))
            .overlay {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(monthTitle(selected))
                            .font(.headline).bold()

                        Spacer()

                        Button {
                            withAnimation(.snappy) { selected = Date() }
                        } label: {
                            Text("Today")
                                .font(.caption).fontWeight(.semibold)
                                .foregroundStyle(.indigo)
                        }
                        .buttonStyle(.plain)
                    }

                    WeekdayHeader()

                    MonthGrid(selected: $selected)
                }
                .padding(16)
            }
            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }

    private func monthTitle(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "LLLL yyyy"
        return f.string(from: date).capitalized
    }

    private struct WeekdayHeader: View {
        var body: some View {
            let symbols = Calendar.current.shortStandaloneWeekdaySymbols
            HStack {
                ForEach(symbols, id: \.self) { s in
                    Text(s.uppercased())
                        .font(.caption2).fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private struct MonthGrid: View {
        @Binding var selected: Date
        private let calendar = Calendar.current

        var body: some View {
            let days = makeDays()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(days, id: \.self) { day in
                    DayCell(date: day, selected: $selected)
                }
            }
        }

        private func makeDays() -> [Date] {
            let comps = calendar.dateComponents([.year, .month], from: selected)
            let startOfMonth = calendar.date(from: comps)!
            let firstWeekday = calendar.component(.weekday, from: startOfMonth)
            let leading = (firstWeekday + 6) % 7

            let range = calendar.range(of: .day, in: .month, for: selected)!
            let daysInMonth = range.count

            let gridCount = ((leading + daysInMonth) <= 35) ? 35 : 42

            let start = calendar.date(byAdding: .day, value: -leading, to: startOfMonth)!
            return (0..<gridCount).compactMap { calendar.date(byAdding: .day, value: $0, to: start)! }
        }

        private struct DayCell: View {
            let date: Date
            @Binding var selected: Date
            private let calendar = Calendar.current

            var body: some View {
                let isSameMonth = calendar.isDate(date, equalTo: selected, toGranularity: .month)
                let isToday = calendar.isDateInToday(date)
                let isSelected = calendar.isDate(date, inSameDayAs: selected)

                Button {
                    withAnimation(.snappy) { selected = date }
                } label: {
                    VStack(spacing: 4) {
                        Text("\(calendar.component(.day, from: date))")
                            .font(.footnote).fontWeight(.semibold)
                            .foregroundStyle(isSameMonth ? .primary : .secondary)
                            .opacity(isSameMonth ? 1 : 0.5)
                    }
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .padding(.vertical, 6)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.indigo.opacity(0.15))
                        } else if isToday {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.indigo.opacity(0.35), lineWidth: 1)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Recent Workouts

private struct RecentWorkoutsCard: View {
    let workouts: [WorkoutSummary]
    var onOpen: (WorkoutSummary) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent workouts")
                    .font(.headline).bold()
                Spacer()
            }

            VStack(spacing: 12) {
                ForEach(workouts) { w in
                    WorkoutRowCard(summary: w) { onOpen(w) }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        )
    }
}

private struct WorkoutRowCard: View {
    let summary: WorkoutSummary
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.indigo.opacity(0.12))
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 24))
                        .foregroundStyle(.indigo)
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(summary.title)
                            .font(.subheadline).fontWeight(.bold)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer()
                        HStack(spacing: 4) {
                            Text(summary.durationString)
                                .font(.caption).fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            Image(systemName: "clock")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 8) {
                        LabelRow(icon: "dumbbell.fill",
                                 text: "\(summary.exercises) exercises / \(summary.sets) sets")

                        Spacer(minLength: 0)
                    }

                    if !summary.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(summary.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption).fontWeight(.semibold)
                                        .foregroundStyle(.indigo)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.indigo.opacity(0.12), in: Capsule())
                                }
                            }
                        }
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.tertiarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct LabelRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption).fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Data Model

struct WorkoutSummary: Identifiable {
    let id = UUID()
    let title: String
    let duration: TimeInterval
    let exercises: Int
    let sets: Int
    let tags: [String]

    var durationString: String {
        let m = Int(duration) / 60
        let s = Int(duration) % 60
        return "\(m)m \(s)s"
    }

    static let mock: [WorkoutSummary] = [
        .init(title: "Push v1", duration: 50*60+18, exercises: 4, sets: 25, tags: ["Chest"]),
        .init(title: "Push V11", duration: 77*60+50, exercises: 14, sets: 59, tags: ["Chest","Shoulders","Triceps","Calves"]),
        .init(title: "ErererERer...", duration: 16*60+26, exercises: 1, sets: 7, tags: ["Back","Biceps"]),
        .init(title: "Leg day", duration: 69*60+11, exercises: 8, sets: 36, tags: ["Quads","Hamstrings","Glutes"])
    ]
}

#Preview {
    ProfileDemoView()
}
