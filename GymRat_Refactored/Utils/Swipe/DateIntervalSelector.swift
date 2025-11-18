import SwiftUI

struct DateIntervalPickerDesign: View {
    let calendar: Calendar = .current
    let monthsToShow: Int
    let selectedStart: Date?
    let selectedEnd: Date?

    init(monthsToShow: Int = 3,
         selectedStart: Date? = Calendar.current.startOfDay(for: .now),
         selectedEnd: Date? = Calendar.current.date(byAdding: .day, value: 6, to: Calendar.current.startOfDay(for: .now))) {
        self.monthsToShow = monthsToShow
        self.selectedStart = selectedStart
        self.selectedEnd = selectedEnd
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                PresetsBarDesign()
                    .padding(.horizontal)

                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(monthAnchors(), id: \.self) { month in
                            MonthDesignView(
                                month: month,
                                calendar: calendar,
                                start: selectedStart,
                                end: selectedEnd
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }

                VStack(spacing: 6) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Start")
                                .font(.caption).foregroundStyle(.secondary)
                            Text(selectedStart.map { DateIntervalPickerDesign.format($0) } ?? "—")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("End")
                                .font(.caption).foregroundStyle(.secondary)
                            Text(selectedEnd.map { DateIntervalPickerDesign.format($0) } ?? "—")
                                .fontWeight(.semibold)
                        }
                    }
                    .padding(.horizontal)

                    HStack(spacing: 12) {
                        Button("Reset") {}
                            .buttonStyle(.bordered)
                            .disabled(true)
                        Button("Apply") {}
                            .buttonStyle(.borderedProminent)
                            .disabled(true)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle("Select period")
        }
        .background(Color("Background").ignoresSafeArea())
    }

    private func monthAnchors() -> [Date] {
        let base = calendar.date(from: calendar.dateComponents([.year, .month], from: .now))!
        return (0..<monthsToShow).compactMap { calendar.date(byAdding: .month, value: -$0, to: base) }.reversed()
    }

    static func format(_ date: Date, locale: Locale = .current) -> String {
        let df = DateFormatter()
        df.locale = locale
        df.dateFormat = "d. MMMM yyyy"
        return df.string(from: date)
    }
}

private struct PresetsBarDesign: View {
    private let items = ["This week", "Last 7 days", "This month"]
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { title in
                    Text(title)
                        .font(.subheadline).fontWeight(.semibold)
                        .padding(.vertical, 8).padding(.horizontal, 12)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(
                            Capsule().stroke(Color("Separator").opacity(0.6), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
                }
            }
        }
    }
}

private struct MonthDesignView: View {
    let month: Date
    let calendar: Calendar
    let start: Date?
    let end: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(monthTitle(month))
                .font(.headline)
                .padding(.horizontal, 4)

            let symbols = calendar.shortStandaloneWeekdaySymbols
            let ordered = orderedWeekdays(symbols, cal: calendar)

            LazyVGrid(columns: Array(repeating: .init(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(ordered, id: \.self) { s in
                    Text(s.uppercased())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(height: 16)
                }

                ForEach(0..<leadingBlanks(), id: \.self) { _ in
                    Color.clear.frame(height: 36)
                }

                ForEach(daysInMonth(), id: \.self) { day in
                    DayCellDesign(
                        date: day,
                        calendar: calendar,
                        isSelected: isSelected(day),
                        isInRange: isInRange(day),
                        isEdge: isEdge(day)
                    )
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color("Surface"))
                    .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
            )
        }
    }

    private func monthTitle(_ date: Date) -> String {
        let df = DateFormatter()
        df.calendar = calendar
        df.dateFormat = "LLLL yyyy"
        return df.string(from: date)
    }

    private func daysInMonth() -> [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let first = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else { return [] }
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: first) }
    }

    private func leadingBlanks() -> Int {
        let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
        let weekday = calendar.component(.weekday, from: firstOfMonth)
        let first = calendar.firstWeekday // 1=Sun, 2=Mon
        let delta = (weekday - first + 7) % 7
        return delta
    }

    private func orderedWeekdays(_ symbols: [String], cal: Calendar) -> [String] {
        let first = cal.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    private func isSelected(_ d: Date) -> Bool {
        let sd = start.map { calendar.isDate($0, inSameDayAs: d) } ?? false
        let ed = end.map { calendar.isDate($0, inSameDayAs: d) } ?? false
        return sd || ed
    }

    private func isInRange(_ d: Date) -> Bool {
        guard let s = start, let e = end else { return false }
        let ds = calendar.startOfDay(for: d)
        let ss = calendar.startOfDay(for: s)
        let ee = calendar.startOfDay(for: e)
        return (ds >= ss && ds <= ee)
    }

    private func isEdge(_ d: Date) -> Bool {
        guard let s = start ?? end else { return false }
        return calendar.isDate(d, inSameDayAs: s) || (end != nil && calendar.isDate(d, inSameDayAs: end!))
    }
}

private struct DayCellDesign: View {
    let date: Date
    let calendar: Calendar
    let isSelected: Bool
    let isInRange: Bool
    let isEdge: Bool

    var body: some View {
        let day = calendar.component(.day, from: date)

        ZStack {
            if isInRange {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.red.opacity(0.35))
            }
            if isEdge {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue.opacity(1), lineWidth: 2)
            }
            
            Text("\(day)")
                .font(.subheadline)
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 36)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.clear)
        )
    }
}

#Preview("DateIntervalPickerDesign") {
    DateIntervalPickerDesign(
        monthsToShow: 10,
        selectedStart: Calendar.current.date(byAdding: .day, value: -3, to: Calendar.current.startOfDay(for: .now)),
        selectedEnd: nil
    )
    .presentationDetents([.medium, .large])
}
