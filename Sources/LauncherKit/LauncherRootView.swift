import LauncherCore
import SwiftUI

/// The launcher window: the lake, the title resting above the far shore, and
/// the menu or a panel on the water below it.
public struct LauncherRootView: View {
    private let model: LauncherModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(model: LauncherModel) {
        self.model = model
    }

    public var body: some View {
        GeometryReader { proxy in
            let unit = CGFloat(LakeComposition.unit(forHeight: proxy.size.height))
            let waterline = CGFloat(LakeComposition.waterline(forHeight: proxy.size.height))

            ZStack(alignment: .top) {
                LakeBackdrop(configuration: model.backdropConfiguration(systemReducesMotion: reduceMotion))

                // The lake surfaces from black when the launcher opens.
                Color.black
                    .opacity(model.intro.showsScene ? 0 : 1)
                    .allowsHitTesting(false)

                TitleBlock(isRevealed: model.intro.showsTitle, settlesLetters: !reduceMotion)
                    .frame(maxWidth: .infinity)
                    .frame(height: max(waterline - 36 * unit, 0), alignment: .bottom)

                ScreenContent(model: model)
                    .opacity(model.intro.showsMenu ? 1 : 0)
                    .allowsHitTesting(model.intro.showsMenu)
                    .frame(maxWidth: .infinity)
                    .padding(.top, waterline)
                    .animation(.easeInOut(duration: 0.5), value: model.screen)

                LauncherFooter(version: model.version, hint: model.footerHint) {
                    model.openWebsite()
                }
                .opacity(model.intro.showsMenu ? 1 : 0)
                .allowsHitTesting(model.intro.showsMenu)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .animation(.easeInOut(duration: 0.5), value: model.footerHint)

                // A click during the opening skips it.
                if model.intro != .complete {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { model.completeIntro() }
                }

                // Quitting fades everything to black.
                Color.black
                    .opacity(model.isQuitting ? 1 : 0)
                    .allowsHitTesting(model.isQuitting)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .environment(\.launcherUnit, unit)
        }
        .ignoresSafeArea()
        .frame(minWidth: 960, minHeight: 600)
        .background(Color.black)
        .preferredColorScheme(.dark)
        .background(
            WindowBridge(startsInFullScreen: model.settings.startsInFullScreen) { key in
                model.handle(key)
            }
        )
        .onAppear {
            model.beginIntro(systemReducesMotion: reduceMotion)
        }
    }
}

/// The menu or the open panel. Each sits at its own depth below the waterline.
private struct ScreenContent: View {
    let model: LauncherModel

    @Environment(\.launcherUnit) private var unit

    var body: some View {
        ZStack(alignment: .top) {
            switch model.screen {
            case .title:
                MainMenu(model: model)
                    .padding(.top, 92 * unit)
                    .transition(.opacity)
            case .settings:
                SettingsPanel(model: model)
                    .padding(.top, 52 * unit)
                    .transition(.opacity)
            case .play:
                PlayPanel(model: model)
                    .padding(.top, 60 * unit)
                    .transition(.opacity)
            }
        }
    }
}
