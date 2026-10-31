import NullmereCore
import NullmereModels
import NullmereWorld
import SwiftUI

/// A work of a hold seen close: what it is, and where it stands in the view.
struct CityWork: Identifiable, Equatable {
    let kind: BuildingKind
    let level: Int
    /// Being raised to this level.
    let rising: Bool
    let at: CGPoint

    var id: BuildingKind { kind }

    /// Its name and level as the view shows it: "Granary II".
    var title: String {
        "\(kind.title) \(Narration.roman(level))" + (rising ? ", rising" : "")
    }
}

extension GameSession {
    /// How close the city view comes over a hold, and how far it leans in.
    static let cityScale = 165.0
    static let cityTilt = 0.86
    /// How close the view stands over the lake as a world opens.
    static let lakeScale = 28.0
    /// How near the camera comes before the models' fine work is drawn:
    /// twice the lake's view, where a keep's quoins are a point across.
    static let fineScale = 56.0

    /// The city view, as RoK's: the view close over one of the keeper's
    /// holds (the seat unless another is named), leaning in, the hold
    /// chosen and its works named where they stand.
    func viewCity(_ holdID: Int? = nil) {
        guard let hold = holdID.flatMap({ state.hold($0) }) ?? state.seat(of: player), hold.owner == player else { return }
        selection = .hold(hold.id)
        glide(to: hold.position, scale: GameSession.cityScale, tilt: GameSession.cityTilt)
    }

    /// From the city view back out over the lake, as the view first stood.
    func leaveCity() {
        workInFocus = nil
        glide(to: camera.centreHex, scale: GameSession.lakeScale, tilt: Camera.defaultTilt)
    }

    /// The key's way: into the city view, or out of it.
    func toggleCity() {
        if cityInView != nil { leaveCity() } else { viewCity() }
    }

    /// The keeper's hold the view is close over, if it is.
    var cityInView: Hold? {
        guard camera.scale >= GameSession.cityScale * 0.7 else { return nil }
        let centre = camera.centreHex
        return state.holds(of: player)
            .filter { $0.position.distance(to: centre) <= 1 }
            .min { ($0.position.distance(to: centre), $0.id) < ($1.position.distance(to: centre), $1.id) }
    }

    /// The works of the hold the view is close over, each where it stands
    /// in a view of `size`, a little over its roof; a work being raised at
    /// the level it rises to.
    func cityWorks(in size: CGSize) -> [CityWork] {
        guard let hold = cityInView else { return [] }
        if stage == nil { stage = WorldStage(map: state.map, relief: relief) }
        guard let stage else { return [] }
        var works: [CityWork] = []
        for piece in stage.pieces(of: hold, progress: nil, heritage: state.heritage(of: hold.owner)) {
            let kind: BuildingKind, level: Int
            switch piece.key {
            case .work(let work, let at):
                kind = work
                level = at
            case .study(let at):
                kind = .archive
                level = at
            case .walls(let at):
                kind = .walls
                level = at
            default:
                continue
            }
            let top = piece.position.y + Library.model(piece.key).mesh.bounds.max.y + 0.08
            let at = camera.viewPoint(worldX: Double(piece.position.x), worldY: Double(piece.position.z), height: Double(top), in: size)
            works.append(CityWork(kind: kind, level: level, rising: hold.project?.kind == kind, at: at))
        }
        return works
    }

    /// A work of the hold in view, chosen from its name over it: the hold's
    /// panel opens on its row.
    func focus(work kind: BuildingKind, at hold: Hold) {
        selection = .hold(hold.id)
        workInFocus = kind
    }
}

/// The city view's own marks: each work of the hold in view named over
/// it, a click on the name taking the hold's panel to its row, and the way
/// back out to the lake. Nothing while the view is over the lake.
struct CityLabels: View {
    let session: GameSession

    var body: some View {
        GeometryReader { proxy in
            if let hold = session.cityInView {
                ZStack(alignment: .topLeading) {
                    ForEach(session.cityWorks(in: proxy.size)) { work in
                        Button {
                            session.focus(work: work.kind, at: hold)
                        } label: {
                            Text(verbatim: work.title)
                                .font(.nm(10.5, weight: .medium))
                                .foregroundStyle(Palette.text(0.92))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.black.opacity(0.62)))
                                .overlay(Capsule().stroke(session.workInFocus == work.kind ? Palette.glow : Palette.line(0.3), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(work.title) at \(hold.name)")
                        .position(work.at)
                    }
                    QuietButton(title: "Back to the lake", size: 9.5, name: "Back to the lake from \(hold.name)") {
                        session.leaveCity()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.black.opacity(0.55)))
                    .position(x: proxy.size.width / 2, y: 64)
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("\(hold.name), close")
            }
        }
    }
}
