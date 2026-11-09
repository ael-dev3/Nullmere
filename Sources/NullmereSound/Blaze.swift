import Foundation

/// The blackwood burning near the view, as it is heard: a low roar that
/// surges and sinks as the fire draws breath, the hiss of sap boiling over
/// it, and the wood crackling, small sharp cracks coming thick and never on
/// a beat, a few loud and most soft, and now and then a branch snapping
/// loud and low. Louder than the night beneath it, close by, as fire is.
/// It draws on noise of its own, so the night sounds as it did whether the
/// fire is heard or not.
struct Blaze {
    let sampleRate: Float
    private var noise = Noise(seed: 0x0B1A_2E5F)
    /// The draws that shape the fire's breath, each crack and each snap,
    /// each kind its own and apart from the noise drawn every sample, so
    /// the fire crackles alike at any sample rate.
    private var breaths = Noise(seed: 0x00B2_EA7E)
    private var crackling = Noise(seed: 0x00C4_ACC1)
    private var snapping = Noise(seed: 0x005A_A9ED)
    /// The noise scaled so the roar sounds as loud at any rate: the filter
    /// passes the same band of it.
    private let loudness: Float
    /// The roar, low; the hiss, high; a crack's ring, bright; a snap's body.
    private var roar: Lowpass
    private var hiss: Bandpass
    private var ring: Bandpass
    private var body: Bandpass
    /// How hard the fire draws, easing toward a new breath every second or two.
    private var surge: Float = 0.8
    private var drawing: Float = 0.8
    private var nextBreath: Float = 0.6
    /// The crack sounding: how long since it began, how long it rings and
    /// how loud; and how long until the next.
    private var crack: (age: Float, length: Float, amplitude: Float) = (1, 0.004, 0)
    private var nextCrack: Float = 0.03
    /// A branch snapping: how long since, how loud; and until the next.
    private var snap: (age: Float, amplitude: Float) = (1, 0)
    private var nextSnap: Float = 1.6
    /// How many cracks and snaps have sounded, for tests.
    private(set) var cracks = 0
    private(set) var snaps = 0
    /// The shortest and longest time between two cracks, for tests.
    private(set) var gaps: (shortest: Float, longest: Float) = (.infinity, 0)
    private var sinceCrack: Float = 0

    /// How many cracks a second the fire gives, on the average, as it draws
    /// hardest.
    static let cracking: Float = 20

    init(sampleRate: Float) {
        self.sampleRate = sampleRate
        loudness = (sampleRate / 48_000).squareRoot()
        roar = Lowpass(corner: 170, resonance: 0.8, sampleRate: sampleRate)
        hiss = Bandpass(centre: 6_500, width: 1.2, sampleRate: sampleRate)
        ring = Bandpass(centre: 2_600, width: 1.4, sampleRate: sampleRate)
        body = Bandpass(centre: 720, width: 1.1, sampleRate: sampleRate)
    }

    /// A draw from 0 to 1.
    private static func draw(_ from: inout Noise) -> Float { 0.5 + 0.5 * from.next() }

    /// The fire's next sample, at full; the synthesiser sets how near.
    @inline(__always)
    mutating func sample(dt: Float) -> Float {
        // The fire's breath: a new pull every second or two, eased toward.
        nextBreath -= dt
        if nextBreath <= 0 {
            drawing = 0.5 + 0.5 * Blaze.draw(&breaths)
            nextBreath = 0.7 + 1.6 * Blaze.draw(&breaths)
        }
        surge += (drawing - surge) * min(dt * 2.5, 1)
        var sound = roar.process(noise.next() * loudness) * 1.7 * surge
        sound += hiss.process(noise.next()) * 0.04 * surge
        // The cracks: thicker as it draws harder, the gaps between them
        // as a fire's are, mostly short and now and then long.
        sinceCrack += dt
        nextCrack -= dt
        if nextCrack <= 0 {
            if cracks > 0 { gaps = (min(gaps.shortest, sinceCrack), max(gaps.longest, sinceCrack)) }
            sinceCrack = 0
            let loud = Blaze.draw(&crackling)
            crack = (0, 0.0015 + 0.005 * Blaze.draw(&crackling), 0.15 + 1.2 * loud * loud * loud)
            let rate = Blaze.cracking * (0.35 + 0.65 * surge)
            nextCrack = max(-log(max(1 - Blaze.draw(&crackling), 0.0001)) / rate, 0.004)
            cracks += 1
        }
        var struck: Float = 0
        if crack.age < crack.length * 8 {
            crack.age += dt
            struck = noise.next() * crack.amplitude * exp(-crack.age / crack.length)
        }
        sound += ring.process(struck) * 0.9
        // Now and then a branch snaps, loud and low, the first instant a
        // click.
        nextSnap -= dt
        if nextSnap <= 0 {
            snap = (0, 0.5 + 0.5 * Blaze.draw(&snapping))
            nextSnap = 1.5 + 4 * Blaze.draw(&snapping)
            snaps += 1
        }
        var split: Float = 0
        if snap.age < 0.2 {
            snap.age += dt
            split = noise.next() * snap.amplitude * exp(-snap.age * 30)
            sound += noise.next() * snap.amplitude * 0.3 * exp(-snap.age * 500)
        }
        sound += body.process(split) * 0.7
        return sound
    }
}
