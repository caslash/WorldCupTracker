#if os(macOS)
import SwiftUI

struct MenuBarLabel: View {
    var tracker: MatchTracker

    var body: some View {
        HStack(spacing: 4) {
            Text(labelText)
                .lineLimit(1)
        }
    }

    private var labelText: String {
        guard tracker.isAuthenticated else { return "Setup" }
        if tracker.loadState.isLoading && tracker.matches.isEmpty { return "Loading…" }
        guard let match = tracker.featured else { return "No Matches" }
        return match.menuBarText
    }
}

private extension Match {
    var menuBarText: String {
        let h = homeFlagEmoji
        let a = awayFlagEmoji
        switch status {
        case .live:
            let display = elapsedDisplay ?? ""
            return "\(h) \(homeScore)–\(awayScore) \(a) \(display)"
        case .upcoming:
            let dateStr = Self.menuBarFormatter.string(from: kickoff)
            return "\(h) vs \(a) · \(dateStr)"
        case .finished:
            let label = finishedLabel ?? "FT"
            return "\(h) \(homeScore)–\(awayScore) \(a) \(label)"
        case .postponed:
            return "\(h) vs \(a) PST"
        case .cancelled:
            return "\(h) vs \(a)"
        }
    }

    private static let menuBarFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, HH:mm"
        return f
    }()
}
#endif

#Preview {
    MenuBarLabel(tracker: MatchTracker())
}
