#if os(macOS)
import SwiftUI

struct MenuBarLabel: View {
    var tracker: MatchTracker

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "soccerball")
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
        switch status {
        case .live:
            let display = elapsedDisplay ?? ""
            return "\(homeShortName) \(homeScore)–\(awayScore) \(awayShortName) \(display)"
        case .upcoming:
            let dateStr = Self.menuBarFormatter.string(from: kickoff)
            return "\(homeShortName) vs \(awayShortName) · \(dateStr)"
        case .finished:
            let label = finishedLabel ?? "FT"
            return "\(homeShortName) \(homeScore)–\(awayScore) \(awayShortName) \(label)"
        case .postponed:
            return "\(homeShortName) vs \(awayShortName) PST"
        case .cancelled:
            return "\(homeShortName) vs \(awayShortName)"
        }
    }

    private static let menuBarFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, HH:mm"
        return f
    }()
}
#endif
