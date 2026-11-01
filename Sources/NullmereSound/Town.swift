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
        return voices * 0.5 + work * 0.12
    }
}
