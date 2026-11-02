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
    /// How much of the town heard is a beacon's fire, 0 to 1: its roar,
    /// low, and the crackle of wood splitting in it.
    var burning: Float = 0
    private var roar = Bandpass()
    private var roarSet = false
    private var crack: Float = 0
    /// How many cracks have sounded, for tests.
    private(set) var cracks = 0
    /// How much of the town heard is a granary's threshing floor, 0 to 1:
    /// two flails falling in turn, each a dull thud on the grain.
    var threshing: Float = 0
    private var flail = (Resonator(), Resonator())
    private var nextFlail: Float = 0.3
    private var flailTurn = false
    /// How many flails have fallen, for tests.
    private(set) var flails = 0
    /// How much of the town heard is a quarry at work, 0 to 1: picks and
    /// wedges driven into rock, each blow a dull ring with a scatter of grit.
    var quarrying: Float = 0
    private var pick = Resonator()
    private var grit: Float = 0
    private var nextPick: Float = 0.4
    /// How many blows the picks have struck, for tests.
    private(set) var picks = 0
    /// How much of the town heard is a saltworks, 0 to 1: rakes drawn
    /// through the crust of the pans, a dry hiss stroke after stroke.
    var raking: Float = 0
    private var hiss = Bandpass()
    private var hissSet = false
    private var draw: Float = 0
    /// How much of the town heard is a muster hall at drill, 0 to 1: the
    /// drill drum beating the step, two beats and a rest.
    var drilling: Float = 0
    private var beat = (Resonator(), Resonator())
    private var nextBeat: Float = 0.3
    private var beatInBar = 0
    /// How many beats the drum has struck, for tests.
    private(set) var beats = 0
    /// How much of the town heard is an infirmary at work, 0 to 1: a pestle
    /// grinding herbs in a stone mortar, a soft knock and a turn.
    var grinding: Float = 0
    private var knock = Resonator()
    private var grain = Bandpass()
    private var grainSet = false
    private var turn: Float = 0
    /// How many knocks the pestle has given, for tests.
    private(set) var knocks = 0
    /// How much of the town heard is an archive, 0 to 1: pages turned and
    /// quills scratching, quiet under all the rest.
    var reading: Float = 0
    private var leaf = Bandpass()
    private var leafSet = false
    private var turnLeft: Float = 0
    private var nextLeaf: Float = 0.8
    /// How many pages have turned, for tests.
    private(set) var pages = 0

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
        return voices * 0.5 + work * 0.12 + saw(dt: dt) * 0.1 + chisel(dt: dt) * 0.1 + burn(dt: dt) * 0.1 + thresh(dt: dt) * 0.12 + quarry(dt: dt) * 0.1 + rake(dt: dt) * 0.1 + drill(dt: dt) * 0.12 + grind(dt: dt) * 0.1 + read(dt: dt) * 0.08
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

    /// The beacon's fire: a low roar of wind through flame, and now and
    /// then a crack as a log splits in it.
    @inline(__always)
    mutating func burn(dt: Float) -> Float {
        guard burning > 0.001 else { return 0 }
        if !roarSet {
            roar = Bandpass(centre: 260, width: 1.4, sampleRate: sampleRate)
            roarSet = true
        }
        let draw = noise.next()
        if draw > 0.9994 {
            crack = 0.6 + 0.4 * draw
            cracks += 1
        }
        crack *= 1 - min(dt * 250, 1)
        return (roar.process(noise.next()) * 0.8 + noise.next() * crack) * burning
    }

    /// The threshing floor: two flails falling in turn, a little under two
    /// strokes a second between them, each a low thud with its rustle.
    @inline(__always)
    mutating func thresh(dt: Float) -> Float {
        guard threshing > 0.001 else { return 0 }
        nextFlail -= dt
        if nextFlail <= 0 {
            let pitch: Float = flailTurn ? 140 : 175
            flail = (Resonator(frequency: pitch, amplitude: 0.9, decay: 18, sampleRate: sampleRate),
                     Resonator(frequency: pitch * 3.1, amplitude: 0.3, decay: 40, sampleRate: sampleRate))
            flailTurn.toggle()
            nextFlail = 0.5 + 0.06 * noise.next()
            flails += 1
        }
        return (flail.0.next() + flail.1.next()) * threshing
    }

    /// The quarry: picks and wedges on rock, a blow every half to one and a
    /// half seconds, each a low ring and a spray of grit.
    @inline(__always)
    mutating func quarry(dt: Float) -> Float {
        guard quarrying > 0.001 else { return 0 }
        nextPick -= dt
        if nextPick <= 0 {
            pick = Resonator(frequency: 820 + 140 * noise.next(), amplitude: 0.8, decay: 45, sampleRate: sampleRate)
            grit = 0.5
            nextPick = 1 + 0.5 * noise.next()
            picks += 1
        }
        grit *= 1 - min(dt * 60, 1)
        return (pick.next() + noise.next() * grit * 0.4) * quarrying
    }

    /// The pans: a rake drawn through salt crust, a long hiss rising and
    /// falling once every second and a half.
    @inline(__always)
    mutating func rake(dt: Float) -> Float {
        guard raking > 0.001 else { return 0 }
        if !hissSet {
            hiss = Bandpass(centre: 5_200, width: 1.6, sampleRate: sampleRate)
            hissSet = true
        }
        draw += dt / 1.5
        if draw >= 1 { draw -= 1 }
        let swell = max(0, Float(sin(Double(draw) * 2 * .pi)))
        return hiss.process(noise.next()) * swell * raking
    }

    /// The drill drum: two beats and a rest, a little under a beat in half a
    /// second, each a deep skin's boom and its slap.
    @inline(__always)
    mutating func drill(dt: Float) -> Float {
        guard drilling > 0.001 else { return 0 }
        nextBeat -= dt
        if nextBeat <= 0 {
            if beatInBar < 2 {
                let strong: Float = beatInBar == 0 ? 1 : 0.7
                beat = (Resonator(frequency: 95, amplitude: strong, decay: 9, sampleRate: sampleRate),
                        Resonator(frequency: 380, amplitude: strong * 0.25, decay: 50, sampleRate: sampleRate))
                beats += 1
            }
            beatInBar = (beatInBar + 1) % 3
            nextBeat = 0.42
        }
        return (beat.0.next() + beat.1.next()) * drilling
    }

    /// The infirmary: a pestle in a stone mortar, a knock then a grinding
    /// turn, a little faster than once a second.
    @inline(__always)
    mutating func grind(dt: Float) -> Float {
        guard grinding > 0.001 else { return 0 }
        if !grainSet {
            grain = Bandpass(centre: 1_400, width: 1.2, sampleRate: sampleRate)
            grainSet = true
        }
        let before = turn
        turn += dt * 1.2
        if turn >= 1 { turn -= 1 }
        if turn < before {
            knock = Resonator(frequency: 620, amplitude: 0.6, decay: 60, sampleRate: sampleRate)
            knocks += 1
        }
        let rub = turn > 0.2 && turn < 0.8 ? Float(sin(Double((turn - 0.2) / 0.6) * .pi)) : 0
        return (knock.next() + grain.process(noise.next()) * rub * 0.6) * grinding
    }

    /// The archive: now and then a page turned, a soft rush of paper a
    /// fifth of a second long, and between them the scratch of a quill.
    @inline(__always)
    mutating func read(dt: Float) -> Float {
        guard reading > 0.001 else { return 0 }
        if !leafSet {
            leaf = Bandpass(centre: 3_200, width: 1.8, sampleRate: sampleRate)
            leafSet = true
        }
        nextLeaf -= dt
        if nextLeaf <= 0 {
            turnLeft = 0.2
            nextLeaf = 1.6 + 0.8 * (1 + noise.next())
            pages += 1
        }
        let rush: Float = turnLeft > 0 ? Float(sin(Double(turnLeft / 0.2) * .pi)) : 0
        turnLeft = max(turnLeft - dt, 0)
        let scratch: Float = noise.next() > 0.7 ? 0.15 : 0
        return leaf.process(noise.next()) * (rush + scratch) * reading
    }
}
