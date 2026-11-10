import NullmereCore
import SwiftUI

/// The regions of the shores and the streams between them named over the
/// land, as a map of it would name them, while the view takes in the
/// country rather than its holds (`WorldMarks.landNames`).
///
/// Set as the interface's own words over the world, as the Houses' names
/// from afar are, rather than drawn in the marks' canvas, which draws
/// itself anew every frame while anything marches: these change only as
/// the view moves.
struct LandNames: View {
    let session: GameSession

    /// A name set over the land: what it says, whether a region's or a
    /// stream's, and where it stands, in points.
    struct Name: Identifiable, Equatable {
        enum Kind: Equatable { case region, stream }
        let id: String
        let words: String
        let kind: Kind
        let at: CGPoint
    }

    var body: some View {
        GeometryReader { proxy in
            let shown = WorldMarks.landNames(at: session.camera.scale)
            if shown > 0, let atlas = session.state.atlas {
                ZStack(alignment: .topLeading) {
                    ForEach(LandNames.names(atlas, in: proxy.size) { hex in session.viewPoint(of: hex, in: proxy.size) }) { name in
                        LandName(name: name, shown: shown)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        // The tile's record and the Realm panel's regions say them.
        .accessibilityHidden(true)
    }

    /// The names over the land as the view stands: each region's at its
    /// heart, each stream's above the middle of its course; none whose
    /// place lies off the map by more than a name's breadth.
    static func names(_ atlas: Atlas, in size: CGSize, point: (Hex) -> CGPoint) -> [Name] {
        func onScreen(_ p: CGPoint) -> Bool { p.x > -80 && p.y > -20 && p.x < size.width + 80 && p.y < size.height + 20 }
        var names: [Name] = []
        for (index, region) in atlas.regions.enumerated() {
            let at = point(region.heart)
            guard onScreen(at) else { continue }
            names.append(Name(id: "region-\(index)", words: region.name.uppercased(), kind: .region, at: at))
        }
        for (index, river) in atlas.rivers.enumerated() where !river.course.isEmpty {
            let at = point(river.course[river.course.count / 2])
            guard onScreen(at) else { continue }
            names.append(Name(id: "stream-\(index)", words: river.name, kind: .stream, at: CGPoint(x: at.x, y: at.y - 10)))
        }
        return names
    }
}

/// One name over the land, over its dark shadow a hair below: a region's
/// in light, widely spaced capitals; a stream's in light italics.
private struct LandName: View {
    let name: LandNames.Name
    let shown: Double

    var body: some View {
        let region = name.kind == .region
        let words: Text = region
            ? Text(verbatim: name.words).font(.nm(11, weight: .light)).tracking(3.4)
            : Text(verbatim: name.words).font(.nm(9.5, weight: .light)).italic()
        ZStack {
            words.foregroundStyle(Color.black.opacity(0.7 * shown))
                .offset(x: 1, y: 1)
            words.foregroundStyle(region ? Palette.text(0.62 * shown) : Palette.glowWords.opacity(0.7 * shown))
        }
        .fixedSize()
        .position(name.at)
    }
}
