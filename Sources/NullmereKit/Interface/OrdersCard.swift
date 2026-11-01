import NullmereCore
import SwiftUI

/// Orders in the keeper's own words, at the foot of the world while asked
/// for: a line to write them on; the orders this Mac's model reads from
/// them, each with what it would do or why it can't be given; and those
/// that can, given together. Without the model, the order book's own lines
/// are read as they are written. Below them, the standing orders the
/// House's caretaker keeps while its keeper is away, if they gave any.
struct OrdersCard: View {
    let session: GameSession
    @State private var words: String
    @FocusState private var writing: Bool

    /// `words` begins the line: empty, or words already written.
    init(session: GameSession, words: String = "") {
        self.session = session
        _words = State(initialValue: words)
    }

    /// What the line asks for: words of the keeper's own, or the order
    /// book's lines where no model reads them.
    static func prompt(readByModel: Bool) -> String {
        readByModel ? "Your orders, in your own words" : "Order book lines, as MARCH C1 TO a place"
    }

    /// The button that gives the orders read, by how many can be given.
    static func giveTitle(_ count: Int) -> String {
        count == 1 ? "Give the order" : "Give \(count) orders"
    }

    var body: some View {
        let orders = session.ordersInWords ?? GameSession.OrdersInWords()
        let givable = orders.lines.filter { $0.command != nil && $0.why == nil }.count
        let prompt = Self.prompt(readByModel: session.readsOrders)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Caps("Orders", size: 8, weight: .medium)
                    .foregroundStyle(Palette.glowWords)
                TextField(prompt, text: $words)
                    .textFieldStyle(.plain)
                    .font(.nm(11.5))
                    .foregroundStyle(Palette.ink)
                    .padding(.vertical, 4)
                    .overlay(alignment: .bottom) { Rule(opacity: 0.5) }
                    .focused($writing)
                    .onSubmit(read)
                    .onExitCommand { session.toggleOrders() }
                    .accessibilityLabel(prompt)
                QuietButton(title: "Read", size: 8.5, enabled: !orders.reading && !blank, name: "Read the orders",
                            why: blank ? "Write what you would have done." : nil, action: read)
                CloseButton(label: "Put the orders away") { session.toggleOrders() }
            }
            if orders.reading {
                Text(verbatim: session.readsOrders ? "Your clerk reads your words…" : "Reading…")
                    .font(.nm(10.5, weight: .light))
                    .foregroundStyle(Palette.text(0.6))
            } else if orders.unread {
                Text(verbatim: "No orders could be read from those words. Name a company, a place, a work or a kind of company.")
                    .font(.nm(10.5))
                    .foregroundStyle(Palette.text(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(orders.lines.enumerated()), id: \.offset) { _, line in
                OrderLine(line: line)
            }
            if !orders.lines.isEmpty {
                HStack {
                    Text(verbatim: "Nothing is given until you give it; the realm judges each order as it always does.")
                        .font(.nm(9.5))
                        .foregroundStyle(Palette.text(0.45))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    QuietButton(title: Self.giveTitle(givable), size: 8.5, prominent: givable > 0, enabled: givable > 0 && !orders.reading,
                                name: "Give the orders read", why: givable == 0 ? "None of these orders can be given." : nil) {
                        session.giveOrders()
                    }
                }
            }
            let standing = session.state.standingOrders(of: session.player)
            if !standing.isEmpty {
                Rule(opacity: 0.4)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: standing.said)
                        .font(.nm(10))
                        .foregroundStyle(Palette.text(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    QuietButton(title: "Clear", size: 8.5, name: "Clear the standing orders") { session.perform(.standDown) }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 460, alignment: .leading)
        .panelBackground()
        .onAppear { writing = true }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Orders")
    }

    private var blank: Bool { words.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private func read() {
        guard !blank else { return }
        session.readOrders(words)
    }
}

/// One order read: what it would do, or that it can't be given and why.
struct OrderLine: View {
    let line: SpokenOrders.Line

    /// The line as VoiceOver says it.
    static func spoken(_ line: SpokenOrders.Line) -> String {
        line.why.map { "\(line.told) Can't be given: \($0)" } ?? line.told
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: line.why == nil ? "checkmark" : "xmark")
                .font(.nm(9, weight: .medium))
                .foregroundStyle(line.why == nil ? Palette.good : Palette.bad)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: line.told)
                    .font(.nm(11))
                    .foregroundStyle(Palette.text(line.why == nil ? 0.9 : 0.6))
                if let why = line.why {
                    Text(verbatim: why)
                        .font(.nm(10))
                        .foregroundStyle(Palette.bad)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.spoken(line))
    }
}
