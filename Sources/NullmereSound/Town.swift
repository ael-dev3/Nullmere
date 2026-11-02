import Foundation

/// The sound of the towns near the view: their people talking, two
/// murmurs of voices that rise and fall syllable by syllable, each through
/// a voice's two lowest formants, the vowels changing as the talk goes;
/// and their work, now and then a mallet or a smith's hammer on something
/// hard, each blow two struck modes and its click. Quiet, beneath the
/// night's wind, and only as near as the view comes; it draws on noise of
/// its own, so the night sounds as it did whether a town is heard or not.
struct Town {
    /// One voice of the murmur: its syllables' swell, and the two bands
    /// its vowel sounds in.
    private struct Talker {
        var swell: Float = 0
        var goal: Float = 0
        var clock: Float = 0
        var first = Bandpass()
        var second = Bandpass()
    }

    let sampleRate: Float
    private var noise = Noise(seed: 0x70E7_1A2B)
    private var talkers = [Talker(), Talker()]
    private var blow = (Resonator(), Resonator())
    private var click: Float = 0
    private var nextBlow: Float = 1.5
    /// How many blows have fallen, for tests.
    private(set) var blows = 0
    /// How much of the town heard is sawpits at work, 0 to 1: a two-man
    /// pit-saw's rasp, each stroke a swell of grit through the teeth.
    var sawing: Float = 0
    private var stroke: Float = 0
    private var rasp = Bandpass()
    private var raspSet = false
    /// How much of the town heard is masons at work, 0 to 1: a chisel's
    /// taps under the mallet, quick and uneven, ringing on stone.
    var chiselling: Float = 0
    private var tap = Resonator()
    private var nextTap: Float = 0.2
    /// How many taps have fallen, for tests.
    private(set) var taps = 0

    init(sampleRate: Float) {
        self.sampleRate = sampleRate
        for index in talkers.indices { speak(index) }
    }

    /// A talker's next syllable: how loud, how long, and its vowel.
    private mutating func speak(_ index: Int) {
        let draw = { (noise: inout Noise) in 0.5 + 0.5 * noise.next() }
        talkers[index].goal = draw(&noise) < 0.25 ? 0 : 0.3 + 0.7 * draw(&noise)
        talkers[index].clock = 0.12 + 0.22 * draw(&noise)
        // A voice's first formant from about 350 to 750 hertz, its second
        // from 900 to 2,000: the vowels of speech.
        talkers[index].first = Bandpass(centre: 350 + 400 * draw(&noise), width: 1.6, sampleRate: sampleRate)
        talkers[index].second = Bandpass(centre: 900 + 1_100 * draw(&noise), width: 2.4, sampleRate: sampleRate)
    }

    /// The town's next sample, at full; the synthesiser sets how near.
    @inline(__always)
    mutating func sample(dt: Float) -> Float {
        var voices: Float = 0
        for index in talkers.indices {
            talkers[index].clock -= dt
            if talkers[index].clock <= 0 { speak(index) }
            // Each syllable swells in and dies away over a few hundredths.
            talkers[index].swell += (talkers[index].goal - talkers[index].swell) * min(dt * 30, 1)
            let breath = noise.next()
            voices += (talkers[index].first.process(breath) + 0.5 * talkers[index].second.process(breath)) * talkers[index].swell
        }
        nextBlow -= dt
        if nextBlow <= 0 {
            let strength = 0.4 + 0.3 * (1 + noise.next())
            let pitch = 1_000 + 300 * noise.next()
            blow = (Resonator(frequency: pitch, amplitude: strength, decay: 30, sampleRate: sampleRate),
                    Resonator(frequency: pitch * 2.31, amplitude: strength * 0.5, decay: 45, sampleRate: sampleRate))
            click = strength
            nextBlow = 1.2 + 1.4 * (1 + noise.next())
            blows += 1
        }
        click *= 1 - min(dt * 400, 1)
        let work = blow.0.next() + blow.1.next() + noise.next() * click * 0.3
        return voices * 0.5 + work * 0.12 + saw(dt: dt) * 0.1 + chisel(dt: dt) * 0.1
    }

    /// The pit-saw's rasp: strokes a little over one a second, the down
    /// stroke biting harder than the up.
    @inline(__always)
    mutating func saw(dt: Float) -> Float {
        guard sawing > 0.001 else { return 0 }
        if !raspSet {
            rasp = Bandpass(centre: 2_400, width: 1.2, sampleRate: sampleRate)
            raspSet = true
        }
        stroke += dt * 1.15
        if stroke >= 1 { stroke -= 1 }
        let phase = stroke < 0.5 ? stroke * 2 : (stroke - 0.5) * 2
        let bite: Float = stroke < 0.5 ? 1 : 0.55
        let swell = Float(sin(Double(phase) * .pi)) * bite
        return rasp.process(noise.next()) * swell * sawing
    }

    /// The masons' chisels: taps a fifth to a half of a second apart,
    /// each a bright ring on stone that dies in a few hundredths.
    @inline(__always)
    mutating func chisel(dt: Float) -> Float {
        guard chiselling > 0.001 else { return 0 }
        nextTap -= dt
        if nextTap <= 0 {
            let strength = 0.5 + 0.25 * (1 + noise.next())
            tap = Resonator(frequency: 3_100 + 500 * noise.next(), amplitude: strength, decay: 70, sampleRate: sampleRate)
            nextTap = 0.2 + 0.15 * (1 + noise.next())
            taps += 1
        }
        return tap.next() * chiselling
    }
}
