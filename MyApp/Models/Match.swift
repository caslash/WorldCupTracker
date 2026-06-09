import Foundation

// MARK: - Response wrapper

struct FixturesResponse: Decodable {
    let errors: APIResponseErrors
    let response: [Match]
}

// api-football sends "errors": [] (empty array) on success, {"key": "msg"} on failure.
// This custom type handles both.
struct APIResponseErrors: Decodable {
    let messages: [String: String]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        messages = (try? container.decode([String: String].self)) ?? [:]
    }

    var hasErrors: Bool { !messages.isEmpty }
    var first: String? { messages.values.first }
}

// MARK: - Match (one fixture entry from /fixtures)

struct Match: Decodable, Identifiable {
    var id: Int { fixture.id }

    let fixture: FixtureInfo
    let league: LeagueInfo
    let teams: TeamsInfo
    let goals: GoalsInfo
    let score: ScoreInfo

    // MARK: Display names

    var homeDisplayName: String { teams.home.name }
    var awayDisplayName: String { teams.away.name }
    var homeShortName: String { abbreviate(teams.home.name) }
    var awayShortName: String { abbreviate(teams.away.name) }

    // "Mexico" → "MEX", "South Africa" → "SA", "United States" → "US"
    private func abbreviate(_ name: String) -> String {
        let words = name.split(separator: " ")
        if words.count == 1 { return String(name.prefix(3)).uppercased() }
        return words.prefix(4).map { String($0.prefix(1)) }.joined().uppercased()
    }

    // MARK: Scores

    var homeScore: String { goals.home.map(String.init) ?? "0" }
    var awayScore: String { goals.away.map(String.init) ?? "0" }
    var homeScoreValue: Int? { goals.home }
    var awayScoreValue: Int? { goals.away }

    // MARK: Dates & stage

    var kickoff: Date { Date(timeIntervalSince1970: TimeInterval(fixture.timestamp)) }

    var stageLabel: String { league.round }

    // MARK: Status

    var status: MatchStatus {
        switch fixture.status.short {
        case "1H", "2H", "ET", "BT", "INT":
            return .live(elapsed: fixture.status.elapsed, extra: fixture.status.extra,
                         short: fixture.status.short)
        case "HT", "P":
            return .live(elapsed: fixture.status.elapsed, extra: nil,
                         short: fixture.status.short)
        case "FT", "AET", "PEN":
            return .finished(short: fixture.status.short)
        case "PST":
            return .postponed
        case "CANC", "ABD", "SUSP", "WO", "AWD":
            return .cancelled
        default:
            return .upcoming  // NS, TBD
        }
    }

    var isLive: Bool { if case .live = status { return true }; return false }
    var isUpcoming: Bool { if case .upcoming = status { return true }; return false }
    var isFinished: Bool { if case .finished = status { return true }; return false }

    // e.g. "67'", "90+3'", "HT", "PK", "BT"
    var elapsedDisplay: String? {
        guard case .live(let elapsed, let extra, let short) = status else { return nil }
        switch short {
        case "HT": return "HT"
        case "P":  return "PK"
        case "BT": return "BT"
        default:
            guard let e = elapsed else { return short }
            return extra.map { "\(e)+\($0)'" } ?? "\(e)'"
        }
    }

    // "FT", "AET", or "PEN"
    var finishedLabel: String? {
        guard case .finished(let short) = status else { return nil }
        return short
    }
}

// MARK: - Nested decodable types

struct FixtureInfo: Decodable {
    let id: Int
    let timestamp: Int
    let status: StatusInfo
    let venue: VenueInfo?
}

struct StatusInfo: Decodable {
    let long: String
    let short: String
    let elapsed: Int?
    let extra: Int?
}

struct VenueInfo: Decodable {
    let name: String?
    let city: String?
}

struct LeagueInfo: Decodable {
    let id: Int
    let name: String
    let round: String
}

struct TeamsInfo: Decodable {
    let home: TeamInfo
    let away: TeamInfo
}

struct TeamInfo: Decodable {
    let id: Int
    let name: String
    let logo: String?
}

struct GoalsInfo: Decodable {
    let home: Int?
    let away: Int?
}

struct ScoreInfo: Decodable {
    let halftime: GoalsInfo
    let fulltime: GoalsInfo
    let extratime: GoalsInfo?
    let penalty: GoalsInfo?
}

// MARK: - Status enum

enum MatchStatus {
    case upcoming
    case live(elapsed: Int?, extra: Int?, short: String)
    case finished(short: String)
    case postponed
    case cancelled
}
