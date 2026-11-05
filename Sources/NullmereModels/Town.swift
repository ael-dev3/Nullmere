import Foundation
import NullmereCore

/// The town about a hold (see `HoldLayout.town`): the homes of its folk,
/// their windows lit at night; the lanes between its works; its well, its
/// fields and, at a seat, its market. Made in Blender (Art/blender/town.py,
/// read by Art.town) of stone, timber, thatch and slate, which the stage
/// gives the hold's people's colours, each home's door in its House's
/// colour. Small and lean, for a hold has dozens; each faces +z, toward the
/// lane it stands on, and stands on y = 0.
public enum Town: String, CaseIterable, Sendable {
    /// A small home, whitewashed under a steep thatch.
    case cottage
    /// A long low home of weathered planks under thatch, its woodpile at
    /// the gable.
    case longhouse
    /// A tall home of two storeys, stone below and timber-framed above,
    /// under slate.
    case townhouse
    /// A round home of wattle under a cone of thatch.
    case roundhouse
    /// The ward's well: a ring of stone, a windlass under a little roof.
    case well
    /// A strip field: ridged furrows of grain, fenced about.
    case field
    /// A length of lane, a unit long from x = -0.5 to 0.5: trodden earth
    /// with flat stones set in it, stretched to the length it runs.
    case lane
    /// A stall at a seat's market, its awning in the House's colour.
    case stall

    /// The homes, for the town's lots.
    public static let homes: [Town] = [.cottage, .longhouse, .townhouse, .roundhouse]

    /// How far it reaches from its foot on the ground: within it, nothing
    /// else of the town stands.
    public var footprint: Float {
        switch self {
        case .cottage: return 0.1
        case .longhouse: return 0.13
        case .townhouse: return 0.09
        case .roundhouse: return 0.08
        case .well: return 0.06
        case .field: return 0.22
        case .lane: return 0.06
        case .stall: return 0.07
        }
    }
}
