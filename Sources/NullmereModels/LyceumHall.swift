import Foundation

/// The Lyceum's hall, where the realm's scholars sit: a round house of
/// pale stone on a stepped drum, ten columns about a lit inner wall, a
/// shallow dome of slate with an open eye at its crown, braziers between
/// its four doors and lecterns before them. Over the eye an orrery of
/// moonsalt rings turns while the Lyceum sits, drawn apart so it can turn.
/// It fills the heart of its hex, its doors to ±x and ±z. Both are made in
/// Blender (Art/blender/lyceum.py, read by `Art.lyceum`); these are the
/// measures the world places them by.
public enum LyceumHall {
    static let drum: Float = 0.08
    static let crown: Float = 0.47
    /// Where the orrery turns, over the dome's eye.
    public static let orreryAt = Vec3(0, crown + 0.04, 0)
    /// The braziers before the doors, where smoke goes up.
    static let braziers: [Vec3] = (0..<4).map { MeshBuilder.ring(0.47, drum + 0.13, Float($0) * .pi / 2 + .pi / 4) }
}
