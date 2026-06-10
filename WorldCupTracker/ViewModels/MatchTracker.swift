import Foundation
import Observation

@Observable @MainActor
final class MatchTracker {
    var matches: [Match] = []
    var loadState: LoadState = .idle
    var lastUpdated: Date?
    var isAuthenticated: Bool = ApiKeyStore.load() != nil
    var apiKeyError: String?

    // Cached World Cup season ID — persists across launches via UserDefaults
    private var cachedSeasonId: Int? = UserDefaults.standard.integer(forKey: "wc_season_id").nonZero
    // Cached league ID discovered from date-range results (faster than broad date queries)
    private var cachedLeagueId: Int? = UserDefaults.standard.integer(forKey: "wc_league_id").nonZero
    // True when season discovery failed and we're using date-range/league-id filtering instead
    private var usesDateFallback: Bool = UserDefaults.standard.bool(forKey: "wc_date_fallback")

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
            // BSD has no rate limit — poll 30s live, 3 min otherwise
            let interval: Duration = liveMatches.isEmpty ? .seconds(180) : .seconds(30)
            do { try await Task.sleep(for: interval) }
            catch { break }
        }
    }

    // MARK: - Data

    func fetch() async {
        guard isAuthenticated, !loadState.isLoading else { return }
        loadState = .loading
        do {
            let fetchedMatches: [Match]
            if let seasonId = cachedSeasonId {
                // Best path: direct season query
                fetchedMatches = try await WorldCupAPIClient.shared.matches(seasonId: seasonId)
            } else if let leagueId = cachedLeagueId {
                // Good path: direct league query (discovered on a previous run)
                fetchedMatches = try await WorldCupAPIClient.shared.matchesByLeague(leagueId: leagueId)
            } else if let seasonId = try await resolveSeasonId() {
                // Discovered season on this run
                fetchedMatches = try await WorldCupAPIClient.shared.matches(seasonId: seasonId)
            } else {
                // Last resort: date range with WC round/group name filtering
                let result = try await WorldCupAPIClient.shared.matchesByDateRange()
                fetchedMatches = result.matches
                // Cache whatever IDs we found so future polls skip this expensive path
                if let sid = result.seasonId {
                    cachedSeasonId = sid
                    UserDefaults.standard.set(sid, forKey: "wc_season_id")
                } else if let lid = result.leagueId {
                    cachedLeagueId = lid
                    UserDefaults.standard.set(lid, forKey: "wc_league_id")
                }
            }
            matches = fetchedMatches
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

    // Returns the cached season ID, or discovers it. Returns nil if not found (use date range).
    private func resolveSeasonId() async throws -> Int? {
        if let cached = cachedSeasonId { return cached }
        do {
            let id = try await WorldCupAPIClient.shared.findWorldCupSeasonId()
            cachedSeasonId = id
            UserDefaults.standard.set(id, forKey: "wc_season_id")
            return id
        } catch APIError.worldCupNotFound {
            return nil
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
        cachedSeasonId = nil
        cachedLeagueId = nil
        usesDateFallback = false
        UserDefaults.standard.removeObject(forKey: "wc_season_id")
        UserDefaults.standard.removeObject(forKey: "wc_league_id")
        UserDefaults.standard.removeObject(forKey: "wc_date_fallback")
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
        cachedSeasonId = nil
        cachedLeagueId = nil
        usesDateFallback = false
        UserDefaults.standard.removeObject(forKey: "wc_season_id")
        UserDefaults.standard.removeObject(forKey: "wc_league_id")
        UserDefaults.standard.removeObject(forKey: "wc_date_fallback")
        isAuthenticated = false
        matches = []
        loadState = .idle
        pollingTask = nil
    }
}

// MARK: - Helpers

private extension Int {
    /// Returns nil when the Int is 0 (UserDefaults returns 0 for missing integer keys)
    var nonZero: Int? { self == 0 ? nil : self }
}
