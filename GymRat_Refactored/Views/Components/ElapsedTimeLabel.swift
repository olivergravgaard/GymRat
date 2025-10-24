import SwiftUI
import Foundation

fileprivate func formatElapsed(since start: Date, now: Date = .now) -> String {
    let total = max(0, Int(now.timeIntervalSince(start)))
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60

    if h > 0 {
        return String(format: "%02dh %02dm %02ds", h, m, s)   // hh:mm:ss
    } else if m > 0 {
        return String(format: "%02dm %02ds", m, s)           // mm:ss
    } else {
        return String(format: "%02ds", s)                   // ss
    }
}

struct ElapsedTimeLabel: View {
    let startedAt: Date
    
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(formatElapsed(since: startedAt, now: context.date))
                .monospacedDigit()
                .accessibilityLabel("Elapsed time")
        }
    }
}
