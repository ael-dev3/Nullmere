import Foundation
import NullmereCore
import NullmereSound

/// The trailer's sound: the game's own night over the water and its own
/// score, rendered by its synthesiser away from any audio engine, shot by
/// shot. The drone and the wind from the first moment and the score at
/// peace; the towns as the camera comes among them; the drums of war
/// under the march, a horn as it sets out and the hooves of its riders;
/// the din of the battle and every blow, volley, fall and skill in it, as
/// the picture throws them; a deep toll as the moon is eaten; the lake's
/// title theme over the lake from on high and the title, two stately
/// chords as it rises, and all of it fading with the picture.
public struct Soundtrack: Sendable {
    public static let sampleRate = 48_000

    public enum Event: Sendable {
        case music(Score.Mood)
        case din(Float, pan: Float)
        case town(Float, pan: Float)
        case cue(SoundCue, pan: Float, gain: Float)
        case fadeOut(rate: Float)
    }

    public let events: [(time: Double, event: Event)]
    public let duration: Double

    public init(trailer: Trailer) {
        duration = trailer.duration
        var events: [(time: Double, event: Event)] = []
        func at(_ time: Double, _ event: Event) { events.append((time: time, event: event)) }
        func start(of name: String) -> Double { trailer.shots.first { $0.name == name }?.start ?? 0 }
        at(0, .music(.peace))
        at(5.5, .cue(.watch, pan: 0, gain: 0.7))
        // Among the holds and their folk.
        let descent = start(of: "the descent"), seat = start(of: "the seat"), town = start(of: "the town")
        let rising = start(of: "the rising")
        at(descent + 5, .town(0.3, pan: 0))
        at(seat, .town(0.6, pan: -0.2))
        at(town, .town(0.9, pan: 0.2))
        at(town + 3, .cue(.coin, pan: -0.4, gain: 0.5))
        at(rising, .town(0.45, pan: 0))
        at(rising + 2, .cue(.complete, pan: 0.3, gain: 0.55))
        // The march: the drums of war, a horn as it sets out, hooves.
        let march = start(of: "the march")
        at(march, .town(0, pan: 0))
        at(march, .music(.war))
        at(march + 0.6, .cue(.horn, pan: -0.3, gain: 0.8))
        for (index, offset) in [2.0, 5.5, 9.0].enumerated() {
            at(march + offset, .cue(.ride, pan: Float(index) * 0.3 - 0.3, gain: 0.6))
        }
        at(march + 7, .cue(.muster, pan: 0.2, gain: 0.55))
        // The battle, as the picture throws it.
        let battle = start(of: "the battle")
        at(battle, .cue(.herald, pan: 0, gain: 0.75))
        at(battle + 0.5, .din(0.8, pan: 0))
        for beat in trailer.battle.beats {
            switch beat.sound {
            case .clash(let across): at(battle + beat.time, .cue(.clash, pan: across, gain: 0.75))
            case .loose: at(battle + beat.time, .cue(.loose, pan: 0, gain: 0.55))
            case .fall: at(battle + beat.time, .cue(.dread, pan: 0, gain: 0.6))
            case .fury: at(battle + beat.time, .cue(.horn, pan: 0, gain: 0.7))
            }
        }
        if trailer.battle.blaze != nil {
            at(battle + 2.5, .cue(.batter, pan: 0.5, gain: 0.6))
        }
        // The moon eaten over the field.
        let eaten = start(of: "the eaten moon")
        at(eaten, .din(0.15, pan: 0))
        at(eaten, .music(.eclipse))
        at(eaten + 0.4, .cue(.toll, pan: 0, gain: 0.85))
        at(eaten + 4, .din(0, pan: 0))
        // The lake from on high, and the title.
        let lake = start(of: "the lake")
        at(lake, .music(.title(.round)))
        at(trailer.titleRises + 0.3, .cue(.banner, pan: 0, gain: 0.7))
        at(trailer.fadesOut - 0.5, .fadeOut(rate: 0.5))
        self.events = events.sorted { $0.time < $1.time }
    }

    /// Its samples, left and right, from its first moment to `end` (all of
    /// it, if none is given), the loudest at -1 dBFS.
    public func render(until end: Double? = nil) -> (left: [Float], right: [Float]) {
        let total = Int((min(end ?? duration, duration) * Double(Soundtrack.sampleRate)).rounded())
        var left = [Float](repeating: 0, count: total), right = [Float](repeating: 0, count: total)
        let synth = Synth()
        synth.prepare(sampleRate: Float(Soundtrack.sampleRate))
        synth.setVolumes(effects: 0.9, ambience: 0.6, music: 1)
        synth.setMusic(on: true, mood: .peace)
        synth.fadeIn()
        var next = 0
        var cursor = 0
        let chunk = Soundtrack.sampleRate / 100
        while cursor < total {
            let now = Double(cursor) / Double(Soundtrack.sampleRate)
            while next < events.count, events[next].time <= now {
                switch events[next].event {
                case .music(let mood): synth.setMusic(on: true, mood: mood)
                case .din(let level, let pan): synth.setDin(level: level, pan: pan)
                case .town(let level, let pan): synth.setTown(level: level, pan: pan)
                case .cue(let cue, let pan, let gain): synth.trigger(cue, at: SoundPlace(pan: pan, gain: gain))
                case .fadeOut(let rate): synth.fadeOut(rate: rate)
                }
                next += 1
            }
            let frames = min(chunk, total - cursor)
            left.withUnsafeMutableBufferPointer { l in
                right.withUnsafeMutableBufferPointer { r in
                    synth.render(frames: frames, left: l.baseAddress! + cursor, right: r.baseAddress! + cursor)
                }
            }
            cursor += frames
        }
        // Its loudest moment at -1 dBFS, and the last moments faded to nothing.
        let peak = max(left.map(abs).max() ?? 0, right.map(abs).max() ?? 0)
        let gain = peak > 0 ? 0.891 / peak : 1
        let tail = min(Soundtrack.sampleRate * 2, total)
        for index in 0..<total {
            let fade = index >= total - tail ? Float(total - index) / Float(tail) : 1
            left[index] *= gain * fade
            right[index] *= gain * fade
        }
        return (left, right)
    }

    /// Samples as a WAV file: 16-bit, two channels, at the trailer's rate.
    public static func wav(left: [Float], right: [Float]) -> Data {
        let frames = min(left.count, right.count)
        var data = Data()
        func word(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        func half(_ value: UInt16) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        let bytes = UInt32(frames * 4)
        data.append(contentsOf: Array("RIFF".utf8)); word(36 + bytes)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8)); word(16); half(1); half(2)
        word(UInt32(sampleRate)); word(UInt32(sampleRate * 4)); half(4); half(16)
        data.append(contentsOf: Array("data".utf8)); word(bytes)
        data.reserveCapacity(data.count + frames * 4)
        for index in 0..<frames {
            for sample in [left[index], right[index]] {
                let clamped = min(max(sample, -1), 1)
                half(UInt16(bitPattern: Int16((clamped * 32_767).rounded())))
            }
        }
        return data
    }
}
