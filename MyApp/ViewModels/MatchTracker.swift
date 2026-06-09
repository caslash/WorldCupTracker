import Foundation
import Observation

@Observable @MainActor
final class MatchTracker {
    var matches: [Match] = []
    var loadState: LoadState = .idle
    var lastUpdated: Date?
    var isAuthenticated: Bool = ApiKeyStore.load() != nil
    var apiKeyError: String?

    private var pollingTask: Task<Void, Never>?

    enum LoadState: Equatable {
        case idle, loading, loaded, error(String)
        var isLoading: Bool { self == .loading }
    }

    // MARK: - Computed match lists

    var featured: Match? {
        if let live = matches.first(where: \.isLive) { return live }
        let next = matches.filter(\.isUpcoming).sorted { $0.kickoff < $1.kickoff }.first
        if let next { return next }
        return matches.filter(\.isFinished).last
    }

    var liveMatches: [Match] { matches.filter(\.isLive) }

    var upcomingMatches: [Match] {
        matches.filter(\.isUpcoming).sorted { $0.kickoff < $1.kickoff }
    }

    var finishedMatches: [Match] { matches.filter(\.isFinished) }

    // MARK: - Lifecycle

    func start() {
        guard pollingTask == nil else { return }
        pollingTask = Task { await poll() }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func poll() async {
        while !Task.isCancelled {
            await fetch()
            // Free tier: 100 calls/day — 2 min during a live match, 30 min otherwise
            let interval: Duration = liveMatches.isEmpty ? .seconds(1800) : .seconds(120)
            do { try await Task.sleep(for: interval) }
            catch { break }
        }
    }

    // MARK: - Data

    func fetch() async {
        guard isAuthenticated, !loadState.isLoading else { return }
        loadState = .loading
        do {
            matches = try await WorldCupAPIClient.shared.fixtures()
            lastUpdated = Date()
            loadState = .loaded
        } catch APIError.unauthorized {
            isAuthenticated = false
            ApiKeyStore.delete()
            loadState = .error("Invalid API key. Please update it in Settings.")
        } catch {
            loadState = .error(error.localizedDescription)
        }
    }

    // MARK: - API key management

    func setApiKey(_ key: String) async {
        apiKeyError = nil
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            apiKeyError = "API key cannot be empty."
            return
        }
        ApiKeyStore.save(trimmed)
        isAuthenticated = true
        stop()
        pollingTask = nil
        // Validate the key with a real request
        await fetch()
        if case .error(let msg) = loadState {
            ApiKeyStore.delete()
            isAuthenticated = false
            apiKeyError = msg
            loadState = .idle
        } else {
            start()
        }
    }

    func removeApiKey() {
        stop()
        ApiKeyStore.delete()
        isAuthenticated = false
        matches = []
        loadState = .idle
        pollingTask = nil
    }
}
