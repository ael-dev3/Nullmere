import LauncherCore
import SwiftUI

extension EnvironmentValues {
    /// How much the world moves: the display settings' Motion, the
    /// launcher's, with the system's Reduce Motion where it says to follow
    /// it. The map's water and stars run on a clock at its pace; below full
    /// motion, marches and blows are not played out.
    @Entry var worldMotion: ResolvedMotion = .full
    /// The display settings' frame rate cap, the launcher's.
    @Entry var worldFrameRate: FrameRateCap = .sixty
    /// The display settings' resolution, the launcher's: the most of the
    /// screen's pixels the map is drawn at.
    @Entry var worldQuality: RenderQuality = .native
}
