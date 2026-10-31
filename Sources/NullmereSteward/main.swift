import Foundation
import NullmereCore
import NullmereRealm

// The steward: runs the Nullmere realm's rules beside its SpacetimeDB
// database. Run it as the identity that published the realm module.
//
//   NullmereSteward http://127.0.0.1:3000/nullmere
//
// The token comes from NULLMERE_STEWARD_TOKEN, or from the file named by
// NULLMERE_STEWARD_TOKEN_FILE. NULLMERE_REALM_NAME, NULLMERE_REALM_SEED,
// NULLMERE_REALM_SEATS and NULLMERE_WATCH_SECONDS shape a new realm; an
// existing one is taken up as it stands. NULLMERE_FRONTIER=1 makes a new
// realm the Frontier, where the realms meet; NULLMERE_BORDERS names, by
// their addresses and between commas, the realms it borders: the
// Frontier, for a home realm; the home realms, for the Frontier.

// Each line as it's written, even into a log file.
setvbuf(stdout, nil, _IOLBF, 0)

let environment = ProcessInfo.processInfo.environment
let arguments = CommandLine.arguments.dropFirst()

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

guard let text = arguments.first, let address = URL(string: text), let transport = SpacetimeHTTP(address: address) else {
    fail("usage: NullmereSteward <server>/<database>, such as http://127.0.0.1:3000/nullmere")
}
let token: String
if let value = environment["NULLMERE_STEWARD_TOKEN"], !value.isEmpty {
    token = value
} else if let path = environment["NULLMERE_STEWARD_TOKEN_FILE"],
          let value = try? String(contentsOfFile: path, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines) {
    token = value
} else {
    fail("Set NULLMERE_STEWARD_TOKEN or NULLMERE_STEWARD_TOKEN_FILE to the token of the identity that published the module.")
}
// A realm of a size no lake can seat is refused here, aloud, never made
// another size without a word.
let seats: Int = {
    guard let text = environment["NULLMERE_REALM_SEATS"], !text.isEmpty else { return RealmState.defaultSeats }
    guard let asked = Int(text), RealmState.seatRange.contains(asked) else {
        fail("NULLMERE_REALM_SEATS is \(text), but a realm has \(RealmState.seatRange.lowerBound) to \(RealmState.seatRange.upperBound) seats.")
    }
    return asked
}()

// A steward restarted while its last self still holds the realm waits for
// that hold to lapse (a minute at most); another steward running elsewhere
// keeps it, and this one gives up.
func takeUp() async -> RealmSteward {
    let waitUntil = Date().addingTimeInterval(150)
    var said = false
    while true {
        do {
            return try await RealmSteward(
                transport: transport,
                token: token,
                name: environment["NULLMERE_REALM_NAME"] ?? "The Nullmere",
                seed: environment["NULLMERE_REALM_SEED"] ?? "the still water",
                seats: seats,
                watchLength: environment["NULLMERE_WATCH_SECONDS"].flatMap(Double.init) ?? RealmState.defaultWatchLength,
                frontier: environment["NULLMERE_FRONTIER"] == "1",
                now: Date().timeIntervalSince1970
            )
        } catch where RealmSteward.isHeldByAnother(error) && Date() < waitUntil {
            if !said {
                print("Another steward holds the realm; waiting for its hold to lapse.")
                said = true
            }
            try? await Task.sleep(nanoseconds: 5_000_000_000)
        } catch {
            fail("The steward couldn't take up the realm: \(error)")
        }
    }
}

let steward = await takeUp()
for border in (environment["NULLMERE_BORDERS"] ?? "").split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces) })
    where !border.isEmpty {
    guard let url = URL(string: border), let bordering = SpacetimeHTTP(address: url) else { fail("NULLMERE_BORDERS: \(border) is no realm's address.") }
    await steward.border(bordering, at: border)
}
let realm = await steward.state
print("Stewarding \(realm.name), age \(realm.age), watch \(realm.world.watch), at \(text).")
await steward.setReporter { line in
    print("\(Date().formatted(.iso8601)) \(line)")
}
await steward.run()
if await steward.isDisplaced {
    fail("Another steward holds the realm now; this one has stopped.")
}
