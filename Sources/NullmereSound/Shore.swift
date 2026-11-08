import Foundation

/// The lake at its edge, near the view: small waves running up the strand
/// and drawing back, each a swell of low water that rises in a moment and
/// ebbs away slowly, the shingle rattling as the water drains back through
/// it; one comes in every two to five seconds, never on a beat, each a
/// little stronger or weaker than the last; and now and then a drop falls
/// back into the water. Quiet, as the black lake is, beneath the night's
/// wind; it draws on noise of its own, so the night sounds as it did
/// whether the shore is heard or not.
struct Shore {
    let sampleRate: Float
    private var noise = Noise(seed: 0x5A0E_17D3)
    /// The draws that shape each wave and drop, apart from the noise drawn
    /// every sample, so the waves come alike at any sample rate.
    private var chance = Noise(seed: 0x0DD5_EED5)
    /// The noise scaled so the low water sounds as loud at any rate: the
    /// filter passes the same band of it.
    private let loudness: Float
    /// The water's body, low; its wash, about the middle; and the
    /// shingle's rattle, high.
    private var body: Lowpass
    private var wash: Bandpass
    private var rattle: Bandpass
    /// The wave running in: how long since it began, how long it runs, how
    /// strong it is, and how long until the next begins.
    private var age: Float = 0
    private var length: Float = 2.4
    private var strength: Float = 0.7
    private var nextWave: Float = 0
    /// A drop falling back into the water: a short ring rising in pitch as
    /// the bubble it leaves closes.
    private var drop: (phase: Float, frequency: Float, age: Float, amplitude: Float) = (0, 0, 9, 0)
    private var nextDrop: Float = 1.3
    /// How many waves have come in, and drops fallen, for tests.
    private(set) var waves = 0
    private(set) var drops = 0
    /// The shortest and longest time between two waves, for tests.
    private(set) var gaps: (shortest: Float, longest: Float) = (.infinity, 0)

    /// How fast a wave washes up the strand, in seconds.
    static let rise: Float = 0.4

    init(sampleRate: Float) {
        self.sampleRate = sampleRate
        loudness = (sampleRate / 48_000).squareRoot()
        body = Lowpass(corner: 380, resonance: 0.6, sampleRate: sampleRate)
        wash = Bandpass(centre: 850, width: 0.9, sampleRate: sampleRate)
        rattle = Bandpass(centre: 3_600, width: 1.3, sampleRate: sampleRate)
    }

    /// A draw from 0 to 1.
    private mutating func draw() -> Float { 0.5 + 0.5 * chance.next() }

    /// The next wave: how strong and how long, and when the one after.
    private mutating func begin() {
        strength = 0.5 + 0.5 * draw()
        length = 1.8 + 1.6 * draw()
        let gap = length + 0.2 + 1.4 * draw()
        if waves > 0 { gaps = (min(gaps.shortest, age), max(gaps.longest, age)) }
        age = 0
        nextWave = gap
        waves += 1
    }

    /// The shore's next sample, at full; the synthesiser sets how near.
    @inline(__always)
    mutating func sample(dt: Float) -> Float {
        age += dt
        nextWave -= dt
        if nextWave <= 0 { begin() }
        // The wash: up the strand in a moment, back over a second or more.
        var swell: Float = 0
        var draining: Float = 0
        if age < Shore.rise {
            swell = sin(age / Shore.rise * .pi / 2)
        } else if age < length {
            let back = 1 - (age - Shore.rise) / (length - Shore.rise)
            swell = back * back
            // The shingle rattles most as the water drains through it,
            // between the crest and the wave's end.
            draining = 4 * back * (1 - back)
        }
        let water = noise.next()
        var sound = (body.process(water * loudness) * 2.4 + wash.process(water) * 0.35) * swell * strength
        sound += rattle.process(noise.next()) * 0.22 * draining * strength
        nextDrop -= dt
        if nextDrop <= 0 {
            drop = (0, 900 + 500 * draw(), 0, 0.12 + 0.1 * draw())
            nextDrop = 1.5 + 3 * draw()
            drops += 1
        }
        if drop.age < 0.12 {
            drop.age += dt
            drop.frequency *= 1 + dt * 9
            drop.phase += 2 * .pi * drop.frequency * dt
            if drop.phase > 2 * .pi { drop.phase -= 2 * .pi }
            sound += sin(drop.phase) * drop.amplitude * exp(-drop.age * 45) * min(drop.age * 2_000, 1)
        }
        return sound
    }
}
