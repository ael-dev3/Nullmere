import AVFoundation
import Foundation
import NullmereCore
import NullmereSound
import os

/// The game's sound on the Mac: the audio engine that plays what the
/// synthesiser (NullmereSound's `Synth`) makes, all of it made as it plays.
/// Nothing is recorded or sampled.
@MainActor
public final class Ambience {
    /// What the game sounds, each its own.
    public typealias Cue = SoundCue

    private static let logger = Logger(subsystem: "online.nullmere.game", category: "sound")

    private let engine = AVAudioEngine()
    private let synth = Synth()
    private var started = false

    /// The player has sound turned on.
    public var isEnabled: Bool {
        didSet { apply() }
    }

    /// The game wants its sound now, from `start()` to `stop()`: at the
    /// realm's door and in the world, not in the launcher. Sound turned on
    /// meanwhile waits for it.
    public private(set) var isWanted = false

    /// Fading out before the engine stops: a hard stop clicks.
    private var winding: Task<Void, Never>?
    /// How long sound takes to fade out, as the picture fades.
    static let fadeOutSeconds = 0.8

    /// The engine is running and not fading out: for tests.
    var isPlaying: Bool { started && winding == nil }

    /// The engine is running, fading out or not: for tests.
    var isRunning: Bool { started }

    /// When each cue last sounded. The same cue again within a tenth of a
    /// second is one sound, not a pile of them: ten watches turned at once
    /// toll one bell.
    private var lastPlayed: [Cue: ContinuousClock.Instant] = [:]

    public init(enabled: Bool) {
        isEnabled = enabled
    }

    /// The cues asked for together, as a watch's turning asks for its bell
    /// and what the watch brought: when they began, and how many so far.
    private var batch: (start: ContinuousClock.Instant, count: Int)?
    /// How far apart cues asked for together sound: one after another, the
    /// bell first, not all at once.
    static let batchSpacing: Float = 0.38

    public func play(_ cue: Cue, at place: SoundPlace = .middle) {
        guard isEnabled, started, winding == nil else { return }
        let now = ContinuousClock.now
        if let last = lastPlayed[cue], now - last < .milliseconds(100) { return }
        lastPlayed[cue] = now
        var delay: Float = 0
        if let current = batch, now - current.start < .milliseconds(30) {
            delay = Float(current.count) * Self.batchSpacing
            batch = (current.start, current.count + 1)
        } else {
            batch = (now, 1)
        }
        synth.trigger(cue, after: delay, at: place)
    }

    /// Fades all of it out quickly, for the app quitting, and says how long
    /// to wait for it: a hard stop clicks. Nothing to wait for while silent
    /// or already fading.
    @discardableResult
    public func fadeForQuitting() -> Double {
        guard started, winding == nil else { return 0 }
        synth.fadeOut(rate: 12)
        return Self.quitFadeSeconds
    }

    /// Long enough at that pace for the sound to fall some thirty decibels.
    public static let quitFadeSeconds = 0.35

    /// The din of the fields of battle in sight: how loud, from nothing (0)
    /// to a great battle close by (1), and where across the view, from the
    /// left (-1) to the right (1).
    public func setDin(level: Float, pan: Float) {
        synth.setDin(level: level, pan: pan)
    }

    /// The towns near the view: how near, from nothing (0) to a busy seat
    /// close by (1), and where across the view, from the left (-1) to the
    /// right (1).
    public func setTown(level: Float, pan: Float) {
        synth.setTown(level: level, pan: pan)
    }

    /// How much of the towns heard is sawpits at work, 0 to 1.
    public func setSawing(_ share: Float) {
        synth.setSawing(share)
    }

    /// How much of the towns heard is masons at work, 0 to 1.
    public func setChiselling(_ share: Float) {
        synth.setChiselling(share)
    }

    /// How much of the towns heard is a beacon's fire, 0 to 1.
    public func setBurning(_ share: Float) {
        synth.setBurning(share)
    }

    /// How much of the towns heard is a granary's threshing, 0 to 1.
    public func setThreshing(_ share: Float) {
        synth.setThreshing(share)
    }

    /// How much of the towns heard is a quarry at work, 0 to 1.
    public func setQuarrying(_ share: Float) {
        synth.setQuarrying(share)
    }

    /// How much of the towns heard is a saltworks, 0 to 1.
    public func setRaking(_ share: Float) {
        synth.setRaking(share)
    }

    /// How much of the towns heard is a muster hall at drill, 0 to 1.
    public func setDrilling(_ share: Float) {
        synth.setDrilling(share)
    }

    /// How much of the towns heard is an infirmary at work, 0 to 1.
    public func setGrinding(_ share: Float) {
        synth.setGrinding(share)
    }

    /// How much of the towns heard is an archive, 0 to 1.
    public func setReading(_ share: Float) {
        synth.setReading(share)
    }

    /// The score: on or off, and at peace or at war.
    public var isMusicOn = true {
        didSet { applyMusic() }
    }

    public var isAtWar = false {
        didSet { if isAtWar != oldValue { applyMusic() } }
    }

    /// The moon is eaten and the drowned age walks: the score turns strange.
    public var isEclipse = false {
        didSet { if isEclipse != oldValue { applyMusic() } }
    }

    /// The lake whose title theme plays, over the launcher; nil in the realm.
    public var titleLake: Lake? {
        didSet { if titleLake != oldValue { applyMusic() } }
    }

    /// What the score plays now: the title theme over the launcher; in the
    /// realm, the eaten moon's while the drowned age walks, else war or
    /// peace.
    var mood: Score.Mood {
        titleLake.map { .title($0) } ?? (isEclipse ? .eclipse : isAtWar ? .war : .peace)
    }

    private func applyMusic() {
        synth.setMusic(on: isMusicOn, mood: mood)
    }

    /// How loud each part of the sound plays, from silent (0) to full (1):
    /// the cues, the night's drone and wind, and the score.
    public var effectsVolume: Float = 1 { didSet { applyVolumes() } }
    public var ambienceVolume: Float = 1 { didSet { applyVolumes() } }
    public var musicVolume: Float = 1 { didSet { applyVolumes() } }

    private func applyVolumes() {
        synth.setVolumes(effects: effectsVolume, ambience: ambienceVolume, music: musicVolume)
    }

    private func apply() {
        if isEnabled { begin() } else { windDown() }
    }

    public func start() {
        isWanted = true
        begin()
    }

    private func begin() {
        guard isEnabled, isWanted else { return }
        if let winding {
            // Wanted again while fading out: it fades back in.
            winding.cancel()
            self.winding = nil
            synth.fadeIn()
            return
        }
        guard !started else { return }
        let format = engine.outputNode.inputFormat(forBus: 0)
        let rate = format.sampleRate > 0 ? format.sampleRate : 48_000
        let stereo = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2)!
        synth.prepare(sampleRate: Float(rate))
        let source = Ambience.makeSource(format: stereo, synth: synth)
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: stereo)
        engine.mainMixerNode.outputVolume = 0.9
        do {
            try engine.start()
            started = true
            synth.fadeIn()
            applyMusic()
        } catch {
            Ambience.logger.notice("No sound: \(error.localizedDescription, privacy: .public)")
            engine.detach(source)
        }
    }

    /// Built outside the main actor: the render block runs on the audio thread.
    nonisolated private static func makeSource(format: AVAudioFormat, synth: Synth) -> AVAudioSourceNode {
        AVAudioSourceNode(format: format) { _, _, frameCount, buffers in
            synth.render(frames: Int(frameCount), into: UnsafeMutableAudioBufferListPointer(buffers))
            return noErr
        }
    }

    public func stop() {
        isWanted = false
        windDown()
    }

    /// Fades out, then stops the engine.
    private func windDown() {
        guard started, winding == nil else { return }
        synth.fadeOut()
        winding = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Ambience.fadeOutSeconds))
            guard let self, !Task.isCancelled else { return }
            self.winding = nil
            self.end()
        }
    }

    private func end() {
        guard started else { return }
        engine.stop()
        for node in engine.attachedNodes where node is AVAudioSourceNode {
            engine.detach(node)
        }
        // Begun again, it fades in from silence, with no tail of before.
        synth.reset()
        started = false
    }
}

extension Synth {
    /// Renders into the audio engine's buffers, the left ear first.
    func render(frames: Int, into buffers: UnsafeMutableAudioBufferListPointer) {
        guard buffers.count >= 2,
              let left = buffers[0].mData?.assumingMemoryBound(to: Float.self),
              let right = buffers[1].mData?.assumingMemoryBound(to: Float.self)
        else { return }
        render(frames: frames, left: left, right: right)
    }
}
