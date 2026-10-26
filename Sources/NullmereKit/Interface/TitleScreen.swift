import AppKit
import LauncherKit
import NullmereCore
import SwiftUI

/// The game's first screen: the moonlit lake, the name, and the choices
/// that shape a new world.
struct TitleScreen: View {
    let app: GameApp

    @AppStorage("newGame.seed") private var seed = SeedWords.random()
    @AppStorage("newGame.house") private var house = Names.houses[0]
    @AppStorage("newGame.houseCount") private var houseCount = 5
    @AppStorage("newGame.size") private var size = WorldSize.middling.rawValue
    @AppStorage("newGame.difficulty") private var difficulty = Difficulty.even.rawValue
    @State private var appeared = false
    @State private var confirmingNewWorld = false

    var body: some View {
        ZStack {
            MoonlitLake()
                .ignoresSafeArea()
            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer(minLength: 40)
                VStack(spacing: 14) {
                    Text(verbatim: "NULLMERE")
                        .font(.system(size: 76, weight: .thin))
                        .tracking(appeared ? 30 : 46)
                        .foregroundStyle(Palette.ink)
                        .shadow(color: Palette.glow.opacity(0.35), radius: 24)
                        .accessibilityAddTraits(.isHeader)
                    Caps("A game of Houses around a dead lake", size: 10, tracking: 0.5)
                        .foregroundStyle(Palette.ink.opacity(0.6))
                }
                .opacity(appeared ? 1 : 0)
                Spacer(minLength: 40)

                VStack(spacing: 18) {
                    NewWorldForm(seed: $seed, house: $house, houseCount: $houseCount, size: $size, difficulty: $difficulty)
                    HStack(spacing: 10) {
                        if app.hasSave {
                            QuietButton(title: "Continue", size: 11) { app.continueSaved() }
                        }
                        QuietButton(title: "Begin", size: 11, prominent: true) {
                            if app.hasSave { confirmingNewWorld = true } else { begin() }
                        }
                        .keyboardShortcut(.defaultAction)
                        .confirmationDialog("Begin a new world?", isPresented: $confirmingNewWorld) {
                            Button("Begin a New World", role: .destructive) { begin() }
                            Button("Continue the Saved Game") { app.continueSaved() }
                        } message: {
                            Text(verbatim: "Your saved game will be replaced.")
                        }
                        QuietButton(title: "Quit", size: 11) { NSApp.terminate(nil) }
                    }
                }
                .padding(.vertical, 22)
                .padding(.horizontal, 28)
                .panelBackground()
                .overlay(alignment: .bottom) {
                    if let notice = app.saveNotice {
                        Text(verbatim: notice)
                            .font(.system(size: 11, weight: .light))
                            .foregroundStyle(Palette.bad)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 420)
                            .offset(y: 34)
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                Spacer(minLength: 48)
            }
            .padding(.horizontal, 32)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 2.2)) { appeared = true }
        }
    }

    private func begin() {
        let words = seed.trimmingCharacters(in: .whitespacesAndNewlines)
        if words.isEmpty { seed = SeedWords.random() }
        let radius = (WorldSize(rawValue: size) ?? .middling).radius
        app.begin(GameSettings(
            seedText: words.isEmpty ? seed : words,
            houseCount: min(max(houseCount, 2), 8),
            radius: radius,
            playerHouse: Names.houses.contains(house) ? house : Names.houses[0],
            difficulty: Difficulty(rawValue: difficulty) ?? .even
        ))
    }
}

private struct NewWorldForm: View {
    @Binding var seed: String
    @Binding var house: String
    @Binding var houseCount: Int
    @Binding var size: String
    @Binding var difficulty: String

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 12) {
            GridRow {
                label("World")
                HStack(spacing: 8) {
                    TextField("Words that name the world", text: $seed)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 220)
                        .padding(.vertical, 4)
                        .overlay(alignment: .bottom) { Rule(opacity: 0.45) }
                        .accessibilityLabel("World seed")
                    Button {
                        seed = SeedWords.random()
                    } label: {
                        Image(systemName: "dice")
                            .font(.system(size: 12, weight: .light))
                            .foregroundStyle(Palette.ink.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("Other words, another world")
                    .accessibilityLabel("Choose other words")
                }
            }
            GridRow {
                label("House")
                Picker("House", selection: $house) {
                    ForEach(Names.houses, id: \.self) { Text(verbatim: "House \($0)").tag($0) }
                }
                .labelsHidden()
                .frame(width: 180)
            }
            GridRow {
                label("Rivals")
                Picker("Rivals", selection: $houseCount) {
                    ForEach(2...8, id: \.self) { count in
                        Text(verbatim: "\(count - 1)").tag(count)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 260)
            }
            GridRow {
                label("Rivals play")
                Picker("Rivals play", selection: $difficulty) {
                    ForEach(Difficulty.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 260)
                .help("Gentle: rivals start poorer and are slow to war on you. Merciless: richer, and quick to.")
            }
            GridRow {
                label("Lake")
                Picker("Lake", selection: $size) {
                    ForEach(WorldSize.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 260)
            }
        }
    }

    private func label(_ text: String) -> some View {
        Caps(text, size: 9, weight: .medium)
            .foregroundStyle(Palette.ink.opacity(0.55))
            .gridColumnAlignment(.trailing)
    }
}

enum WorldSize: String, CaseIterable {
    case narrow
    case middling
    case vast

    var title: String {
        switch self {
        case .narrow: return "Narrow"
        case .middling: return "Wide"
        case .vast: return "Vast"
        }
    }

    var radius: Int {
        switch self {
        case .narrow: return 18
        case .middling: return 24
        case .vast: return 30
        }
    }
}

/// Two words that name a world.
enum SeedWords {
    private static let first = [
        "black", "still", "drowned", "silver", "hollow", "cold", "pale", "sunken",
        "quiet", "salt", "ashen", "deep", "veiled", "last", "white", "iron",
    ]
    private static let second = [
        "moon", "water", "shore", "crown", "lantern", "spire", "tide", "mirror",
        "reed", "barrow", "star", "hour", "gate", "vigil", "ember", "harbour",
    ]

    static func random() -> String {
        "\(first.randomElement()!) \(second.randomElement()!)"
    }
}
