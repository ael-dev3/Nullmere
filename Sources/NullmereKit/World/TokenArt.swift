import CoreGraphics
import NullmereCore
import SwiftUI

/// The pieces on the map, drawn as paths: original line art in the
/// launcher's spare style.
enum TokenArt {
    /// A keep: a tapering stone tower with three merlons, standing on its
    /// centre. A seat stands taller.
    static func keep(at c: CGPoint, radius r: CGFloat, seat: Bool) -> Path {
        let w = 0.62 * r
        let top = c.y - (seat ? 1.55 : 1.2) * r
        let base = c.y + 0.9 * r
        let notch = 0.28 * r
        var p = Path()
        p.move(to: CGPoint(x: c.x - w * 1.25, y: base))
        p.addLine(to: CGPoint(x: c.x - w, y: top + notch))
        let step = 2 * w / 5
        var x = c.x - w
        for i in 0..<5 {
            let y = i % 2 == 0 ? top : top + notch
            p.addLine(to: CGPoint(x: x, y: y))
            x += step
            p.addLine(to: CGPoint(x: x, y: y))
        }
        p.addLine(to: CGPoint(x: c.x + w, y: top + notch))
        p.addLine(to: CGPoint(x: c.x + w * 1.25, y: base))
        p.closeSubpath()
        return p
    }

    /// The keep's one lit window.
    static func window(at c: CGPoint, radius r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - 0.14 * r, y: c.y - 0.45 * r, width: 0.28 * r, height: 0.4 * r))
    }

    /// The top of a keep, where a banner or a spire rises.
    static func keepTop(at c: CGPoint, radius r: CGFloat, seat: Bool) -> CGFloat {
        c.y - (seat ? 1.55 : 1.2) * r
    }

    /// A seat's banner: a pole and a pennant.
    static func banner(at c: CGPoint, radius r: CGFloat) -> (pole: Path, pennant: Path) {
        let top = keepTop(at: c, radius: r, seat: true)
        var pole = Path()
        pole.move(to: CGPoint(x: c.x, y: top))
        pole.addLine(to: CGPoint(x: c.x, y: top - 0.75 * r))
        var pennant = Path()
        pennant.move(to: CGPoint(x: c.x, y: top - 0.75 * r))
        pennant.addLine(to: CGPoint(x: c.x + 0.6 * r, y: top - 0.6 * r))
        pennant.addLine(to: CGPoint(x: c.x, y: top - 0.42 * r))
        pennant.closeSubpath()
        return (pole, pennant)
    }

    /// Side towers for a hold that has grown: one beside the keep after
    /// a few works, a second after many.
    static func towers(at c: CGPoint, radius r: CGFloat, count: Int) -> Path {
        var p = Path()
        let width = 0.36 * r
        let base = c.y + 0.9 * r
        let top = c.y - 0.7 * r
        for side in [-1.0, 1.0].prefix(min(max(count, 0), 2)) {
            let x = c.x + CGFloat(side) * 1.02 * r
            let left = x - width / 2, right = x + width / 2
            let notch = 0.16 * r
            p.move(to: CGPoint(x: left, y: base))
            p.addLine(to: CGPoint(x: left, y: top))
            p.addLine(to: CGPoint(x: x - width / 6, y: top))
            p.addLine(to: CGPoint(x: x - width / 6, y: top + notch))
            p.addLine(to: CGPoint(x: x + width / 6, y: top + notch))
            p.addLine(to: CGPoint(x: x + width / 6, y: top))
            p.addLine(to: CGPoint(x: right, y: top))
            p.addLine(to: CGPoint(x: right, y: base))
            p.closeSubpath()
        }
        return p
    }

    /// How many side towers a hold shows for the works it has raised
    /// (walls and the Moonspire have their own marks).
    static func towerCount(for hold: Hold) -> Int {
        let works = hold.levels.filter { $0.key != .walls && $0.key != .moonspire }.values.reduce(0, +)
        return works >= 8 ? 2 : (works >= 3 ? 1 : 0)
    }

    /// A low ring of walls at the keep's foot, for walled holds.
    static func walls(at c: CGPoint, radius r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - 1.15 * r, y: c.y + 0.45 * r, width: 2.3 * r, height: 0.9 * r))
    }

    /// A company's shield: a heater shield with its point down.
    static func shield(at c: CGPoint, radius r: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: c.x - 0.85 * r, y: c.y - 0.85 * r))
        p.addLine(to: CGPoint(x: c.x + 0.85 * r, y: c.y - 0.85 * r))
        p.addLine(to: CGPoint(x: c.x + 0.85 * r, y: c.y + 0.05 * r))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + 1.0 * r), control: CGPoint(x: c.x + 0.8 * r, y: c.y + 0.7 * r))
        p.addQuadCurve(to: CGPoint(x: c.x - 0.85 * r, y: c.y + 0.05 * r), control: CGPoint(x: c.x - 0.8 * r, y: c.y + 0.7 * r))
        p.closeSubpath()
        return p
    }
}
