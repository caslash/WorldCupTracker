import SwiftUI

struct SettingsView: View {
    @Environment(MatchTracker.self) private var tracker

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
        }
        .padding(24)
    }

    // MARK: - API key form

    private var apiKeyForm: some View {
        VStack(spacing: 14) {
            Text("Enter your API-Football key to get started.")
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
                Text("Get a free key at **api-football.com**")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Free tier: 100 calls/day. The app polls every 2 min during a live match and every 30 min otherwise to stay within this limit.")
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
            Text("Connected to API-Football. Live scores update every 2 minutes.")
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
