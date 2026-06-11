import SwiftUI

struct GroupTablesView: View {
    @Environment(MatchTracker.self) private var tracker

    private let columns = [GridItem(.adaptive(minimum: 300, maximum: 460), spacing: 16)]

    var body: some View {
        let standings = tracker.groupStandings
        Group {
            if standings.isEmpty {
                ContentUnavailableView(
                    "No Standings Yet",
                    systemImage: "tablecells",
                    description: Text("Group standings appear once group-stage matches have been scheduled.")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                        ForEach(standings) { GroupCard(standing: $0) }
                    }
                    .padding()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Group card

private struct GroupCard: View {
    let standing: GroupStanding

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(standing.groupName)
                .font(.callout.bold())

            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
                GridRow {
                    Text("Team")
                        .gridColumnAlignment(.leading)
                    headerCell("P")
                    headerCell("W")
                    headerCell("D")
                    headerCell("L")
                    headerCell("GF")
                    headerCell("GA")
                    headerCell("Pts")
                }
                .font(.caption2.bold())
                .foregroundStyle(.secondary)

                Divider()
                    .gridCellColumns(8)

                ForEach(standing.teams) { team in
                    GridRow {
                        HStack(spacing: 5) {
                            Text(team.flag)
                            Text(team.abbreviation)
                                .font(.caption.monospaced())
                        }
                        .gridColumnAlignment(.leading)
                        numCell(team.played)
                        numCell(team.wins)
                        numCell(team.draws)
                        numCell(team.losses)
                        numCell(team.goalsFor)
                        numCell(team.goalsAgainst)
                        Text("\(team.points)")
                            .font(.caption.bold())
                            .monospacedDigit()
                            .frame(minWidth: 22, alignment: .trailing)
                            .gridColumnAlignment(.trailing)
                    }
                }
            }
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }

    private func headerCell(_ label: String) -> some View {
        Text(label)
            .frame(minWidth: 22, alignment: .trailing)
            .gridColumnAlignment(.trailing)
    }

    private func numCell(_ value: Int) -> some View {
        Text("\(value)")
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .frame(minWidth: 22, alignment: .trailing)
            .gridColumnAlignment(.trailing)
    }
}

#Preview {
    GroupTablesView()
        .environment(MatchTracker())
}
