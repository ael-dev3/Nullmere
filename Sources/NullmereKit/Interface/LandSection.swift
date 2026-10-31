import NullmereCore
import SwiftUI

/// The land's legend in the Realm panel: the streams that run from the
/// Spine to the lake, and the regions of the shores between them, each
/// with the streams that bound it and whose holds stand in it. Folded until
/// asked for.
struct LandSection: View {
    let session: GameSession
    @AppStorage(LandSection.openKey) private var open = false

    static let openKey = "land.open"

    /// A region as the legend tells it.
    struct Row: Equatable {
        let name: String
        let line: String
    }

    var body: some View {
        if let atlas = session.state.atlas, !atlas.regions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Caps("The land", size: 9, weight: .medium).foregroundStyle(Palette.text(0.7)).accessibilityAddTraits(.isHeader)
                    Spacer()
                    QuietButton(title: open ? "Fold the regions" : "Show the regions", size: 9) { open.toggle() }
                }
                Text(verbatim: LandSection.summary(atlas))
                    .font(.nm(10.5))
                    .foregroundStyle(Palette.text(0.6))
                    .fixedSize(horizontal: false, vertical: true)
                if open {
                    ForEach(LandSection.rows(session.state, regions: session.regions(), player: session.player), id: \.name) { row in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: row.name).font(.nm(11, weight: .medium)).foregroundStyle(Palette.text(0.88))
                            Text(verbatim: row.line)
                                .font(.nm(10))
                                .foregroundStyle(Palette.text(0.6))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    /// The streams, named, and how many regions lie between them.
    static func summary(_ atlas: Atlas) -> String {
        let names = atlas.rivers.map(\.name)
        let streams = names.count == 1 ? "One stream runs" : "\(LandSection.spelled(names.count).capitalized) streams run"
        let regions = atlas.regions.count == 1 ? "one region" : "\(LandSection.spelled(atlas.regions.count)) regions"
        return "\(streams) from the Spine down to the lake, crossed at their shoals: \(SeatBriefing.list(names)). "
            + "Between them lie \(regions) of the shores."
    }

    /// A count of streams or regions in words, as the legend says it.
    static func spelled(_ n: Int) -> String {
        let words = ["no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve"]
        return words.indices.contains(n) ? words[n] : "\(n)"
    }

    /// Each region: the streams that bound it, and whose holds stand in it.
    static func rows(_ state: GameState, regions: [Int?], player: Int) -> [Row] {
        guard let atlas = state.atlas else { return [] }
        func region(of hex: Hex) -> Int? {
            guard let index = state.map.index(of: hex), regions.indices.contains(index) else { return nil }
            return regions[index]
        }
        return atlas.regions.indices.map { number in
            let bounds = atlas.rivers.filter { river in
                river.course.contains { hex in state.map.neighbors(of: hex).contains { region(of: $0) == number } }
            }.map(\.name)
            var parts: [String] = []
            if !bounds.isEmpty { parts.append("by \(SeatBriefing.list(bounds))") }
            var held: [Int: Int] = [:]
            for hold in state.holds where region(of: hold.position) == number { held[hold.owner, default: 0] += 1 }
            let mine = held[player] ?? 0
            if mine > 0 { parts.append(mine == 1 ? "1 hold of yours" : "\(mine) holds of yours") }
            if let most = held.filter({ $0.key != player }).max(by: { ($0.value, $1.key) < ($1.value, $0.key) }),
               state.houses.indices.contains(most.key) {
                parts.append(most.value == 1 ? "1 hold of \(state.houses[most.key].title)"
                                             : "\(most.value) holds of \(state.houses[most.key].title)")
            }
            if held.isEmpty { parts.append("no hold raised") }
            return Row(name: atlas.regions[number].name.prefix(1).uppercased() + atlas.regions[number].name.dropFirst(),
                       line: parts.joined(separator: " · "))
        }
    }
}
