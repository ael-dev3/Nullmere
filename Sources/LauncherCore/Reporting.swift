import Foundation

/// Lines the app says on its own output as well as to the unified log,
/// for the smoke tests: the unified log can take seconds to hold a line,
/// the app's output holds it at once. Debug builds always say them; a
/// release build only when launched with NULLMERE_SAY_READY=1.
public enum Reporting {
    public static var isOn: Bool {
        #if DEBUG
        return true
        #else
        return ProcessInfo.processInfo.environment["NULLMERE_SAY_READY"] == "1"
        #endif
    }

    public static func say(_ line: String) {
        guard isOn else { return }
        FileHandle.standardError.write(Data((line + "\n").utf8))
    }
}
