import SwiftUI

struct ContentView: View {
    @Environment(MatchTracker.self) private var tracker
    @State private var showSettings = false

    var body: some View {
        Group {
            if !tracker.isAuthenticated {
                SettingsView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                matchList
            }
        }
        .onAppear { tracker.start() }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 480)
        #endif
    }

    // MARK: - Match list

    private var matchList: some View {
        NavigationStack {
            List {
                if !tracker.liveMatches.isEmpty {
                    Section("Live") {
                        ForEach(tracker.liveMatches) { MatchRow(match: $0) }
                    }
                }
                if !tracker.upcomingMatches.isEmpty {
                    Section("Upcoming") {
                        ForEach(tracker.upcomingMatches) { MatchRow(match: $0) }
                    }
                }
                if !tracker.finishedMatches.isEmpty {
                    Section("Finished") {
                        ForEach(tracker.finishedMatches) { MatchRow(match: $0) }
                    }
                }
                if case .error(let msg) = tracker.loadState {
                    Section {
                        Label(msg, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("2026 FIFA World Cup")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        Task { await tracker.fetch() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(tracker.loadState.isLoading)
                }
                ToolbarItem(placement: .automatic) {
                    Button {
                        showSettings = true
                    } label: {
                        Label("Account", systemImage: "person.circle")
                    }
                }
            }
            .overlay {
                if tracker.loadState.isLoading && tracker.matches.isEmpty {
                    ProgressView("Loading matches…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(tracker)
                #if os(macOS)
                .frame(width: 340)
                .padding()
                #endif
        }
    }
}

// MARK: - Match Row

private struct MatchRow: View {
    let match: Match

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(match.homeDisplayName)
                        .fontWeight(leadWeight(isHome: true))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    scoreOrTime
                        .frame(minWidth: 70)
                    Text(match.awayDisplayName)
                        .fontWeight(leadWeight(isHome: false))
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                Text(match.stageLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if match.isLive {
                Circle()
                    .fill(.red)
                    .frame(width: 7, height: 7)
            }
        }
    }

    @ViewBuilder
    private var scoreOrTime: some View {
        switch match.status {
        case .live:
            VStack(spacing: 1) {
                Text("\(match.homeScore) – \(match.awayScore)")
                    .font(.callout.bold())
                    .monospacedDigit()
                Text(match.elapsedDisplay ?? "")
                    .font(.caption2.bold())
                    .foregroundStyle(.red)
            }
            .multilineTextAlignment(.center)
        case .upcoming:
            VStack(spacing: 1) {
                Text(match.kickoff, format: .dateTime.month(.abbreviated).day())
                Text(match.kickoff, format: .dateTime.hour().minute())
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .monospacedDigit()
        case .finished:
            Text("\(match.homeScore) – \(match.awayScore)")
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        case .postponed:
            Text("PST")
                .font(.caption)
                .foregroundStyle(.orange)
        case .cancelled:
            Text("CANC")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func leadWeight(isHome: Bool) -> Font.Weight {
        guard let h = match.homeScoreValue, let a = match.awayScoreValue else { return .regular }
        if isHome { return h > a ? .semibold : .regular }
        return a > h ? .semibold : .regular
    }
}

#Preview {
    ContentView()
        .environment(MatchTracker())
}
