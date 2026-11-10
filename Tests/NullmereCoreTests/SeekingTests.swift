import Foundation
import XCTest
@testable import NullmereCore

/// A keeper's search on the land, as Rise of Kingdoms' map search finds the
/// barbarians and resource points: among what the House has seen, the
/// nearest first; and the House's look about a place (counsel's, a
/// commander's word, a reeve's) telling the wilds and the sites it has seen.
final class SeekingTests: XCTestCase {
    /// A keeper's House with the land six tiles about its seat seen, and
    /// nothing of the wilds, sites, lairs, holy sites or finds but what a
    /// test sets down.
    private func world(_ seed: String = "seeking on the land") throws -> (state: GameState, me: Int, seat: Hex) {
        var state = GameState(settings: GameSettings(seedText: seed, houseCount: 4, radius: 16, keepers: 1))
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me)).position
        state.reveal(around: seat, range: 6, for: me)
        state.wilds = []
        state.sites = []
        state.lairs = []
        state.shrines = []
        state.finds = []
        state.sought = nil
        return (state, me, seat)
    }

    private func hex(_ state: GameState, at distance: Int, from origin: Hex, besides taken: [Hex] = []) throws -> Hex {
        try XCTUnwrap(state.map.hexes.first { $0.distance(to: origin) == distance && !taken.contains($0) && state.hold(at: $0) == nil })
    }

    func testTheWildsAreSoughtNearestFirstAmongWhatTheHouseHasSeen() throws {
        var (state, me, seat) = try world()
        let near = try hex(state, at: 2, from: seat)
        let far = try hex(state, at: 5, from: seat)
        let unseen = try XCTUnwrap(state.map.hexes.first { !state.isExplored($0, by: me) })
        state.wilds = [Wild(id: 1, kind: .reavers, level: 3, position: far, raised: 1),
                       Wild(id: 2, kind: .saltwights, level: 1, position: near, raised: 1),
                       Wild(id: 3, kind: .barrowkin, level: 9, position: unseen, raised: 1)]
        XCTAssertEqual(state.seek(.wilds, from: seat, by: me), [near, far], "the nearest first, none on ground the House has not seen")
        XCTAssertEqual(state.seek(.wilds, from: far, by: me), [far, near], "nearest to where the keeper looks from")
        // A keeper's own view holds only the wilds in its sight, and finds those.
        let viewed = state.view(for: me).seek(.wilds, from: seat, by: me)
        XCTAssertEqual(viewed.first, near, "the wilds in sight of the seat")
        XCTAssertTrue(viewed.allSatisfy { [near, far].contains($0) }, "\(viewed)")
        // Struck down, they are sought no more.
        state.wilds = []
        XCTAssertEqual(state.seek(.wilds, from: seat, by: me), [])
        XCTAssertEqual(Seeking.wilds.noneSeen, "Your House has seen none of the wilds standing.")
    }

    func testASiteOfAStoreIsSoughtAmongTheLandsAndItsOwnAlliances() throws {
        var (state, me, seat) = try world()
        let grain = try hex(state, at: 2, from: seat)
        let timber = try hex(state, at: 3, from: seat)
        let yard = try hex(state, at: 4, from: seat)
        state.sites = [Site(id: 1, store: .timber, level: 2, position: timber, found: 1),
                       Site(id: 2, store: .grain, level: 1, position: grain, found: 1),
                       Site(id: 3, store: .timber, level: 1, position: yard, found: 1, alliance: 7)]
        XCTAssertEqual(state.seek(.timber, from: seat, by: me), [timber], "another alliance's yard is that alliance's alone to work")
        XCTAssertEqual(state.seek(.grain, from: seat, by: me), [grain], "only sites of the store sought")
        XCTAssertEqual(state.seek(.stone, from: seat, by: me), [])
        XCTAssertEqual(Seeking.stone.noneSeen, "Your House has seen no site of stone to work.")
        // Sworn to the alliance whose yard it is, the House seeks it too.
        state.alliances = [Alliance(id: 7, name: "the Timber Pact", leader: me, founded: state.watch)]
        XCTAssertEqual(state.seek(.timber, from: seat, by: me), [timber, yard])
        XCTAssertEqual(Seeking.allCases.compactMap(\.store), Resource.allCases, "a search for each store")
    }

    func testLairsHolySitesAndFindsAreSoughtAsTheHouseKnowsThem() throws {
        var (state, me, seat) = try world()
        let a = try hex(state, at: 2, from: seat)
        let b = try hex(state, at: 3, from: seat, besides: [a])
        let c = try hex(state, at: 4, from: seat, besides: [a, b])
        let d = try hex(state, at: 5, from: seat, besides: [a, b, c])
        state.lairs = [Lair(id: 1, kind: .reavers, level: 2, position: c, raised: 1)]
        state.shrines = [Shrine(id: 1, kind: .moonwell, position: a, holder: me), Shrine(id: 2, kind: .stillStone, position: d)]
        state.finds = [Find(id: 1, kind: .hamlet, position: b, name: "Ashby"), Find(id: 2, kind: .barrow, position: d, name: "Grimslow")]
        state.sought = [me: [1]]
        XCTAssertEqual(state.seek(.lairs, from: seat, by: me), [c])
        XCTAssertEqual(state.seek(.shrines, from: seat, by: me), [d], "not one the House holds")
        XCTAssertEqual(state.seek(.finds, from: seat, by: me), [d], "not one its Lanterns have sought")
        XCTAssertEqual(Seeking.finds.sought, "a hamlet or barrow")
        XCTAssertEqual(Seeking.shrines.title, "Holy sites")
    }

    func testTheHousesLookTellsTheWildsAndTheSitesItHasSeen() throws {
        var (state, me, _) = try world()
        // A tile the House has seen beside one it has not, to look out from.
        let (here, dark) = try XCTUnwrap(state.map.hexes.lazy.compactMap { hex -> (Hex, Hex)? in
            guard state.isExplored(hex, by: me), state.hold(at: hex) == nil,
                  let unseen = hex.neighbors.first(where: { state.map[$0] != nil && !state.isExplored($0, by: me) }) else { return nil }
            return (hex, unseen)
        }.first)
        let seen = try XCTUnwrap(here.neighbors.first { $0 != dark && state.isExplored($0, by: me) && state.hold(at: $0) == nil })
        let further = try XCTUnwrap(state.map.hexes.first { $0.distance(to: here) == 2 && state.isExplored($0, by: me) && state.hold(at: $0) == nil })
        state.wilds = [Wild(id: 1, kind: .saltwights, level: 3, position: further, raised: 1),
                       Wild(id: 2, kind: .reavers, level: 5, position: dark, raised: 1)]
        state.sites = [Site(id: 1, store: .timber, level: 2, position: seen, found: 1)]
        let look = state.seen(around: here, by: me, within: 2)
        let wild = "a band of Saltwights from the wilds, the third of ten in strength, \(GameState.waySaid(to: further, from: here))"
        let site = "\(Site.title(of: .timber)), 600 timber to work, \(GameState.waySaid(to: seen, from: here))"
        XCTAssertTrue(look.contains(wild), look.joined(separator: "\n"))
        XCTAssertFalse(look.contains { $0.contains("Blackwood Reavers") }, "none told on ground the House has not seen")
        XCTAssertEqual(look.last, site, "what the land offers to work after all that stands on it, though nearer")
        XCTAssertLessThan(try XCTUnwrap(look.firstIndex(of: wild)), try XCTUnwrap(look.firstIndex(of: site)))
        // The voices keep from saying a level.
        for line in look {
            let words = Set(line.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init))
            XCTAssertTrue(words.isDisjoint(with: ["level", "levels"]), line)
        }
        XCTAssertEqual(Wild(id: 9, kind: .drowned, level: 10, position: here, raised: 1).strengthSaid, "the tenth of ten in strength")
    }
}
