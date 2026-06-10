import Foundation

// MARK: - Match (EventDetailV2Schema from BSD /api/v2/events/)

struct Match: Decodable, Identifiable {
    let id: Int

    // Teams
    let homeTeamId: Int?
    let homeTeam: String
    let awayTeamId: Int?
    let awayTeam: String

    // Context
    let leagueId: Int?
    let seasonId: Int?
    let roundNumber: Int?
    let roundName: String
    let groupName: String?
    let isNeutralGround: Bool

    // Kickoff
    let eventDate: String  // ISO 8601 UTC e.g. "2026-06-11T13:00:00Z"

    // Status (raw string from API)
    private let statusRaw: String

    // Live tracking
    let period: String?         // "1st_half", "halftime", "2nd_half", "extra_time" or empty/nil
    let currentMinute: Int?     // Elapsed minutes in current period; null when not live

    // Scores (null before match starts)
    private let homeScoreRaw: Int?
    private let awayScoreRaw: Int?
    let homeScoreHt: Int?
    let awayScoreHt: Int?
    let penaltyShootout: PenaltyShootout?
    let extraTimeScore: ExtraTimeScore?

    enum CodingKeys: String, CodingKey {
        case id
        case homeTeamId    = "home_team_id"
        case homeTeam      = "home_team"
        case awayTeamId    = "away_team_id"
        case awayTeam      = "away_team"
        case leagueId      = "league_id"
        case seasonId      = "season_id"
        case roundNumber   = "round_number"
        case roundName     = "round_name"
        case groupName        = "group_name"
        case isNeutralGround  = "is_neutral_ground"
        case eventDate        = "event_date"
        case statusRaw     = "status"
        case period
        case currentMinute = "current_minute"
        case homeScoreRaw  = "home_score"
        case awayScoreRaw  = "away_score"
        case homeScoreHt   = "home_score_ht"
        case awayScoreHt   = "away_score_ht"
        case penaltyShootout = "penalty_shootout"
        case extraTimeScore  = "extra_time_score"
    }

    // MARK: - Display names

    var homeDisplayName: String { homeTeam }
    var awayDisplayName: String { awayTeam }
    var homeShortName: String { abbreviate(homeTeam) }
    var awayShortName: String { abbreviate(awayTeam) }
    // Flag emoji, falling back to abbreviation for placeholders like "1F" or "3C/3D/3G"
    var homeFlagEmoji: String { Self.flagEmoji(for: homeTeam) ?? homeShortName }
    var awayFlagEmoji: String { Self.flagEmoji(for: awayTeam) ?? awayShortName }

    // "Mexico" → "MEX", "South Africa" → "SA", "United States" → "US"
    private func abbreviate(_ name: String) -> String {
        let words = name.split(separator: " ")
        if words.count == 1 { return String(name.prefix(3)).uppercased() }
        return words.prefix(4).map { String($0.prefix(1)) }.joined().uppercased()
    }

    // MARK: - Flag emoji lookup

    static func flagEmoji(for teamName: String) -> String? {
        if let flag = flagOverrides[teamName] { return flag }
        if let code = localeNameToCode[teamName.lowercased()] { return flagFromCode(code) }
        return nil
    }

    private static func flagFromCode(_ code: String) -> String {
        code.unicodeScalars.compactMap {
            Unicode.Scalar($0.value + 0x1F1A5)
        }.map(String.init).joined()
    }

    // Built once: maps lowercase English country name -> ISO 3166-1 alpha-2 code
    private static let localeNameToCode: [String: String] = {
        let locale = Locale(identifier: "en_US")
        var map: [String: String] = [:]
        for code in Locale.isoRegionCodes {
            if let name = locale.localizedString(forRegionCode: code) {
                map[name.lowercased()] = code
            }
        }
        return map
    }()

    // FIFA team names that differ from Locale / ISO standard
    private static let flagOverrides: [String: String] = [
        "England":                  "🏴󠁧󠁢󠁥󠁮󠁧󠁿",
        "Scotland":                 "🏴󠁧󠁢󠁳󠁣󠁴󠁿",
        "Wales":                    "🏴󠁧󠁢󠁷󠁬󠁳󠁿",
        "United States":            "🇺🇸",
        "USA":                      "🇺🇸",
        "Korea Republic":           "🇰🇷",
        "Republic of Korea":        "🇰🇷",
        "South Korea":              "🇰🇷",
        "DPR Korea":                "🇰🇵",
        "Korea DPR":                "🇰🇵",
        "North Korea":              "🇰🇵",
        "Ivory Coast":              "🇨🇮",
        "Côte d'Ivoire":           "🇨🇮",
        "Trinidad & Tobago":        "🇹🇹",
        "Trinidad and Tobago":      "🇹🇹",
        "Bosnia & Herzegovina":     "🇧🇦",
        "Bosnia and Herzegovina":   "🇧🇦",
        "DR Congo":                 "🇨🇩",
        "Congo DR":                 "🇨🇩",
        "Czechia":                  "🇨🇿",
        "Czech Republic":           "🇨🇿",
        "North Macedonia":          "🇲🇰",
        "Republic of Ireland":      "🇮🇪",
        "Chinese Taipei":           "🇹🇼",
        "IR Iran":                  "🇮🇷",
        "UAE":                      "🇦🇪",
    ]

    // MARK: - Scores

    // String representations for backwards-compatible call sites
    var homeScore: String { homeScoreRaw.map(String.init) ?? "0" }
    var awayScore: String { awayScoreRaw.map(String.init) ?? "0" }
    var homeScoreValue: Int? { homeScoreRaw }
    var awayScoreValue: Int? { awayScoreRaw }

    // MARK: - Date

    var kickoff: Date {
        Self.dateFormatter.date(from: eventDate) ?? Date()
    }

    private static let dateFormatter = ISO8601DateFormatter()

    // MARK: - Stage

    var stageLabel: String {
        if let g = groupName, !g.isEmpty { return g }
        return roundName
    }

    // MARK: - Status

    var status: MatchStatus {
        switch statusRaw {
        case "1st_half", "2nd_half", "extratime", "inprogress", "halftime":
            return .live
        case "finished":
            return .finished(short: "FT")
        case "aet":
            return .finished(short: "AET")
        case "penalties":
            return .finished(short: "PEN")
        case "postponed":
            return .postponed
        case "cancelled":
            return .cancelled
        default:
            return .upcoming  // notstarted, tbd, unknown
        }
    }

    var isLive: Bool     { if case .live = status { return true }; return false }
    var isUpcoming: Bool { if case .upcoming = status { return true }; return false }
    var isFinished: Bool { if case .finished = status { return true }; return false }

    // Compact minute string for display (e.g. "67'", "HT", "ET")
    var elapsedDisplay: String? {
        guard isLive else { return nil }
        if statusRaw == "halftime" || period == "halftime" { return "HT" }
        if let min = currentMinute { return "\(min)'" }
        switch period {
        case "extra_time": return "ET"
        case "1st_half":   return "1H"
        case "2nd_half":   return "2H"
        default:           return nil
        }
    }

    // "FT", "AET", or "PEN"
    var finishedLabel: String? {
        guard case .finished(let short) = status else { return nil }
        return short
    }
}

// MARK: - Nested types

struct PenaltyShootout: Decodable {
    let home: Int
    let away: Int
}

struct ExtraTimeScore: Decodable {
    let home: Int
    let away: Int
}

// MARK: - Status enum

enum MatchStatus {
    case upcoming
    case live
    case finished(short: String)  // "FT", "AET", "PEN"
    case postponed
    case cancelled
}

// MARK: - League discovery types

struct LeagueListItem: Decodable {
    let id: Int
    let name: String
    let isActive: Bool
    let currentSeason: SeasonSummary?

    enum CodingKeys: String, CodingKey {
        case id, name
        case isActive       = "is_active"
        case currentSeason  = "current_season"
    }
}

struct SeasonSummary: Decodable {
    let id: Int
    let name: String
}
