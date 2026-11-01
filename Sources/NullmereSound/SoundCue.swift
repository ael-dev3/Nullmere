// The game's sound, all of it made as it plays: a cold drone and the
// night wind over the still water, the score, and the cues, played in a
// hall of their own. Nothing is recorded or sampled, and none of it needs
// the Mac: it is rendered and measured on Linux too, and the Mac's audio
// engine only asks it for its samples.

import Foundation

/// Where a sound is heard from: across the view, -1 its left edge to 1 its
/// right, and how loud for how far off it lies. Each ear hears it by an
/// equal-power law, a sound in the middle at its full in both, one at the
/// edge leaning well into the nearer ear but never gone from the other.
public struct SoundPlace: Equatable, Sendable {
    public var pan: Float
    public var gain: Float

    public init(pan: Float, gain: Float) {
        self.pan = min(max(pan, -1), 1)
        self.gain = min(max(gain, 0), 1)
    }

    /// The middle of the view: orders, the watch's bell, what has no place.
    public static let middle = SoundPlace(pan: 0, gain: 1)

    private var angle: Float { (0.75 * pan + 1) * .pi / 4 }

    public var left: Float { Float(2).squareRoot() * cos(angle) * gain }
    public var right: Float { Float(2).squareRoot() * sin(angle) * gain }
}

/// What the game sounds: each order, happening and gesture its own.
public enum SoundCue: Sendable {
    /// Something chosen on the map.
    case select
    /// A company given its march.
    case order
    /// The watch turns: a low bell over the water.
    case watch
    /// Something raised: a hold founded, a work or a company ordered,
    /// and each finished.
    case rise
    /// War begun, a hold or a company lost, hunger.
    case dread
    /// An envoy at the gate: a soft call of two notes.
    case envoy
    /// A hold taken: a rising triad.
    case triumph
    /// Peace or a pact: a gentle sixth.
    case accord
    /// A House destroyed: a deep, long toll.
    case toll
    /// Steel meeting steel: a company strikes in close, or is struck.
    case clash
    /// A bowstring loosed, by a company or at one.
    case loose
    /// Riders sent off: hooves on hard ground.
    case ride
    /// A company digging in: two spades into stony earth.
    case dig
    /// Goods and gifts changing hands: a few coins counted out.
    case coin
    /// An envoy sent: a soft reed call that rises, asking.
    case parley
    /// A company halted or sent home: a drum's two strokes, the second softer.
    case stand
    /// A work finished: the last knocks of the mallet, and a bright chord.
    case complete
    /// Companies mustered and ready: a horn's call, rising.
    case muster
    /// An offer refused: two soft notes falling.
    case refusal
    /// A hold's walls battered: a heavy blow on timber and stone.
    case batter
    /// A study finished: glass bells rising, one after another.
    case lore
    /// A war horn: a rally called or setting out, a commander's skill.
    case horn
    /// Two stately chords: an alliance founded, joined or led.
    case banner
    /// The realm's crier: drums, then a bell, as a happening begins or ends.
    case herald
    /// A bright fanfare: a deed done, a charge kept, a commander risen.
    case honour
    /// The healers at work: a small bell over a warm, low hum, as the
    /// fallen are carried in and their healing paid for.
    case tend
    /// Salt running through an hourglass, then a small glass chime: an
    /// hourglass turned to hasten what is under way.
    case sift
    /// The smith's hammer on the anvil, three bright blows, the last
    /// left to ring: gear forged.
    case anvil
    /// A panel opened: a leaf turned, a brush of paper and a faint high note.
    case leaf
    /// A panel closed, or the keeper stepping back: the leaf laid down,
    /// lower and softer.
    case fold
    /// An order the rules refuse: two muted knocks on wood, the second lower.
    case deny

    /// Every cue, for tests and previews.
    public static let all: [SoundCue] = [.select, .order, .watch, .rise, .dread, .envoy, .triumph, .accord, .toll,
                                         .clash, .loose, .ride, .dig, .coin, .parley, .stand, .complete, .muster,
                                         .refusal, .batter, .lore, .horn, .banner, .herald, .honour, .tend, .sift, .anvil,
                                         .leaf, .fold, .deny]
}
