import Foundation
import XCTest
@testable import NullmereCore

/// A keeper's identity carried to another Mac: sixteen words written down,
/// their digest's digest kept by the realm, and the same words taking the
/// keeper up again elsewhere.
final class KeeperWordsTests: XCTestCase {
    /// SHA-256 as its standard gives it, across the edges of its blocks and
    /// beyond plain letters.
    func testTheDigestIsTheStandardOne() {
        XCTAssertEqual(SHA256.hex(""), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        XCTAssertEqual(SHA256.hex("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        XCTAssertEqual(SHA256.hex("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"),
                       "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1")
        XCTAssertEqual(SHA256.hex(String(repeating: "a", count: 1000)), "41edece42d63e8d9bf515a9ba6932e1c20cbc9f5a5d134645adb5db1b9737ea3")
        XCTAssertEqual(SHA256.hex(String(repeating: "x", count: 55)), "d5e285683cd4efc02d021a5c62014694958901005d6f71e89e0989fac77e4072")
        XCTAssertEqual(SHA256.hex(String(repeating: "y", count: 56)), "4877e564e5e36e367c7c8d59670774becd3350610b6df4c399c9fa9b66da5813")
        XCTAssertEqual(SHA256.hex(String(repeating: "z", count: 64)), "72996563049cc84daa2c3f31fd5c3d10770e69d6ebbb8da5b6d76db303dbae43")
        XCTAssertEqual(SHA256.hex("\u{e9} moon"), "2e25c4d6a206563df1af91de6763c8d3ed9244dae6f4b56a2c017d18e0494efb")
        XCTAssertEqual(SHA256.digest([]).count, 32)
    }

    /// 256 plain words, each told from the rest by its first four letters:
    /// sixteen of them hold 128 bits.
    func testTheWordsAreTheirOwnAndHoldEnough() {
        XCTAssertEqual(KeeperWords.count, 16)
        XCTAssertEqual(KeeperWords.list.count, 256)
        XCTAssertEqual(Set(KeeperWords.list).count, 256)
        XCTAssertEqual(Set(KeeperWords.list.map { $0.prefix(4) }).count, 256, "Four letters tell each from the rest")
        XCTAssertTrue(KeeperWords.list.allSatisfy { word in (3...7).contains(word.count) && word.allSatisfy { $0.isLetter && $0.isLowercase } })
    }

    /// Words made, written down however a keeper writes them, and read back.
    func testWordsAreMadeAndReadBackHoweverWritten() throws {
        var generator = SeededRandom(seed: 7)
        let words = KeeperWords.make(using: &generator)
        var again = SeededRandom(seed: 7)
        XCTAssertEqual(KeeperWords.make(using: &again), words, "The same randomness, the same words")
        XCTAssertEqual(words.count, 16)
        XCTAssertTrue(words.allSatisfy(KeeperWords.list.contains))
        XCTAssertNotEqual(KeeperWords.make(), KeeperWords.make(), "The system's own randomness")

        let written = words.enumerated().map { "\($0.offset + 1). \($0.element.uppercased())" }.joined(separator: ",\n")
        XCTAssertEqual(KeeperWords.read(written), words, "Numbered, in capitals, a line each")
        XCTAssertNil(KeeperWords.read(words.dropLast().joined(separator: " ")), "Fifteen")
        XCTAssertNil(KeeperWords.read((words + ["acorn"]).joined(separator: " ")), "Seventeen")
        XCTAssertNil(KeeperWords.read((words.dropLast() + ["zebra"]).joined(separator: " ")), "A stranger among them")

        XCTAssertNil(KeeperWords.problem(""), "Nothing written yet")
        XCTAssertNil(KeeperWords.problem(written))
        XCTAssertEqual(KeeperWords.problem("acorn alder"), "2 of 16 words.")
        XCTAssertEqual(KeeperWords.problem("acorn zebra alder"), "\"zebra\" is not one of the words.")
        XCTAssertEqual(KeeperWords.problem((words + ["acorn"]).joined(separator: " ")), "17 words: there are 16.")
    }

    /// The Mac sends the words' digest, never the words; the realm keeps
    /// only that digest's own, which can't be sent back to it.
    func testTheRealmKeepsOnlyADigestOfADigest() {
        let words = KeeperWords.make()
        let proof = KeeperWords.proof(of: words)
        XCTAssertTrue(KeeperWords.isProof(proof))
        XCTAssertEqual(KeeperWords.proof(of: words), proof, "The same words, the same proof")
        XCTAssertFalse(proof.contains(words[0]))
        XCTAssertNotEqual(KeeperWords.proof(of: words.reversed()), proof, "In their order")
        let seal = KeeperWords.seal(of: proof)
        XCTAssertNotEqual(seal, proof)
        XCTAssertFalse(KeeperWords.isProof("not a proof"))
        XCTAssertFalse(KeeperWords.isProof(proof.uppercased()), "Lower case only")
        XCTAssertFalse(KeeperWords.isProof(String(proof.dropLast())))
    }

    /// A keeper sealed by their words is taken up by them on another Mac:
    /// the Mac they left no longer speaks for them; words not theirs, a Mac
    /// that already keeps a House, or what the realm itself keeps, take up
    /// no one; sealing again lets the old words go.
    func testAKeeperIsCarriedToAnotherMacByTheirWords() throws {
        var realm = RealmState(name: "The Nullmere", seed: "carried", seats: 4, radius: 18, watchLength: 60, now: 0)
        let ama = try realm.arrive("first-mac", name: "Ama", now: 1)
        _ = try realm.arrive("bel-mac", name: "Bel", now: 1)
        let proof = KeeperWords.proof(of: KeeperWords.make())

        XCTAssertThrowsError(try realm.seal("stranger", proof: proof)) { XCTAssertEqual($0 as? RealmError, .unknownKeeper) }
        XCTAssertThrowsError(try realm.seal("first-mac", proof: "not a proof")) {
            XCTAssertEqual($0 as? RealmError, .refused("The words' proof couldn't be read."))
        }
        try realm.seal("first-mac", proof: proof)
        let seal = try XCTUnwrap(realm.keeper("first-mac")?.seal)
        XCTAssertEqual(seal, KeeperWords.seal(of: proof))

        XCTAssertThrowsError(try realm.reclaim("second-mac", proof: KeeperWords.proof(of: KeeperWords.make()), now: 2)) {
            XCTAssertEqual($0 as? RealmError, .unknownWords)
        }
        XCTAssertThrowsError(try realm.reclaim("second-mac", proof: seal, now: 2), "What the realm keeps can't be sent back to it") {
            XCTAssertEqual($0 as? RealmError, .unknownWords)
        }
        XCTAssertThrowsError(try realm.reclaim("second-mac", proof: "garbled", now: 2)) { XCTAssertEqual($0 as? RealmError, .unknownWords) }
        XCTAssertThrowsError(try realm.reclaim("bel-mac", proof: proof, now: 2)) { XCTAssertEqual($0 as? RealmError, .keepsAnother) }

        let carried = try realm.reclaim("second-mac", proof: proof, now: 3)
        XCTAssertEqual(carried.name, "Ama")
        XCTAssertEqual(carried.house, ama.house, "Their House with them")
        XCTAssertTrue(carried.isOnline)
        XCTAssertEqual(carried.arrival, ama.arrival)
        XCTAssertNil(realm.keeper("first-mac"), "The Mac they left no longer speaks for them")
        XCTAssertEqual(realm.keepers.count, 2)
        XCTAssertThrowsError(try realm.arrive("first-mac", name: nil, now: 4)) { XCTAssertEqual($0 as? RealmError, .nameInvalid) }

        // Sealing again lets the old words go.
        let fresh = KeeperWords.proof(of: KeeperWords.make())
        try realm.seal("second-mac", proof: fresh)
        XCTAssertThrowsError(try realm.reclaim("third-mac", proof: proof, now: 5)) { XCTAssertEqual($0 as? RealmError, .unknownWords) }
        XCTAssertEqual(try realm.reclaim("third-mac", proof: fresh, now: 6).name, "Ama")
        XCTAssertEqual(RealmError.unknownWords.description, "No keeper of this realm is sealed with those words.")
        XCTAssertTrue(RealmError.keepsAnother.description.hasPrefix("This Mac already keeps a House here"))
    }
}
