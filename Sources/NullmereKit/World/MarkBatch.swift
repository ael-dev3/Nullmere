import SwiftUI

/// Marks gathered by how they are drawn, to be drawn together: a Canvas
/// pays for every fill and stroke it is asked for, so the many small marks
/// of one look (every shield's face, every rim in one House's colour) go
/// as one path. Drawn layer by layer, under to over, and within a layer in
/// the order its looks were first met, so each token stacks as it would
/// drawn alone.
struct MarkBatch {
    /// The order marks are drawn in, under to over: a hold's, then a
    /// company's.
    enum Layer: Int {
        case warning, towers, towerRims, walls, wallRims, keeps, keepRims, windows, poles, pennants, needles
        case shields, rims, halos, glyphs
        case ownership, chevrons, dots, barBack, bar
    }

    enum Paint: Hashable {
        case fill
        case stroke(CGFloat)
        /// Broken, like a warning.
        case dashed(CGFloat)
    }

    private struct Look: Hashable {
        let layer: Layer
        let colour: Color
        let paint: Paint
    }

    private var looks: [Look] = []
    private var paths: [Look: Path] = [:]

    /// How many paths it draws, however many marks went into them.
    var count: Int { looks.count }

    mutating func add(_ path: Path, _ layer: Layer, _ colour: Color, _ paint: Paint) {
        let look = Look(layer: layer, colour: colour, paint: paint)
        if paths[look] == nil {
            looks.append(look)
            paths[look] = path
        } else {
            paths[look]?.addPath(path)
        }
    }

    func draw(in context: inout GraphicsContext) {
        let ordered = looks.enumerated().sorted { ($0.element.layer.rawValue, $0.offset) < ($1.element.layer.rawValue, $1.offset) }
        for (_, look) in ordered {
            guard let path = paths[look] else { continue }
            switch look.paint {
            case .fill:
                context.fill(path, with: .color(look.colour))
            case .stroke(let width):
                context.stroke(path, with: .color(look.colour), lineWidth: width)
            case .dashed(let width):
                context.stroke(path, with: .color(look.colour), style: StrokeStyle(lineWidth: width, dash: [4, 3]))
            }
        }
    }
}
