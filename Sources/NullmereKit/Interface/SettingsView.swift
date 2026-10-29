import SwiftUI

/// The game's settings, under Nullmere ▸ Settings… (⌘,): how loud each
/// part of the sound plays, and how the interface reads.
public struct GameSettingsView: View {
    @Bindable private var app: GameApp
    @Bindable private var text = TextSize.shared
    @AppStorage("counsel.hidden") private var counselHidden = false

    public init(app: GameApp) {
        self.app = app
    }

    public var body: some View {
        Form {
            Section("Sound") {
                Toggle("Play sound", isOn: $app.isSoundOn)
                volume("Effects", value: $app.effectsVolume, help: "Orders, battles, bells and envoys")
                    .disabled(!app.isSoundOn)
                volume("The night", value: $app.ambienceVolume, help: "The drone and the wind over the water")
                    .disabled(!app.isSoundOn)
                Toggle("Play the score", isOn: $app.isMusicOn)
                    .disabled(!app.isSoundOn)
                volume("Music", value: $app.musicVolume, help: "The score, written as it plays")
                    .disabled(!app.isSoundOn || !app.isMusicOn)
            }
            Section("Reading") {
                Toggle("Larger text", isOn: $text.isLarger)
                Toggle("Show counsel", isOn: Binding(get: { !counselHidden }, set: { counselHidden = !$0 }))
                Text("Counsel guides the opening and warns of the race for the lake. Motion follows Reduce Motion in System Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
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
