import Foundation

// MARK: - Model types

struct TeamRecord: Identifiable {
    let teamName: String
    var played = 0
    var wins = 0
    var draws = 0
    var losses = 0
    var goalsFor = 0
    var goalsAgainst = 0

    var id: String { teamName }
    var points: Int { wins * 3 + draws }
    var goalDifference: Int { goalsFor - goalsAgainst }
    var flag: String { Match.flagEmoji(for: teamName) ?? Match.shortName(for: teamName) }
    var abbreviation: String { Match.shortName(for: teamName) }
}

struct GroupStanding: Identifiable {
    let groupName: String
    let teams: [TeamRecord]
    var id: String { groupName }
}

// MARK: - Derivation

extension MatchTracker {
    var groupStandings: [GroupStanding] {
        // Bucket all matches that belong to a group by group name.
        let groupMatches = matches.filter { $0.groupName?.isEmpty == false }
        let byGroup = Dictionary(grouping: groupMatches, by: { $0.groupName! })

        return byGroup.map { group, ms in
            // Seed every team from the full schedule (including upcoming) so
            // all teams show immediately with zeros until they play.
            var records: [String: TeamRecord] = [:]
            for m in ms {
                if records[m.homeTeam] == nil { records[m.homeTeam] = TeamRecord(teamName: m.homeTeam) }
                if records[m.awayTeam] == nil { records[m.awayTeam] = TeamRecord(teamName: m.awayTeam) }
            }

            // Count finished and live matches that have scores available.
            for m in ms {
                guard (m.isFinished || m.isLive),
                      let h = m.homeScoreValue,
                      let a = m.awayScoreValue else { continue }

                var home = records[m.homeTeam]!
                var away = records[m.awayTeam]!

                home.played += 1
                away.played += 1
                home.goalsFor += h
                home.goalsAgainst += a
                away.goalsFor += a
                away.goalsAgainst += h

                if h > a {
                    home.wins += 1
                    away.losses += 1
                } else if h < a {
                    away.wins += 1
                    home.losses += 1
                } else {
                    home.draws += 1
                    away.draws += 1
                }

                records[m.homeTeam] = home
                records[m.awayTeam] = away
            }

            let sorted = records.values.sorted { lhs, rhs in
                if lhs.points != rhs.points { return lhs.points > rhs.points }
                if lhs.goalDifference != rhs.goalDifference { return lhs.goalDifference > rhs.goalDifference }
                if lhs.goalsFor != rhs.goalsFor { return lhs.goalsFor > rhs.goalsFor }
                return lhs.teamName < rhs.teamName
            }

            return GroupStanding(groupName: group, teams: sorted)
        }
        .sorted { $0.groupName < $1.groupName }
    }
}
