import Foundation

enum APIError: Error, LocalizedError {
    case unauthorized
    case worldCupNotFound
    case serverError(Int)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .unauthorized:          return "No API key — enter one in Settings."
        case .worldCupNotFound:      return "World Cup 2026 not found in league list. Try again later."
        case .serverError(let c):    return "Server error (\(c))."
        case .decodingError(let e):  return "Response decode error: \(e.localizedDescription)"
        }
    }
}

// BSD (Bzzoiro Sports Data) — free, no rate limits
// Docs: https://sports.bzzoiro.com/docs/football/
struct WorldCupAPIClient {
    static let shared = WorldCupAPIClient()

    private let baseURL = URL(string: "https://sports.bzzoiro.com")!
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        session = URLSession(configuration: config)
    }

    // MARK: - League discovery

    /// Discovers the FIFA World Cup 2026 season ID.
    /// Tries three approaches in order:
    /// 1. Leagues list name search (fast, may fail if league is named unexpectedly)
    /// 2. Probe the first week of the WC window and extract season_id from group stage matches
    func findWorldCupSeasonId() async throws -> Int {
        // Approach 1: leagues list
        let leaguesUrl = makeURL("api/v2/leagues/", params: ["limit": "200", "include_inactive": "true"])
        if let leagues: [LeagueListItem] = try? await getArray(url: leaguesUrl) {
            let wc = leagues.first(where: {
                $0.name.localizedCaseInsensitiveContains("world cup") ||
                ($0.name.localizedCaseInsensitiveContains("fifa") &&
                 !$0.name.localizedCaseInsensitiveContains("women"))
            })
            if let wc, let season = wc.currentSeason {
                return season.id
            }
        }
        // Approach 2: probe the full WC window and extract season_id from any WC match.
        // Prefer group stage (groupName set), fall back to knockout rounds (roundName patterns).
        // Note: group stage data may not be in BSD yet — knockout brackets are pre-built.
        let probeUrl = makeURL("api/v2/events/", params: [
            "date_from": "2026-06-11",
            "date_to":   "2026-07-20",
            "limit":     "50"
        ])
        let probeMatches: [Match] = (try? await getArray(url: probeUrl)) ?? []
        let wcMatch = probeMatches.first(where: {
            $0.groupName != nil ||
            $0.roundName.localizedCaseInsensitiveContains("round of") ||
            $0.roundName.localizedCaseInsensitiveContains("quarter") ||
            $0.roundName.localizedCaseInsensitiveContains("semi") ||
            $0.roundName.localizedCaseInsensitiveContains("final")
        })
        if let seasonId = wcMatch?.seasonId {
            return seasonId
        }
        throw APIError.worldCupNotFound
    }

    // MARK: - All matches

    /// Full World Cup fixture list using a known season ID.
    func matches(seasonId: Int) async throws -> [Match] {
        let url = makeURL("api/v2/events/", params: [
            "season_id": String(seasonId),
            "limit": "200"
        ])
        return try await getArray(url: url)
    }

    /// Last-resort fallback: fetch the WC window and filter to WC matches by round/group name.
    /// NOTE: `is_neutral_ground` is unreliable in BSD — do not use it as a filter.
    func matchesByDateRange() async throws -> (matches: [Match], seasonId: Int?, leagueId: Int?) {
        let url = makeURL("api/v2/events/", params: [
            "date_from": "2026-06-11",
            "date_to":   "2026-07-20",
            "limit":     "200"
        ])
        let all: [Match] = try await getArray(url: url)

        // Filter to WC-specific matches using round/group name patterns.
        // Club matches have empty roundName and nil groupName.
        let wcOnly = all.filter { match in
            let round = match.roundName.lowercased()
            return match.groupName != nil ||
                   round.contains("round of") ||
                   round.contains("quarter") ||
                   round.contains("semi") ||
                   round.contains("final")
        }

        let first = wcOnly.first
        return (wcOnly, first?.seasonId, first?.leagueId)
    }

    /// Fetch all World Cup matches using a known league ID (faster than date range).
    func matchesByLeague(leagueId: Int) async throws -> [Match] {
        let url = makeURL("api/v2/events/", params: [
            "league_id": String(leagueId),
            "date_from": "2026-06-11",
            "date_to":   "2026-07-20",
            "limit":     "200"
        ])
        return try await getArray(url: url)
    }

    // MARK: - Helpers

    /// Decodes an array from the response, handling both a raw JSON array `[...]`
    /// and a DRF-style paginated wrapper `{"count": N, "results": [...]}`.
    private func getArray<T: Decodable>(url: URL) async throws -> [T] {
        guard let key = ApiKeyStore.load() else { throw APIError.unauthorized }
        var request = URLRequest(url: url)
        request.setValue("Token \(key)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        try checkStatus(response)

        // Try plain array first (what the spec documents)
        if let items = try? JSONDecoder().decode([T].self, from: data) {
            return items
        }
        // Fall back to Django REST Framework paginated wrapper {"count": N, "results": [...]}
        if let wrapper = try? JSONDecoder().decode(PaginatedResults<T>.self, from: data) {
            return wrapper.results
        }
        // Both failed — decode as plain array to surface the real error message
        do {
            return try JSONDecoder().decode([T].self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func makeURL(_ path: String, params: [String: String] = [:]) -> URL {
        var components = URLComponents(url: baseURL.appending(path: path),
                                       resolvingAgainstBaseURL: false)!
        if !params.isEmpty {
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        return components.url!
    }

    private func checkStatus(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200..<300: return
        case 401, 403:  throw APIError.unauthorized
        default:         throw APIError.serverError(http.statusCode)
        }
    }
}

private struct PaginatedResults<T: Decodable>: Decodable {
    let results: [T]
}
