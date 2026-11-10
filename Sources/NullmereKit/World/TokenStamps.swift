import CoreGraphics
import NullmereCore
import SwiftUI

/// The flat world's tokens, drawn once and stamped. A Mac that cannot draw
/// the world draws its holds and companies as line art (`TokenArt`): a
/// company's shield filled and stroked and its kind's mark stroked over
/// it, a hold's towers, walls, keep, window, banner and spire. Filled and
/// stroked anew each frame, that line art was most of what the flat marks
/// cost: run 951 timed them at 5.04 ms against the 4.85 allowed, where the
/// marks over the models, the same but for the tokens, took 2.00. So each
/// token is drawn once into a small image, at twice the point's size at
/// least, and set as a stamp where it stands, on a whole pixel so it is as
/// sharp as it was drawn; one image a token where there were up to ten
/// shapes. A token is told apart by its kind, its House's colour, its
/// size to a quarter of a point and what it shows (dug in; a hold's
/// towers, walls, Moonspire and banner), so a stamp is drawn again only
/// when one of those changes.
@MainActor
final class TokenStamps {
    static let shared = TokenStamps()

    /// The most stamps kept. Past it they are let go together and drawn
    /// again as they are needed: a zoom across every size makes new ones.
    static let most = 1_024

    /// A token drawn once: its image, and where that stands from the
    /// token's centre, in points.
    struct Stamp {
        let image: CGImage?
        /// From the token's centre to the image's top-left corner.
        let offset: CGPoint
        let size: CGSize
        /// The scale it was drawn at: pixels a point.
        let scale: CGFloat
    }

    struct Key: Hashable {
        /// A company's kind, dug in or not; or a hold's towers, walls,
        /// Moonspire and banner.
        let shape: Int
        /// Its radius, in quarter points.
        let quarters: Int
        /// Its House's colour, eight bits a channel.
        let colour: UInt32
        /// Pixels a point, in hundredths.
        let scale: Int
    }

    private var stamps: [Key: Stamp] = [:]
    /// How many stamps have been drawn: each once, while it is kept.
    private(set) var made = 0
    /// How many are kept.
    var count: Int { stamps.count }

    /// Lets every stamp go, and the count of those drawn starts again.
    func forget() {
        stamps.removeAll()
        made = 0
    }

    /// The scale stamps are drawn at for a context: its own, and never
    /// less than two pixels a point, so a stamp set on a Retina screen,
    /// or rendered at twice the size, is never blown up.
    static func scale(for context: GraphicsContext) -> CGFloat {
        max(context.environment.displayScale, 2)
    }

    static func packed(_ colour: Color.Resolved) -> UInt32 {
        func byte(_ value: Float) -> UInt32 { UInt32((min(max(value, 0), 1) * 255).rounded()) }
        return byte(colour.red) << 24 | byte(colour.green) << 16 | byte(colour.blue) << 8 | byte(colour.opacity)
    }

    static func quarters(of radius: CGFloat) -> Int {
        max(Int((radius * 4).rounded()), 1)
    }

    /// The dark a token is filled with, as the line art fills it.
    static let companyFill = CGColor(srgbRed: 0.03, green: 0.035, blue: 0.05, alpha: 0.9)
    static let holdFill = CGColor(srgbRed: 0.04, green: 0.045, blue: 0.06, alpha: 0.92)
    static let wallsFill = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.55)
    static let windowLight = CGColor(srgbRed: 1.0, green: 0.76, blue: 0.45, alpha: 1)
    static let needle = CGColor(srgbRed: 0.86, green: 0.9, blue: 1.0, alpha: 1)

    /// A company's token: its shield filled and stroked in its House's
    /// colour, bolder dug in, and its kind's mark over it.
    func company(_ kind: UnitKind, radius: CGFloat, colour: Color.Resolved, fortified: Bool, scale: CGFloat) -> (Key, Stamp) {
        let quarters = TokenStamps.quarters(of: radius), r = CGFloat(quarters) / 4
        let index = UnitKind.allCases.firstIndex(of: kind) ?? 0
        let key = Key(shape: index * 2 + (fortified ? 1 : 0), quarters: quarters, colour: TokenStamps.packed(colour),
                      scale: Int((scale * 100).rounded()))
        if let stamp = stamps[key] { return (key, stamp) }
        let shield = TokenArt.shield(at: .zero, radius: r)
        let mark = Path(companyMark: kind, at: .zero, radius: r * 0.55)
        let line: CGFloat = fortified ? 2.2 : 1.3
        let ink = colour.cgColor
        let bounds = shield.boundingRect.union(mark.boundingRect).insetBy(dx: -(line / 2 + 1), dy: -(line / 2 + 1))
        return (key, make(key, bounds: bounds, scale: scale) { cg in
            TokenStamps.fill(shield, TokenStamps.companyFill, in: cg)
            TokenStamps.stroke(shield, ink, width: line, in: cg)
            TokenStamps.stroke(mark, ink, width: 1.3, in: cg)
        })
    }

    /// A hold's token: its side towers once it has grown, its walls as they
    /// rise, its keep, a warm window, the seat's banner and the Moonspire's
    /// needle.
    func hold(_ hold: Hold, radius: CGFloat, colour: Color.Resolved, scale: CGFloat) -> (Key, Stamp) {
        let quarters = TokenStamps.quarters(of: radius), r = CGFloat(quarters) / 4
        let towers = TokenArt.towerCount(for: hold), walls = hold.level(.walls), spire = hold.level(.moonspire)
        let shape = 1_000_000 + towers * 100_000 + min(walls, 99) * 1_000 + min(spire, 99) * 10 + (hold.isSeat ? 1 : 0)
        let key = Key(shape: shape, quarters: quarters, colour: TokenStamps.packed(colour), scale: Int((scale * 100).rounded()))
        if let stamp = stamps[key] { return (key, stamp) }
        let seat = hold.isSeat
        let ink = colour.cgColor
        let keep = TokenArt.keep(at: .zero, radius: r, seat: seat)
        let flanks = towers > 0 ? TokenArt.towers(at: .zero, radius: r, count: towers) : nil
        let ring = walls > 0 ? TokenArt.walls(at: .zero, radius: r) : nil
        let banner = seat ? TokenArt.banner(at: .zero, radius: r) : nil
        let top = TokenArt.keepTop(at: .zero, radius: r, seat: seat)
        var needle: Path?
        if spire > 0 {
            var line = Path()
            line.move(to: CGPoint(x: -r * 0.35, y: top))
            line.addLine(to: CGPoint(x: -r * 0.35, y: top - r * 0.45 * CGFloat(spire)))
            needle = line
        }
        var bounds = keep.boundingRect
        for path in [flanks, ring, banner?.pole, banner?.pennant, needle].compactMap({ $0 }) { bounds = bounds.union(path.boundingRect) }
        let widest = max(CGFloat(walls) * 0.5 + 0.6, 1.6)
        bounds = bounds.insetBy(dx: -(widest / 2 + 1), dy: -(widest / 2 + 1))
        return (key, make(key, bounds: bounds, scale: scale) { cg in
            if let flanks {
                TokenStamps.fill(flanks, TokenStamps.holdFill, in: cg)
                TokenStamps.stroke(flanks, ink.copy(alpha: ink.alpha * 0.8) ?? ink, width: 1, in: cg)
            }
            if let ring {
                TokenStamps.fill(ring, TokenStamps.wallsFill, in: cg)
                TokenStamps.stroke(ring, ink.copy(alpha: ink.alpha * 0.7) ?? ink, width: CGFloat(walls) * 0.5 + 0.6, in: cg)
            }
            TokenStamps.fill(keep, TokenStamps.holdFill, in: cg)
            TokenStamps.stroke(keep, ink, width: seat ? 1.6 : 1.2, in: cg)
            // One warm window: someone keeps the lamp lit.
            TokenStamps.fill(TokenArt.window(at: .zero, radius: r), TokenStamps.windowLight, in: cg)
            if let banner {
                TokenStamps.stroke(banner.pole, ink, width: 1.1, in: cg)
                TokenStamps.fill(banner.pennant, ink, in: cg)
            }
            if let needle {
                TokenStamps.stroke(needle, TokenStamps.needle, width: 1.6, in: cg)
            }
        })
    }

    static func fill(_ path: Path, _ colour: CGColor, in cg: CGContext) {
        cg.addPath(path.cgPath)
        cg.setFillColor(colour)
        cg.fillPath()
    }

    static func stroke(_ path: Path, _ colour: CGColor, width: CGFloat, in cg: CGContext) {
        cg.addPath(path.cgPath)
        cg.setStrokeColor(colour)
        cg.setLineWidth(width)
        cg.strokePath()
    }

    /// Draws a token into an image of whole pixels about its centre, the
    /// points running down the page as SwiftUI's do, and keeps it.
    private func make(_ key: Key, bounds: CGRect, scale: CGFloat, draw: (CGContext) -> Void) -> Stamp {
        if stamps.count >= TokenStamps.most { stamps.removeAll() }
        let minX = (bounds.minX * scale).rounded(.down) / scale, minY = (bounds.minY * scale).rounded(.down) / scale
        let maxX = (bounds.maxX * scale).rounded(.up) / scale, maxY = (bounds.maxY * scale).rounded(.up) / scale
        let width = Int(((maxX - minX) * scale).rounded()), height = Int(((maxY - minY) * scale).rounded())
        var image: CGImage?
        if width > 0, height > 0,
           let cg = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) {
            cg.translateBy(x: 0, y: CGFloat(height))
            cg.scaleBy(x: scale, y: -scale)
            cg.translateBy(x: -minX, y: -minY)
            draw(cg)
            image = cg.makeImage()
        }
        made += 1
        let stamp = Stamp(image: image, offset: CGPoint(x: minX, y: minY), size: CGSize(width: maxX - minX, height: maxY - minY), scale: scale)
        stamps[key] = stamp
        return stamp
    }
}

/// The stamps a frame of the flat marks sets: each image readied for the
/// frame once, however many tokens it stands for, and every House's colour
/// worked out once.
@MainActor
struct StampsOfAFrame {
    let scale: CGFloat
    private var readied: [TokenStamps.Key: GraphicsContext.ResolvedImage] = [:]
    private var colours: [Int: Color.Resolved] = [:]

    init(for context: GraphicsContext) {
        scale = TokenStamps.scale(for: context)
    }

    /// A House's colour as the frame draws it.
    mutating func colour(of house: Int, _ colour: Color, in context: GraphicsContext) -> Color.Resolved {
        if let known = colours[house] { return known }
        let resolved = colour.resolve(in: context.environment)
        colours[house] = resolved
        return resolved
    }

    /// Sets a stamp with its token's centre at a point, on a whole pixel.
    mutating func set(_ keyed: (TokenStamps.Key, TokenStamps.Stamp), at point: CGPoint, in context: inout GraphicsContext) {
        let (key, stamp) = keyed
        guard let image = stamp.image else { return }
        let ready: GraphicsContext.ResolvedImage
        if let known = readied[key] {
            ready = known
        } else {
            ready = context.resolve(Image(decorative: image, scale: stamp.scale))
            readied[key] = ready
        }
        let x = (point.x * stamp.scale).rounded() / stamp.scale + stamp.offset.x
        let y = (point.y * stamp.scale).rounded() / stamp.scale + stamp.offset.y
        context.draw(ready, in: CGRect(x: x, y: y, width: stamp.size.width, height: stamp.size.height))
    }
}
