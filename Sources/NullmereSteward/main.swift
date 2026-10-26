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
// existing one is taken up as it stands.

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

let steward: RealmSteward
do {
    steward = try await RealmSteward(
        transport: transport,
        token: token,
        name: environment["NULLMERE_REALM_NAME"] ?? "The Nullmere",
        seed: environment["NULLMERE_REALM_SEED"] ?? "the still water",
        seats: environment["NULLMERE_REALM_SEATS"].flatMap(Int.init) ?? RealmState.defaultSeats,
        watchLength: environment["NULLMERE_WATCH_SECONDS"].flatMap(Double.init) ?? RealmState.defaultWatchLength,
        now: Date().timeIntervalSince1970
    )
} catch {
    fail("The steward couldn't take up the realm: \(error)")
}
let realm = await steward.state
print("Stewarding \(realm.name), age \(realm.age), watch \(realm.world.watch), at \(text).")
await steward.setReporter { line in
    print("\(Date().formatted(.iso8601)) \(line)")
}
await steward.run()
