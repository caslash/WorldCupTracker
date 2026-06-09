import Foundation

enum APIError: Error, LocalizedError {
    case unauthorized
    case rateLimited
    case apiError(String)
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .unauthorized:           return "No API key — enter one in Settings."
        case .rateLimited:            return "Rate limit reached (100 calls/day on free tier)."
        case .apiError(let msg):      return msg
        case .serverError(let code):  return "Server error (\(code))."
        }
    }
}

struct WorldCupAPIClient {
    static let shared = WorldCupAPIClient()

    // Direct api-sports.io endpoint; auth via x-apisports-key header (no RapidAPI wrapper)
    private let baseURL = URL(string: "https://v3.football.api-sports.io")!
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        session = URLSession(configuration: config)
    }

    // MARK: - Fixtures

    /// Fetch all FIFA World Cup 2026 fixtures (league=1, season=2026).
    /// Free tier allows 100 calls/day — the tracker polls conservatively to stay within that.
    func fixtures() async throws -> [Match] {
        guard let key = ApiKeyStore.load() else { throw APIError.unauthorized }
        let url = makeURL("fixtures", params: ["league": "1", "season": "2026"])
        var request = URLRequest(url: url)
        request.setValue(key, forHTTPHeaderField: "x-apisports-key")
        let (data, response) = try await session.data(for: request)
        try checkStatus(response)
        let decoded = try JSONDecoder().decode(FixturesResponse.self, from: data)
        if decoded.errors.hasErrors {
            throw APIError.apiError(decoded.errors.first ?? "Unknown API error")
        }
        return decoded.response
    }

    // MARK: - Helpers

    private func makeURL(_ path: String, params: [String: String]) -> URL {
        var components = URLComponents(url: baseURL.appending(path: path),
                                       resolvingAgainstBaseURL: false)!
        components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        return components.url!
    }

    private func checkStatus(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200..<300: return
        case 401, 403:  throw APIError.unauthorized
        case 429:        throw APIError.rateLimited
        default:         throw APIError.serverError(http.statusCode)
        }
    }
}
