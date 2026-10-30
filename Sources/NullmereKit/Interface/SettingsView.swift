import LauncherCore
import LauncherKit
import SwiftUI

/// The realm's Settings (⌘,), over the front door or the world, in the
/// realm's own quiet type, Larger type and all: how the lake, the map and
/// the type are drawn, the launcher's own display settings shared; how
/// loud each part of the sound plays; the keys; and counsel.
public struct GameSettingsView: View {
    @Bindable private var app: GameApp
    @AppStorage("counsel.hidden") private var counselHidden = false
    @AppStorage(LetterKeys.defaultsKey) private var lettersAlone = true

    public init(app: GameApp) {
        self.app = app
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PanelTitle(title: "Settings", subtitle: "The launcher's display settings, and the realm's own")
            part("Display") {
                ForEach(SettingsRow.allCases, id: \.self) { row in
                    ChoiceLine(title: row.title, options: app.displaySettings.options(for: row),
                               chosen: app.displaySettings.selectedIndex(for: row)) { app.display?.setDisplay(row, to: $0) }
                }
                Note("Motion is how much the lake and the map move; System follows Reduce Motion. Text set to Larger makes all the type a fifth larger.")
            }
            part("Sound") {
                ChoiceLine(title: "Sound", options: ["Off", "On"], chosen: app.isSoundOn ? 1 : 0) { app.isSoundOn = $0 == 1 }
                VolumeLine(title: "Effects", help: "Orders, battles, bells and envoys", value: $app.effectsVolume, enabled: app.isSoundOn)
                VolumeLine(title: "The night", help: "The drone and the wind over the water", value: $app.ambienceVolume,
                           enabled: app.isSoundOn)
                ChoiceLine(title: "Music", options: ["Off", "On"], chosen: app.isMusicOn ? 1 : 0, enabled: app.isSoundOn) {
                    app.isMusicOn = $0 == 1
                }
                VolumeLine(title: "The score", help: "The music, written as it plays", value: $app.musicVolume,
                           enabled: app.isSoundOn && app.isMusicOn)
                ChoiceLine(title: "The advisor", options: ["Silent", "Speaks"], chosen: app.isAdvisorOn ? 1 : 0, enabled: app.isSoundOn) {
                    app.isAdvisorOn = $0 == 1
                }
                Note("The advisor reads each new charge aloud in your Mac's voice; silent while VoiceOver speaks.")
            }
            part("Keys") {
                ChoiceLine(title: "Letter keys", options: ["Alone", "With ⌥"], chosen: lettersAlone ? 0 : 1) { lettersAlone = $0 == 0 }
                Note("With ⌥: F, M, B, H and the game's other letter, number and mark keys need ⌥ held, so a stray key does nothing. Tab, the arrows, Space, Return and Esc act as ever.")
            }
            part("Counsel") {
                ChoiceLine(title: "Counsel", options: ["Shown", "Hidden"], chosen: counselHidden ? 1 : 0) { counselHidden = $0 == 1 }
                Note("Counsel guides the opening and warns of the race for the lake.")
            }
        }
        .padding(22)
        .frame(width: 480)
    }

    /// A part of the settings under its name.
    private func part(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Caps(title, size: 9, weight: .medium)
                .foregroundStyle(Palette.glowWords)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }
}

/// A setting's line: its name, and its choices side by side, the one chosen
/// lit and underlined, chosen by a click or by keyboard navigation; to
/// VoiceOver, a Mac's own pop-up menu of them, as the launcher's are.
struct ChoiceLine: View {
    let title: String
    let options: [String]
    let chosen: Int
    var enabled = true
    let choose: (Int) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(verbatim: title)
                .font(.nm(12))
                .foregroundStyle(Palette.text(enabled ? 0.92 : 0.6))
            Spacer(minLength: 12)
            HStack(spacing: 2) {
                ForEach(options.indices, id: \.self) { index in
                    QuietButton(title: options[index], size: 9.5, enabled: enabled, tint: index == chosen ? Palette.ink : nil) {
                        choose(index)
                    }
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(Palette.line(0.6))
                            .frame(height: 1)
                            .padding(.horizontal, 8)
                            .padding(.bottom, 3)
                            .opacity(index == chosen ? 1 : 0)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
        .accessibilityRepresentation {
            Picker(title, selection: Binding(get: { chosen }, set: { choose($0) })) {
                ForEach(options.indices, id: \.self) { index in
                    Text(verbatim: options[index]).tag(index)
                }
            }
            .disabled(!enabled)
        }
    }
}

/// How loud a part of the sound plays: its name and what it is, and a
/// slider in the realm's colour; to VoiceOver, its name and how loud.
struct VolumeLine: View {
    let title: String
    let help: String
    @Binding var value: Double
    var enabled = true

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title)
                    .font(.nm(12))
                    .foregroundStyle(Palette.text(enabled ? 0.92 : 0.6))
                Text(verbatim: help)
                    .font(.nm(10.5))
                    .foregroundStyle(Palette.text(0.75))
            }
            Spacer(minLength: 12)
            Slider(value: $value, in: 0...1)
                .tint(Palette.glow)
                .frame(width: 180)
                .disabled(!enabled)
                .accessibilityLabel(title)
                .accessibilityValue("\(Int((value * 100).rounded())) per cent")
        }
    }
}

/// A word on what the settings above it do.
private struct Note: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(verbatim: text)
            .font(.nm(10.5))
            .foregroundStyle(Palette.text(0.75))
            .fixedSize(horizontal: false, vertical: true)
    }
}
