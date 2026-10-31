import NullmereCore
import SwiftUI

/// The House's Archive: its tree of studies in four branches, each study's
/// grade, what its next grade does, costs and takes, and why it can't be
/// begun yet when it can't.
struct ArchivePanel: View {
    let session: GameSession

    var body: some View {
        let board = session.state.archiveBoard(for: session.player)
        let stock = session.playerHouse.stock
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PanelTitle(title: "Archive", subtitle: ArchivePanel.subtitle(board))
                CloseButton(label: "Close the Archive") { session.panel = nil }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let pursuit = board.pursuit {
                        let total = session.state.studyWatches(of: pursuit.study, grade: pursuit.grade, for: session.player)
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Caps("\(pursuit.study.title) \(Narration.roman(pursuit.grade))", size: 9.5, weight: .medium)
                                    .foregroundStyle(Palette.glowWords)
                                Spacer()
                                Text(verbatim: ArchivePanel.left(pursuit.watchesLeft))
                                    .font(.nm(10.5))
                                    .foregroundStyle(Palette.text(0.65))
                            }
                            Meter(fraction: 1 - Double(pursuit.watchesLeft) / Double(max(total, pursuit.watchesLeft, 1)))
                        }
                        .accessibilityElement(children: .combine)
                    } else if board.archive == 0 {
                        Text(verbatim: "Build an Archive at a hold to begin. Its level opens each circle of studies.")
                            .font(.nm(10.5))
                            .foregroundStyle(Palette.text(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(board.shelves) { shelf in
                        Rule(opacity: 0.18)
                        Caps(shelf.branch.title, size: 9, weight: .medium)
                            .foregroundStyle(Palette.text(0.7))
                            .accessibilityAddTraits(.isHeader)
                        ForEach(shelf.lines) { line in
                            StudyRow(session: session, line: line, stock: stock)
                        }
                    }
                }
            }
            .scrollEdgeFade()
            .scrollIndicators(.never)
            .pagedByKeys(session, as: .panel(.archive))
        }
        .padding(16)
        .frame(width: PanelWidth.rail)
        .frame(maxHeight: 620)
        .panelBackground()
    }

    static func subtitle(_ board: ArchiveBoard) -> String {
        guard board.archive > 0 else { return "No Archive yet" }
        return "Archive \(Narration.roman(board.archive)) · \(board.learned) of \(ArchiveBoard.gradesInAll) grades learned"
    }

    static func left(_ watches: Int) -> String {
        watches == 1 ? "Done next watch" : "\(watches) watches left"
    }

    /// Why a study can't be begun, as the button says it.
    static func why(_ standing: StudyLine.Standing) -> String? {
        switch standing {
        case .open: return nil
        case .short(let lack): return "You are short of \(lack.description)."
        case .waiting: return "Another study is under way; one at a time."
        case .locked(let why): return why.description
        case .underWay: return "Under way."
        case .mastered: return "Learned to its last grade."
        }
    }
}

/// One study: its grade, what the next does, costs and takes, and the
/// button that begins it.
private struct StudyRow: View {
    let session: GameSession
    let line: StudyLine
    let stock: Stock

    var body: some View {
        let study = line.study
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline) {
                    Caps(study.title, size: 9.5, weight: .medium)
                        .foregroundStyle(Palette.text(isShut ? 0.45 : 0.9))
                    LevelPips(level: line.grade, maximum: study.grades)
                }
                .accessibilityElement(children: .combine)
                Spacer()
                switch line.standing {
                case .mastered:
                    Text(verbatim: "Learned").font(.nm(10)).foregroundStyle(Palette.text(0.5))
                case .underWay(let left):
                    Text(verbatim: ArchivePanel.left(left)).font(.nm(10)).foregroundStyle(Palette.glowWords)
                default:
                    if let next = line.next {
                        QuietButton(title: "Study \(Narration.roman(next))", size: 8.5, enabled: line.standing == .open,
                                    name: "Study \(study.title) \(Narration.roman(next))", why: ArchivePanel.why(line.standing)) {
                            session.perform(.study(study))
                        }
                        .beckoned(session.beckon == .study && line.standing == .open)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: study.effect)
                    .font(.nm(10.5))
                    .foregroundStyle(Palette.text(0.55))
                    .fixedSize(horizontal: false, vertical: true)
                if case .locked(let why) = line.standing {
                    Text(verbatim: why.description)
                        .font(.nm(10))
                        .foregroundStyle(Palette.text(0.45))
                        .fixedSize(horizontal: false, vertical: true)
                } else if let price = line.price, let watches = line.watches, line.standing != .mastered {
                    HStack(spacing: 10) {
                        CostLine(cost: price, available: stock)
                        Text(verbatim: "\(watches) watch\(watches == 1 ? "" : "es")")
                            .font(.nm(10))
                            .foregroundStyle(Palette.text(0.45))
                    }
                }
            }
            .accessibilityElement(children: .combine)
        }
        .padding(.vertical, 2)
    }

    private var isShut: Bool {
        if case .locked = line.standing { return true }
        return false
    }
}
