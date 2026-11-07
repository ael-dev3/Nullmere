import Foundation
import NullmereCompanionCore
import NullmereCore
import NullmereCounsel
import SwiftUI

/// Orders in the keeper's own words, from the phone, as on the Mac: read by
/// Apple's on-device model on this phone into the order book's lines, given
/// the briefing of what the House has and knows, or as the order book's
/// lines as written where it can't, and why; each line with the order the
/// realm would take or why not; nothing given until the keeper gives it,
/// and then each order judged by the realm as any is.
struct OrdersInWordsView: View {
    let session: CompanionSession
    let close: () -> Void
    @State private var words = ""
    @StateObject private var reader = WordsReading()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(verbatim: reader.clerk.unavailable
                         ?? "Read by Apple's on-device model on this phone, given what your House has and knows. Nothing is given until you give it.")
                        .font(Night.small)
                        .foregroundStyle(reader.clerk.unavailable == nil ? Night.ink.opacity(0.7) : Night.bad)
                        .fixedSize(horizontal: false, vertical: true)
                    TextField("Dig in the spears at the seat and raise a granary there", text: $words, axis: .vertical)
                        .lineLimit(3...6)
                        .font(Night.body)
                        .accessibilityLabel("Your orders, in your own words")
                    HStack(spacing: 12) {
                        if reader.busy {
                            ProgressView()
                                .tint(Night.moon)
                            Button("Stop") { stop() }
                                .accessibilityHint("Stops the reading; nothing is read or given")
                        } else {
                            Button("Read") { read() }
                                .disabled(words.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .font(Night.body)
                }
                if let reading = reader.reading {
                    Section {
                        Text(verbatim: reading.summary)
                            .font(Night.small)
                            .foregroundStyle(Night.moon)
                        if let trouble = reading.trouble {
                            Text(verbatim: trouble)
                                .font(Night.small)
                                .foregroundStyle(Night.bad)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        ForEach(Array(reading.lines.enumerated()), id: \.offset) { line in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: line.element.text)
                                    .font(.system(.footnote, design: .monospaced))
                                    .foregroundStyle(Night.ink.opacity(0.6))
                                Text(verbatim: line.element.why ?? line.element.told)
                                    .font(Night.body)
                                    .foregroundStyle(line.element.why == nil ? Night.ink : Night.bad)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .accessibilityElement(children: .combine)
                        }
                        if !reading.takeable.isEmpty {
                            Button(reading.takeable.count == 1 ? "Give the order" : "Give the \(reading.takeable.count) orders") {
                                give(reading)
                            }
                            .font(Night.body)
                        }
                    }
                }
                Section {
                    DisclosureGroup("The order book's lines, and your companies") {
                        ForEach(SpokenOrders.forms, id: \.self) { form in
                            Text(verbatim: form)
                                .font(.system(.footnote, design: .monospaced))
                        }
                        ForEach(Array(handles.enumerated()), id: \.offset) { handle in
                            Text(verbatim: handle.element)
                                .font(Night.small)
                        }
                    }
                    .font(Night.small)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Night.background)
            .navigationTitle("In your own words")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        stop()
                        close()
                    }
                }
            }
        }
        .onAppear {
            #if DEBUG
            // Seen by the smoke test with a line of the order book read.
            if CompanionCheck.wordsShown, words.isEmpty {
                words = "FORTIFY C1"
                read()
            }
            #endif
        }
        .onDisappear { stop() }
    }

    /// The House's companies as the briefing numbers them: C1, C2 and on.
    private var handles: [String] {
        guard let world = session.world, let house = session.keeper?.house else { return [] }
        return SpokenOrders.companies(in: world, player: house).prefix(SpokenOrders.briefedCompanies).enumerated().map { index, unit in
            "C\(index + 1): \(SpokenOrders.named(unit, in: world))"
        }
    }

    /// Reads the words against the House's view as it stands now.
    private func read() {
        guard let world = session.world, let house = session.keeper?.house else { return }
        reader.read(words, in: world, player: house)
    }

    private func stop() {
        reader.stop()
    }

    /// Gives the orders the realm would take as read, one after another,
    /// each judged as any order is; the realm's word on the last follows on
    /// the Army tab.
    private func give(_ reading: SpokenOrders.Reading) {
        for line in reading.takeable {
            if let command = line.command { session.give(command, told: line.told) }
        }
        reader.clear()
        words = ""
        close()
    }
}

/// A reading of the keeper's words under way, or the last made: one at a
/// time, a reading begun again outdoing one still under way, a reading
/// stopped reading nothing.
@MainActor
final class WordsReading: ObservableObject {
    @Published private(set) var reading: SpokenOrders.Reading?
    @Published private(set) var busy = false
    let clerk = OrderClerk()
    private var task: Task<Void, Never>?
    private var serial = 0

    func read(_ words: String, in world: GameState, player: Int) {
        task?.cancel()
        serial += 1
        let mine = serial
        busy = true
        let clerk = clerk
        task = Task { [weak self] in
            let made = await clerk.read(words, in: world, player: player)
            guard let self, self.serial == mine else { return }
            self.reading = made
            self.busy = false
            self.task = nil
        }
    }

    func stop() {
        guard busy else { return }
        task?.cancel()
        task = nil
        serial += 1
        busy = false
        reading = .stopped
    }

    func clear() {
        reading = nil
    }
}
