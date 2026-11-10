import AppKit
import LauncherKit
import NullmereCore
import SwiftUI

/// The Houses named over their land as the view draws away from the holds
/// to take in the country, as a kingdom's map names its cities from afar
/// (Rise of Kingdoms' kingdom map): each House whose seat the keeper has
/// seen, its name on a dark plate at its seat, marked in its colour and by
/// how it stands to the keeper's own; fading in as the holds' own names go.
/// Where names would crowd, the keeper's own House, its alliance's and its
/// foes' are set down first and the rest give way; never one over another,
/// and never more than a few at once.
///
/// Set as the interface's own words over the world rather than drawn in the
/// marks' canvas, which draws itself anew every frame while anything
/// marches: these change only as the view moves or the realm does.
struct HouseNamesAfar: View {
    let session: GameSession

    /// How fully the names show at a scale: none while the holds are named
    /// themselves (from 18 points a hex), all of them three points further out.
    static func shown(at scale: Double) -> Double {
        min(max((18 - scale) / 3, 0), 1)
    }

    /// The most Houses named at once.
    static let limit = 16

    /// A House's name as set down: where and what.
    struct Plate: Identifiable, Equatable {
        var id: Int { house }
        let house: Int
        let title: String
        let standing: NamedAfar.Standing
        /// Its frame on the map, in points.
        let frame: CGRect
    }

    var body: some View {
        GeometryReader { proxy in
            let shown = HouseNamesAfar.shown(at: session.camera.scale)
            if shown > 0 {
                ZStack(alignment: .topLeading) {
                    ForEach(HouseNamesAfar.plates(for: session, in: proxy.size)) { plate in
                        HousePlate(plate: plate, colour: Palette.house(session.state.houses[plate.house]))
                            .position(x: plate.frame.midX, y: plate.frame.midY)
                    }
                }
                .opacity(shown)
            }
        }
        .allowsHitTesting(false)
        // The map's own items tell VoiceOver whose each hold is.
        .accessibilityHidden(true)
    }
}

extension HouseNamesAfar {
    /// The names set down over the map as it stands: the Houses the keeper
    /// has seen in the order `GameState.namedFromAfar` gives (own, allies,
    /// foes, the rest, the nearest the view's heart first), each beneath its
    /// seat or, where that would cover a name of the land, above it; none
    /// over another, and no more than `limit`.
    @MainActor
    static func plates(for session: GameSession, in size: CGSize) -> [Plate] {
        let state = session.state
        let bounds = CGRect(origin: .zero, size: size)
        let named = state.namedFromAfar(by: session.player, around: session.camera.centreHex)
        var offered: [(name: NamedAfar, title: String, places: [CGRect])] = []
        for name in named {
            let seat = session.viewPoint(of: name.seat, in: size)
            // Off the map by more than a name's breadth: not measured at all.
            guard bounds.insetBy(dx: -120, dy: -40).contains(seat) else { continue }
            let title = state.houses[name.house].name.uppercased()
            let plate = HouseNamesAfar.size(of: title)
            let below = CGRect(x: seat.x - plate.width / 2, y: seat.y + 9, width: plate.width, height: plate.height)
            let above = below.offsetBy(dx: 0, dy: -(plate.height + 24))
            offered.append((name, title, [below, above]))
        }
        let landNames = state.atlas.map { atlas in
            WorldMarks.landFrames(atlas, scale: session.camera.scale, size: size) { hex in session.viewPoint(of: hex, in: size) }
        } ?? []
        return place(offered.map { $0.places }, within: bounds, around: landNames, limit: limit).map { chosen in
            let offer = offered[chosen.index]
            return Plate(house: offer.name.house, title: offer.title, standing: offer.name.standing, frame: chosen.frame)
        }
    }

    /// Where names are set down, in the order offered: for each, the first
    /// of its places that lies on the map and clear of every name set down
    /// before it and of `around` (names drawn beneath, which it would
    /// rather not cover); failing that, the first clear of the names set
    /// down alone; none at all where each of its places falls on one, nor
    /// once `limit` are set down.
    static func place(_ offered: [[CGRect]], within bounds: CGRect, around: [CGRect] = [], limit: Int) -> [(index: Int, frame: CGRect)] {
        var set: [(index: Int, frame: CGRect)] = []
        for (index, places) in offered.enumerated() {
            guard set.count < limit else { break }
            let open = places.filter { place in bounds.intersects(place) && !set.contains { $0.frame.intersects(place) } }
            if let frame = open.first(where: { place in !around.contains { $0.intersects(place) } }) ?? open.first {
                set.append((index, frame))
            }
        }
        return set
    }

    /// The lettering a name is set in: its size and spacing.
    @MainActor
    static var lettering: (size: CGFloat, tracking: CGFloat) { (TextSize.shared.size(9.5), 1.8) }

    /// A plate's size about a name: its words in their type and spacing, a
    /// mark before them, and its margins.
    @MainActor
    static func size(of title: String) -> CGSize {
        let lettering = HouseNamesAfar.lettering
        let words = SetWords.size(of: title, points: lettering.size, weight: .medium, tracking: lettering.tracking)
        return CGSize(width: ceil(words.width) + 8 + 5 + 14, height: ceil(max(words.height, lettering.size * 1.2)) + 6)
    }
}

/// Words measured as they are set, each kept once measured: the names over
/// the map are measured again each time the view moves.
@MainActor
enum SetWords {
    private static var kept: [String: CGSize] = [:]

    /// The size of `words` set in the system's type at `points` and
    /// `weight`, `tracking` apart.
    static func size(of words: String, points: CGFloat, weight: NSFont.Weight, tracking: CGFloat = 0) -> CGSize {
        let key = "\(points)|\(weight.rawValue)|\(tracking)|\(words)"
        if let size = kept[key] { return size }
        let size = NSAttributedString(string: words, attributes: [.font: NSFont.systemFont(ofSize: points, weight: weight),
                                                                  .kern: tracking]).size()
        // Names are few, but sizes chosen anew would keep them all.
        if kept.count >= 4_096 { kept.removeAll() }
        kept[key] = size
        return size
    }
}

/// One House's name over its land: on a dark plate edged in its colour, a
/// mark before it that says how it stands to the keeper's House in shape as
/// well as colour (a banner for the keeper's own, a ring for an ally, a
/// cross for a foe at war, a bar for the rest).
private struct HousePlate: View {
    let plate: HouseNamesAfar.Plate
    let colour: Color

    var body: some View {
        let own = plate.standing == .own
        HStack(spacing: 5) {
            Canvas { context, size in
                context.stroke(HousePlate.mark(plate.standing, in: CGRect(origin: .zero, size: size)), with: .color(colour), lineWidth: 1.4)
                if own { context.fill(HousePlate.mark(.own, in: CGRect(origin: .zero, size: size)), with: .color(colour)) }
            }
            .frame(width: 8, height: 8)
            Text(verbatim: plate.title)
                .font(.system(size: HouseNamesAfar.lettering.size, weight: .medium))
                .tracking(HouseNamesAfar.lettering.tracking)
                .foregroundStyle(Palette.text(own ? 0.96 : 0.84))
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .frame(width: plate.frame.width, height: plate.frame.height)
        .background(RoundedRectangle(cornerRadius: 2).fill(Color.black.opacity(0.62)))
        .overlay(RoundedRectangle(cornerRadius: 2).stroke(colour.opacity(own ? 0.9 : 0.5), lineWidth: 1))
    }

    /// The mark for a standing, drawn within `r`.
    static func mark(_ standing: NamedAfar.Standing, in r: CGRect) -> Path {
        var p = Path()
        switch standing {
        case .own:
            // A pennant on its staff.
            p.move(to: CGPoint(x: r.minX + 1, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX + 1, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.3))
            p.addLine(to: CGPoint(x: r.minX + 1, y: r.minY + r.height * 0.6))
            p.closeSubpath()
        case .allied:
            p.addEllipse(in: r.insetBy(dx: 1, dy: 1))
        case .atWar:
            p.move(to: CGPoint(x: r.minX + 1, y: r.minY + 1))
            p.addLine(to: CGPoint(x: r.maxX - 1, y: r.maxY - 1))
            p.move(to: CGPoint(x: r.maxX - 1, y: r.minY + 1))
            p.addLine(to: CGPoint(x: r.minX + 1, y: r.maxY - 1))
        case .other:
            p.move(to: CGPoint(x: r.midX, y: r.minY))
            p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        }
        return p
    }
}
