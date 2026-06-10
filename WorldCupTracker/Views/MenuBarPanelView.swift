#if os(macOS)
import SwiftUI
import AppKit

struct MenuBarPanelView: View {
    @Environment(MatchTracker.self) private var tracker
    @Environment(\.openWindow) private var openWindow
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            if !tracker.isAuthenticated {
                setupPrompt
            } else {
                matchContent
            }
        }
        .frame(width: 300)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(tracker)
                .frame(width: 320)
                .padding()
        }
        .onAppear { tracker.start() }
    }

    // MARK: - Setup prompt (no API key yet)

    private var setupPrompt: some View {
        VStack(spacing: 14) {
            Image(systemName: "soccerball")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text("WorldCupTracker")
                .font(.headline)
            Text("Enter your API-Football key to follow the 2026 FIFA World Cup live.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Enter API Key") { showSettings = true }
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }

    // MARK: - Match content

    @ViewBuilder
    private var matchContent: some View {
        if let match = tracker.featured {
            FeaturedMatchCard(match: match)
                .padding(12)
        } else if tracker.loadState.isLoading {
            ProgressView("Loading…")
                .padding(24)
        } else {
            Text("No matches available")
                .foregroundStyle(.secondary)
                .padding(24)
        }

        Divider()

        HStack {
            if let updated = tracker.lastUpdated {
                Text(updated, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } else {
                Spacer()
            }
            Spacer()
            if tracker.loadState.isLoading {
                ProgressView().controlSize(.mini)
            } else {
                Button {
                    Task { await tracker.fetch() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)

        Divider()

        HStack(spacing: 0) {
            Button("Open App") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 16)

            Button("Settings") { showSettings = true }
                .frame(maxWidth: .infinity)

            Divider().frame(height: 16)

            Button("Quit") { NSApplication.shared.terminate(nil) }
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }
}

// MARK: - Featured Match Card

private struct FeaturedMatchCard: View {
    let match: Match

    var body: some View {
        VStack(spacing: 10) {
            statusBadge

            HStack(alignment: .top, spacing: 0) {
                teamBlock(name: match.homeDisplayName, score: match.homeScore, isLeading: isHomeLeading)
                Text("–")
                    .font(.system(size: 26, weight: .light))
                    .padding(.top, 8)
                teamBlock(name: match.awayDisplayName, score: match.awayScore, isLeading: isAwayLeading)
            }

            Text(match.stageLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch match.status {
        case .live:
            if let display = match.elapsedDisplay {
                Label(display, systemImage: "circle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.red)
            }
        case .upcoming:
            Label {
                Text(match.kickoff, style: .relative)
            } icon: {
                Image(systemName: "clock")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        case .finished:
            Text(match.finishedLabel ?? "FT")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .postponed:
            Text("Postponed")
                .font(.caption)
                .foregroundStyle(.orange)
        case .cancelled:
            Text("Cancelled")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func teamBlock(name: String, score: String, isLeading: Bool) -> some View {
        VStack(spacing: 2) {
            Text(score)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isLeading ? Color.primary : Color.secondary)
            Text(name)
                .font(.caption2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 110)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }

    private var isHomeLeading: Bool {
        guard let h = match.homeScoreValue, let a = match.awayScoreValue else { return false }
        return h > a
    }

    private var isAwayLeading: Bool {
        guard let h = match.homeScoreValue, let a = match.awayScoreValue else { return false }
        return a > h
    }
}
#endif
