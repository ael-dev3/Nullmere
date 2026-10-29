import LauncherCore
import SwiftUI

/// The realm's Settings (⌘,), over the front door or the world: how the
/// lake and the map are drawn, the launcher's own display settings shared;
/// how loud each part of the sound plays; and how the interface reads.
public struct GameSettingsView: View {
    @Bindable private var app: GameApp
    @Bindable private var text = TextSize.shared
    @AppStorage("counsel.hidden") private var counselHidden = false

    public init(app: GameApp) {
        self.app = app
    }

    public var body: some View {
        Form {
            Section("Display") {
                ForEach(SettingsRow.allCases, id: \.self) { row in
                    Picker(row.title, selection: displayChoice(for: row)) {
                        ForEach(Array(app.displaySettings.options(for: row).enumerated()), id: \.offset) { index, option in
                            Text(verbatim: option).tag(index)
                        }
                    }
                }
                Text("Motion is how much the lake and the map move; System follows Reduce Motion. The same settings as the launcher's.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Section("Sound") {
                Toggle("Sound", isOn: $app.isSoundOn)
                volume("Effects", value: $app.effectsVolume, help: "Orders, battles, bells and envoys")
                    .disabled(!app.isSoundOn)
                volume("The night", value: $app.ambienceVolume, help: "The drone and the wind over the water")
                    .disabled(!app.isSoundOn)
                Toggle("Music", isOn: $app.isMusicOn)
                    .disabled(!app.isSoundOn)
                volume("The score", value: $app.musicVolume, help: "The music, written as it plays")
                    .disabled(!app.isSoundOn || !app.isMusicOn)
            }
            Section("Reading") {
                Toggle("Larger text", isOn: $text.isLarger)
                Toggle("Show counsel", isOn: Binding(get: { !counselHidden }, set: { counselHidden = !$0 }))
                Text("Counsel guides the opening and warns of the race for the lake.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// A display setting's choice, read from and written to the launcher's.
    private func displayChoice(for row: SettingsRow) -> Binding<Int> {
        Binding(get: { app.displaySettings.selectedIndex(for: row) },
                set: { app.display?.setDisplay(row, to: $0) })
    }

    private func volume(_ title: String, value: Binding<Double>, help: String) -> some View {
        LabeledContent {
            Slider(value: value, in: 0...1)
                .frame(width: 200)
                .accessibilityLabel(title)
                .accessibilityValue("\(Int((value.wrappedValue * 100).rounded())) per cent")
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(help).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
