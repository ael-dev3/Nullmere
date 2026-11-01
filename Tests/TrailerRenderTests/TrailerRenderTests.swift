import AppKit
import AVFoundation
import CoreText
import ImageIO
@testable import LauncherKit
import LauncherCore
import Metal
@testable import NullmereKit
import NullmereModels
import NullmereSound
import NullmereTrailer
import NullmereWorld
import XCTest

/// The trailer drawn by the game's own renderers, frame by frame, the
/// title over the lake of the title screen, and written with its score to
/// an H.264 film of 1920 by 1080 at thirty frames a second: run by
/// scripts/render-trailer.sh, which names the folder it goes to, and
/// skipped otherwise. With NULLMERE_TRAILER_MODE=stills it draws only a
/// still from the middle of each shot, to look at.
final class TrailerRenderTests: XCTestCase {
    func testRenderTheTrailer() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let out = environment["NULLMERE_TRAILER"] else { throw XCTSkip("The trailer is rendered by scripts/render-trailer.sh") }
        guard let device = MTLCreateSystemDefaultDevice() else { throw XCTSkip("No Metal device available") }
        let directory = URL(fileURLWithPath: out, isDirectory: true)
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("stills"), withIntermediateDirectories: true)
        let began = Date()
        let projector = try Projector(device: device, trailer: Trailer(houses: WorldView.houseColours))
        let trailer = projector.trailer
        print("TRAILER world ready in \(Int(Date().timeIntervalSince(began))) s: \(trailer.shots.count) shots, \(trailer.frameCount) frames, "
              + "\(trailer.world.state.holds.count) holds, on \(device.name)")

        // A still from the middle of each shot, and from the battle's height.
        var stills = trailer.shots.map { (name: $0.name, time: $0.start + $0.length * 0.55) }
        if let battle = trailer.shots.first(where: { $0.action == .battle }) {
            stills.append((name: "the battle, close", time: battle.start + battle.length * 0.85))
        }
        for still in stills {
            let frame = projector.frame(at: still.time)
            try Projector.jpeg(frame, width: Trailer.width, height: Trailer.height,
                            to: directory.appendingPathComponent("stills/\(still.name.replacingOccurrences(of: " ", with: "-")).jpg"))
        }
        print("TRAILER stills drawn in \(Int(Date().timeIntervalSince(began))) s")
        guard environment["NULLMERE_TRAILER_MODE"] != "stills" else { return }

        // The score, then the film.
        let soundtrack = Soundtrack(trailer: trailer)
        let (left, right) = soundtrack.render()
        try Soundtrack.wav(left: left, right: right).write(to: directory.appendingPathComponent("nullmere-trailer.wav"))
        print("TRAILER score rendered in \(Int(Date().timeIntervalSince(began))) s")
        let film = directory.appendingPathComponent("nullmere-trailer.mp4")
        try Film.write(to: film, frames: trailer.frameCount, picture: { projector.frame(at: Double($0) / Double(Trailer.framesPerSecond)) },
                       left: left, right: right)
        let size = (try FileManager.default.attributesOfItem(atPath: film.path)[.size] as? Int) ?? 0
        print("TRAILER film written in \(Int(Date().timeIntervalSince(began))) s: \(film.lastPathComponent), \(size / 1_000_000) MB, "
              + "\(String(format: "%.1f", trailer.duration)) s")
        XCTAssertGreaterThan(size, 5_000_000)

        // Read back: as long as the trailer, its picture 1920 by 1080, its sound there.
        let asset = AVURLAsset(url: film)
        let duration = try awaitResult { try await asset.load(.duration) }
        XCTAssertEqual(duration.seconds, trailer.duration, accuracy: 0.5)
        let video = try awaitResult { try await asset.loadTracks(withMediaType: .video) }
        let audio = try awaitResult { try await asset.loadTracks(withMediaType: .audio) }
        XCTAssertEqual(video.count, 1)
        XCTAssertEqual(audio.count, 1)
        if let track = video.first {
            let natural = try awaitResult { try await track.load(.naturalSize) }
            XCTAssertEqual(natural, CGSize(width: Trailer.width, height: Trailer.height))
        }
    }

    /// Waits on async work from a test that is not itself async.
    func awaitResult<T: Sendable>(_ work: @escaping @Sendable () async throws -> T) throws -> T {
        let semaphore = DispatchSemaphore(value: 0)
        let box = Box<Result<T, any Error>>()
        // Detached, so it never waits on the main thread this blocks.
        Task.detached {
            do { box.value = .success(try await work()) } catch { box.value = .failure(error) }
            semaphore.signal()
        }
        semaphore.wait()
        return try box.value!.get()
    }
}

final class Box<T>: @unchecked Sendable {
    var value: T?
}

/// What draws the trailer: the game's world renderer and the launcher's
/// lake renderer on one GPU, drawing any moment of the trailer to pixels,
/// row by row from the top, four bytes each, blue, green, red and alpha.
final class Projector: @unchecked Sendable {
    let trailer: Trailer
    private let world: WorldRenderer
    private let target: WorldRenderer.Target
    private let lake: LakeRenderer
    private let lakeTarget: any MTLTexture
    private let width = Trailer.width, height = Trailer.height

    init(device: any MTLDevice, trailer: Trailer) throws {
        self.trailer = trailer
        let library = try device.makeLibrary(source: WorldShaders.source, options: nil)
        world = try WorldRenderer(device: device, library: library, pixelFormat: .bgra8Unorm)
        world.meshSource = { Library.model($0).mesh }
        let state = trailer.world.state
        try world.setLand(trailer.world.terrain, for: state.map)
        // All of it seen: no mist anywhere.
        try world.updateTiles(TileTexture.bytes(for: state, viewer: state.player, visible: Array(repeating: true, count: state.map.count)),
                              side: TileTexture.side(for: state.map))
        target = try world.makeTarget(width: Trailer.width, height: Trailer.height)
        lake = try LakeRenderer(device: device, library: device.makeLibrary(source: LakeShader.source, options: nil), pixelFormat: .bgra8Unorm)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: Trailer.width, height: Trailer.height,
                                                                  mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else { throw WorldRenderer.Failure.noTexture }
        lakeTarget = texture
    }

    /// The trailer at a moment: its shot, dissolving from the one before;
    /// the title over the lake; as bright as the trailer is then.
    func frame(at time: Double) -> [UInt8] {
        let (shot, from, weight) = trailer.shot(at: time)
        var pixels = picture(of: shot, at: time)
        if let from, weight < 1 {
            let before = picture(of: from, at: time)
            let w = Float(weight)
            for index in pixels.indices {
                pixels[index] = UInt8(min(Float(before[index]) * (1 - w) + Float(pixels[index]) * w + 0.5, 255))
            }
        }
        if shot.look == .title {
            title(on: &pixels, showing: trailer.title(at: time))
        }
        let brightness = Float(trailer.brightness(at: time))
        if brightness < 1 {
            for index in pixels.indices {
                pixels[index] = UInt8(Float(pixels[index]) * brightness)
            }
        }
        return pixels
    }

    private func picture(of shot: Trailer.Shot, at time: Double) -> [UInt8] {
        switch shot.look {
        case .lake, .title:
            return lakePicture(at: time)
        case .world:
            let camera = trailer.camera(of: shot, at: time)
            let scene = trailer.scene(of: shot, at: time)
            var frame = FrameUniforms.make(camera: camera, size: Trailer.viewSize, pixelsPerPoint: Trailer.pixelsPerPoint, time: Float(time),
                                           motion: 1, radius: trailer.world.state.map.radius, terrain: trailer.world.terrain,
                                           hovered: nil, selected: nil, houses: trailer.world.houses)
            frame.light(with: PointLight.strongest(scene.lights, near: camera.focus))
            frame.weather(scene.weather)
            return world.pixels(frame, scene: scene, into: target) ?? [UInt8](repeating: 0, count: width * height * 4)
        }
    }

    /// The lake of the title screen: the moon over the still water, the
    /// stars, a falling star now and then.
    private func lakePicture(at time: Double) -> [UInt8] {
        let uniforms = LakeUniforms(sizeAndPixels: SIMD4(Float(Trailer.viewSize.width), Float(Trailer.viewSize.height), Float(width), Float(height)),
                                    params: SIMD4(Float(time + 30), 1, Float(LakeComposition.horizon), 0))
        _ = lake.measureFrame(uniforms, into: lakeTarget)
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        bytes.withUnsafeMutableBytes { raw in
            guard let base = raw.baseAddress else { return }
            lakeTarget.getBytes(base, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        }
        return bytes
    }

    /// The title as the launcher sets it over the lake: NULLMERE ONLINE,
    /// wide and thin above the far shore, in the launcher's pale type and
    /// glow.
    private func title(on pixels: inout [UInt8], showing opacity: Double) {
        guard opacity > 0 else { return }
        let scale = Trailer.pixelsPerPoint
        let unit = LakeComposition.unit(width: Trailer.viewSize.width, height: Trailer.viewSize.height)
        let size = 60 * unit * scale
        let tracking = 0.32
        let font = NSFont.systemFont(ofSize: size, weight: .thin)
        let ink = NSColor(srgbRed: 0.894, green: 0.918, blue: 0.949, alpha: opacity)
        let text = NSAttributedString(string: "NULLMERE ONLINE", attributes: [.font: font, .kern: size * tracking, .foregroundColor: ink])
        let line = CTLineCreateWithAttributedString(text)
        let lineWidth = CTLineGetTypographicBounds(line, nil, nil, nil) - size * tracking
        // Resting at the foot of the band above the far shore, as the launcher sets it.
        let band = (LakeComposition.waterline(forHeight: Trailer.viewSize.height) - 46 * unit) * scale
        let baseline = Double(height) - band - Double(font.descender)
        pixels.withUnsafeMutableBytes { raw in
            guard let base = raw.baseAddress,
                  let context = CGContext(data: base, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                          space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
            else { return }
            let glow = NSColor(srgbRed: 0.588, green: 0.706, blue: 0.882, alpha: 1)
            let x = (Double(width) - lineWidth) / 2
            for (blur, strength) in [(26 * unit * scale, 0.42), (3 * unit * scale, 0.28)] {
                context.saveGState()
                context.setShadow(offset: .zero, blur: CGFloat(blur), color: glow.withAlphaComponent(CGFloat(strength * opacity)).cgColor)
                context.textPosition = CGPoint(x: x, y: baseline)
                CTLineDraw(line, context)
                context.restoreGState()
            }
        }
    }

    /// A frame written as a JPEG, for looking at.
    static func jpeg(_ pixels: [UInt8], width: Int, height: Int, to url: URL) throws {
        var pixels = pixels
        let image: CGImage? = pixels.withUnsafeMutableBytes { raw in
            guard let base = raw.baseAddress else { return nil }
            return CGContext(data: base, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                             space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                             bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)?.makeImage()
        }
        guard let image, let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.jpeg" as CFString, 1, nil) else {
            throw WorldRenderer.Failure.noTexture
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw WorldRenderer.Failure.noTexture }
    }
}

/// The film: pictures and sound written together as H.264 and AAC in an MP4.
enum Film {
    enum Failure: Error { case writer(String), buffer }

    static func write(to url: URL, frames count: Int, picture: (Int) -> [UInt8], left: [Float], right: [Float]) throws {
        try? FileManager.default.removeItem(at: url)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let width = Trailer.width, height = Trailer.height
        let video = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 16_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoMaxKeyFrameIntervalKey: 60,
                AVVideoExpectedSourceFrameRateKey: Trailer.framesPerSecond,
            ] as [String: Any],
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ],
        ])
        video.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: video, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ])
        let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: Soundtrack.sampleRate,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 256_000,
        ])
        audio.expectsMediaDataInRealTime = false
        writer.add(video)
        writer.add(audio)
        guard writer.startWriting() else { throw Failure.writer("\(writer.error.map { "\($0)" } ?? "could not start")") }
        writer.startSession(atSourceTime: .zero)

        var format: CMAudioFormatDescription?
        var description = AudioStreamBasicDescription(mSampleRate: Float64(Soundtrack.sampleRate), mFormatID: kAudioFormatLinearPCM,
                                                      mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked,
                                                      mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4, mChannelsPerFrame: 2,
                                                      mBitsPerChannel: 16, mReserved: 0)
        CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &description, layoutSize: 0, layout: nil, magicCookieSize: 0,
                                       magicCookie: nil, extensions: nil, formatDescriptionOut: &format)
        guard let format else { throw Failure.buffer }
        let samples = min(left.count, right.count)
        let chunk = Soundtrack.sampleRate / 10
        var cursor = 0

        func waitUntilReady(_ input: AVAssetWriterInput) -> Bool {
            let started = Date()
            while !input.isReadyForMoreMediaData {
                if writer.status == .failed || Date().timeIntervalSince(started) > 5 { return false }
                Thread.sleep(forTimeInterval: 0.002)
            }
            return true
        }
        func appendSound(until end: Int) throws {
            while cursor < min(end, samples) {
                guard waitUntilReady(audio) else { return }
                let count = min(chunk, samples - cursor)
                var interleaved = [Int16](repeating: 0, count: count * 2)
                for index in 0..<count {
                    interleaved[2 * index] = Int16((min(max(left[cursor + index], -1), 1) * 32_767).rounded())
                    interleaved[2 * index + 1] = Int16((min(max(right[cursor + index], -1), 1) * 32_767).rounded())
                }
                var block: CMBlockBuffer?
                let length = count * 4
                CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault, memoryBlock: nil, blockLength: length,
                                                   blockAllocator: kCFAllocatorDefault, customBlockSource: nil, offsetToData: 0,
                                                   dataLength: length, flags: 0, blockBufferOut: &block)
                guard let block else { throw Failure.buffer }
                interleaved.withUnsafeBytes { raw in
                    if let base = raw.baseAddress {
                        CMBlockBufferReplaceDataBytes(with: base, blockBuffer: block, offsetIntoDestination: 0, dataLength: length)
                    }
                }
                var sample: CMSampleBuffer?
                CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: kCFAllocatorDefault, dataBuffer: block, formatDescription: format,
                                                                     sampleCount: count,
                                                                     presentationTimeStamp: CMTime(value: CMTimeValue(cursor),
                                                                                                   timescale: CMTimeScale(Soundtrack.sampleRate)),
                                                                     packetDescriptions: nil, sampleBufferOut: &sample)
                guard let sample, audio.append(sample) else { throw Failure.writer("sound at \(cursor): \(writer.error.map { "\($0)" } ?? "")") }
                cursor += count
            }
        }

        for frame in 0..<count {
            // The sound a little ahead of the picture, so the two interleave.
            try appendSound(until: (frame + 1) * Soundtrack.sampleRate / Trailer.framesPerSecond + chunk)
            let pixels = picture(frame)
            guard waitUntilReady(video), let pool = adaptor.pixelBufferPool else { throw Failure.writer("picture at \(frame): not ready") }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buffer)
            guard let buffer else { throw Failure.buffer }
            CVPixelBufferLockBaseAddress(buffer, [])
            if let base = CVPixelBufferGetBaseAddress(buffer) {
                let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
                pixels.withUnsafeBytes { raw in
                    guard let source = raw.baseAddress else { return }
                    for row in 0..<height {
                        memcpy(base + row * rowBytes, source + row * width * 4, width * 4)
                    }
                }
            }
            CVPixelBufferUnlockBaseAddress(buffer, [])
            guard adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: CMTimeScale(Trailer.framesPerSecond)))
            else { throw Failure.writer("picture at \(frame): \(writer.error.map { "\($0)" } ?? "")") }
            if frame % 300 == 0 { print("TRAILER frame \(frame) of \(count)") }
        }
        try appendSound(until: samples)
        video.markAsFinished()
        audio.markAsFinished()
        let done = DispatchSemaphore(value: 0)
        writer.finishWriting { done.signal() }
        done.wait()
        guard writer.status == .completed else { throw Failure.writer("finishing: \(writer.error.map { "\($0)" } ?? "\(writer.status.rawValue)")") }
    }
}
