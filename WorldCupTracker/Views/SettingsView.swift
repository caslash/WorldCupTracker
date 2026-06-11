import SwiftUI

struct SettingsView: View {
    @Environment(MatchTracker.self) private var tracker
    #if os(macOS)
    @Environment(AppUpdater.self) private var updater
    #endif

    @State private var apiKey = ""
    @State private var isWorking = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "soccerball")
                .font(.system(size: 52))
                .foregroundStyle(.tint)

            Text("WorldCupTracker")
                .font(.title2.bold())

            if tracker.isAuthenticated {
                authenticatedView
            } else {
                apiKeyForm
            }

            #if os(macOS)
            Divider()

            Button("Check for Updates…") {
                updater.checkForUpdates()
            }
            .disabled(!updater.canCheckForUpdates)
            #endif
        }
        .padding(24)
    }

    // MARK: - API key form

    private var apiKeyForm: some View {
        VStack(spacing: 14) {
            Text("Enter your BSD API key to get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField("Paste API key here", text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))

            if let error = tracker.apiKeyError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button(action: save) {
                if isWorking {
                    ProgressView().controlSize(.small)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Save & Connect")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isWorking || apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Divider()

            VStack(spacing: 6) {
                Text("Get a free key at **sports.bzzoiro.com**")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("No rate limits. The app polls every 30 s during live matches and every 3 min otherwise.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 280)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 280)
    }

    // MARK: - Authenticated state

    private var authenticatedView: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)
            Text("API Key Saved")
                .font(.headline)
            Text("Connected to BSD Sports API. Live scores update every 30 seconds.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Divider()

            VStack(spacing: 10) {
                Text("Replace API Key")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("New API key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .font(.system(.caption, design: .monospaced))
                Button("Update Key", action: save)
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isWorking)
            }
            .frame(maxWidth: 260)

            Button("Remove Key", role: .destructive) {
                tracker.removeApiKey()
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Actions

    private func save() {
        isWorking = true
        Task {
            await tracker.setApiKey(apiKey)
            isWorking = false
            if tracker.isAuthenticated { apiKey = "" }
        }
    }
}
