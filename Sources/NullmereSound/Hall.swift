import Foundation

/// A hall for the sound to ring in, as a stone hall by still water rings:
/// each sound first waits a breath, then four all-pass filters smear it
/// into a wash of early echoes, then it is carried round eight delay lines
/// of unlike lengths, each feeding every other (a feedback delay network,
/// after Jot), losing a little of itself each time round and its highs the
/// faster, so the tail darkens as it fades. The two ears hear different
/// lines, so the tail is wide. Every length and corner is set in seconds
/// and hertz, so it rings alike at any sample rate. Its memory is found
/// once, as it is made; on the audio thread it finds none.
final class Hall {
    /// The lines' lengths at 48 kHz, in samples: prime, from 27 to 56 ms.
    static let lines = [1_307, 1_451, 1_607, 1_789, 1_993, 2_207, 2_437, 2_671]
    /// The diffusers' lengths at 48 kHz, in samples: from 5 to 13 ms.
    static let diffusers = [229, 347, 467, 631]
    /// How long a sound waits before the hall gives it back, in seconds.
    static let predelay: Float = 0.014
    /// How much each diffuser passes on and holds back.
    static let diffusion: Float = 0.6
    /// The corner, in hertz, above which each line's echoes lose their
    /// highs as they go round.
    static let damping: Float = 9_000
    /// Each line's share of what the hall is given: one over the root of
    /// eight, so the eight together hold what came in.
    static let share: Float = 0.353_553_4

    let sampleRate: Float
    /// Seconds for the hall's echoes to die away sixty decibels.
    let seconds: Float

    /// The predelay, the four diffusers and the eight lines, one after
    /// another; where each begins, how long each is, and where each reads
    /// and writes now.
    private static let parts = 13
    private let storage: UnsafeMutablePointer<Float>
    private let size: Int
    private let starts: UnsafeMutablePointer<Int>
    private let lengths: UnsafeMutablePointer<Int>
    private let cursors: UnsafeMutablePointer<Int>
    /// Each line's echo with its highs lessened, and what it keeps of
    /// itself each time round, for its length.
    private let lows: UnsafeMutablePointer<Float>
    private let gains: UnsafeMutablePointer<Float>
    private let smoothing: Float

    init(sampleRate: Float, seconds: Float = 2.6) {
        self.sampleRate = sampleRate
        self.seconds = seconds
        let scale = sampleRate / 48_000
        let sizes = [max(1, Int((Hall.predelay * sampleRate).rounded()))]
            + (Hall.diffusers + Hall.lines).map { max(1, Int((Float($0) * scale).rounded())) }
        size = sizes.reduce(0, +)
        storage = .allocate(capacity: size)
        storage.initialize(repeating: 0, count: size)
        starts = .allocate(capacity: Hall.parts)
        lengths = .allocate(capacity: Hall.parts)
        cursors = .allocate(capacity: Hall.parts)
        var start = 0
        for (part, length) in sizes.enumerated() {
            starts[part] = start
            lengths[part] = length
            cursors[part] = 0
            start += length
        }
        lows = .allocate(capacity: 8)
        lows.initialize(repeating: 0, count: 8)
        gains = .allocate(capacity: 8)
        for line in 0..<8 {
            // Sixty decibels down in `seconds`, however long the line.
            gains[line] = pow(10, -3 * Float(sizes[5 + line]) / (seconds * sampleRate))
        }
        smoothing = 1 - exp(-2 * .pi * Hall.damping / sampleRate)
    }

    deinit {
        storage.deallocate()
        starts.deallocate()
        lengths.deallocate()
        cursors.deallocate()
        lows.deallocate()
        gains.deallocate()
    }

    /// Silent again, with no tail of before.
    func clear() {
        storage.update(repeating: 0, count: size)
        lows.update(repeating: 0, count: 8)
    }

    /// What a part gives back now: what was written to it its length ago.
    @inline(__always)
    private func read(_ part: Int) -> Float {
        storage[starts[part] + cursors[part]]
    }

    /// Writes a part's next sample in place of the one just read, and moves on.
    @inline(__always)
    private func write(_ part: Int, _ value: Float) {
        let cursor = cursors[part]
        storage[starts[part] + cursor] = value
        cursors[part] = cursor + 1 == lengths[part] ? 0 : cursor + 1
    }

    /// The hall's answer to one sample of each ear.
    @inline(__always)
    func process(left: Float, right: Float) -> (left: Float, right: Float) {
        // The sound waits its breath, then the diffusers smear it.
        var x = read(0)
        write(0, 0.5 * (left + right))
        for part in 1...4 {
            let delayed = read(part)
            let held = x + Hall.diffusion * delayed
            write(part, held)
            x = delayed - Hall.diffusion * held
        }
        // What each line gives back now, its highs lessened and its loss
        // taken; the ears hear the lines as they come back, the even ones
        // the left, the odd ones the right.
        var heardLeft: Float = 0, heardRight: Float = 0
        var sum: Float = 0
        for line in 0..<8 {
            let back = read(5 + line)
            let sign: Float = line & 2 == 0 ? 0.5 : -0.5
            if line & 1 == 0 { heardLeft += sign * back } else { heardRight += sign * back }
            var low = lows[line] + (back - lows[line]) * smoothing
            // Below hearing, an echo is nothing, not a crawl of tiny numbers.
            if low < 1e-18 && low > -1e-18 { low = 0 }
            lows[line] = low
            sum += low * gains[line]
        }
        // Every line fed by every other, each alike: a Householder
        // reflection, which keeps all it is given, and the new sound shared
        // among them, by turns of sign.
        let reflected = sum * 0.25
        for line in 0..<8 {
            let kept = lows[line] * gains[line]
            write(5 + line, kept - reflected + (line & 1 == 0 ? x : -x) * Hall.share)
        }
        return (heardLeft, heardRight)
    }
}
