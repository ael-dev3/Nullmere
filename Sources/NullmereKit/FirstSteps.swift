import Foundation
import NullmereCore

/// A new keeper's first three things to do, ticked off as they do them,
/// and kept on this Mac until all are done.
struct FirstSteps: Codable, Equatable {
    enum Step: String, Codable, CaseIterable {
        case work, march, ready

        var title: String {
            switch self {
            case .work: return "Give a hold a work to build"
            case .march: return "March a company: select it, right-click where it should go"
            case .ready: return "Say you're ready (⌘↩) when your orders are given"
            }
        }
    }

    private(set) var done: Set<Step> = []

    var isComplete: Bool { done.count == Step.allCases.count }

    /// Marks what an order does; returns whether anything new was done.
    mutating func note(_ command: Command) -> Bool {
        switch command {
        case .build, .train: return mark(.work)
        case .move: return mark(.march)
        default: return false
        }
    }

    @discardableResult
    mutating func mark(_ step: Step) -> Bool {
        done.insert(step).inserted
    }
}

extension LocalStore {
    var firstStepsURL: URL { directory.appendingPathComponent("first-steps.json") }

    func loadFirstSteps() -> FirstSteps? {
        guard let data = try? Data(contentsOf: firstStepsURL) else { return nil }
        return try? JSONDecoder().decode(FirstSteps.self, from: data)
    }

    func saveFirstSteps(_ steps: FirstSteps) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? JSONEncoder().encode(steps).write(to: firstStepsURL, options: .atomic)
    }
}
