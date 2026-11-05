import Foundation
import NullmereCore
@testable import NullmereModels
import XCTest

/// How the models move: every clip at every moment gives a sound pose;
/// the looping clips come round to where they began; the dead fall, lie
/// low and stay down.
final class ClipTests: XCTestCase {
    /// The most any entry of any part's transform differs between two poses.
    static func difference(_ a: [Mat4], _ b: [Mat4]) -> Float {
        var most: Float = 0
        for (m, n) in zip(a, b) {
            for column in [m.c0 - n.c0, m.c1 - n.c1, m.c2 - n.c2, m.c3 - n.c3] {
                most = max(most, abs(column.x), abs(column.y), abs(column.z), abs(column.w))
            }
        }
        return most
    }

    /// The highest point of a model as it stands at a moment of a clip,
    /// leaving out parts it does not fall with.
    static func top(_ model: Model, _ clip: Clip, _ time: Float, leaving out: Set<UInt16> = []) -> Float {
        let pose = model.pose(clip, at: time)
        return model.mesh.vertices.filter { !out.contains($0.part) }.map { $0.posed(pose).y }.max() ?? 0
    }

    func testClipsKeepTime() {
        XCTAssertEqual(Clip.allCases.filter(\.loops), [.idle, .march, .attack, .hit, .gather])
        XCTAssertEqual(Clip.hit.period, Clip.attack.period, "struck on the beat the foe strikes")
        XCTAssertFalse(Clip.death.loops)
        for clip in Clip.allCases {
            XCTAssertGreaterThan(clip.period, 0.5)
            XCTAssertEqual(clip.progress(at: 0), 0)
            XCTAssertEqual(clip.progress(at: clip.period * 0.25), 0.25, accuracy: 1e-5)
            XCTAssertEqual(clip.progress(at: .nan), 0, "a moment that is no moment is the start")
        }
        XCTAssertEqual(Clip.march.progress(at: Clip.march.period * 2.5), 0.5, accuracy: 1e-5, "a loop comes round")
        XCTAssertEqual(Clip.idle.progress(at: -1), 0.75, accuracy: 1e-5)
        XCTAssertEqual(Clip.death.progress(at: Clip.death.period * 3), 1, "the dead stay down")
        XCTAssertEqual(Clip.death.progress(at: -2), 0)
    }

    func testKeyframesEaseAndHold() {
        XCTAssertEqual(Motion.key(0.5, []), 0)
        let frames: [(Float, Float)] = [(0.2, 1), (0.6, 3)]
        XCTAssertEqual(Motion.key(0, frames), 1, "held before the first")
        XCTAssertEqual(Motion.key(1, frames), 3, "held after the last")
        XCTAssertEqual(Motion.key(0.4, frames), 2, accuracy: 1e-5, "eased through the middle")
        XCTAssertEqual(Motion.smooth(-1), 0)
        XCTAssertEqual(Motion.smooth(2), 1)
        XCTAssertEqual(Motion.wave(0.25), 1, accuracy: 1e-5)
        XCTAssertEqual(Motion.cosine(0.5), -1, accuracy: 1e-5)
        var pose = Pose(count: 2)
        pose.hide(1)
        XCTAssertEqual(pose.joints[1].scale, Vec3(repeating: Motion.hidden))
        pose.stretch(1, 2)
        XCTAssertEqual(pose.joints[1].scale.x, Motion.hidden * 2, accuracy: 1e-7)
    }

    func testEveryPoseIsSound() {
        for key in Library.catalogue {
            let model = Library.model(key)
            for clip in Clip.allCases {
                for step in 0...30 {
                    let time = clip.period * 2.2 * Float(step) / 30 - 0.3
                    let pose = model.pose(clip, at: time)
                    XCTAssertEqual(pose.count, model.rig.count, "\(key) \(clip)")
                    let finite = pose.allSatisfy { m in [m.c0, m.c1, m.c2, m.c3].allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite && $0.w.isFinite } }
                    XCTAssertTrue(finite, "\(key) \(clip) at \(time) is finite")
                    XCTAssertTrue(pose.allSatisfy { $0.inverse != nil }, "\(key) \(clip) at \(time) keeps every part invertible")
                }
            }
        }
    }

    func testLoopingClipsComeRound() {
        for key in Library.catalogue {
            let model = Library.model(key)
            guard model.motion != nil || model.skeleton != nil else { continue }
            for clip in Clip.allCases where clip.loops {
                for time in [Float(0), 0.31, 0.77, 1.3] {
                    let a = model.pose(clip, at: time), b = model.pose(clip, at: time + clip.period)
                    XCTAssertLessThan(ClipTests.difference(a, b), 1e-3, "\(key) \(clip) loops")
                }
                // No jump where the loop joins: no more change across it than it makes anywhere else.
                let step: Float = 0.002
                let usual = (1...24).map { index -> Float in
                    let time = clip.period * Float(index) / 25
                    return ClipTests.difference(model.pose(clip, at: time - step), model.pose(clip, at: time + step))
                }.max() ?? 0
                let across = ClipTests.difference(model.pose(clip, at: clip.period - step), model.pose(clip, at: clip.period + step))
                XCTAssertLessThanOrEqual(across, usual * 1.5 + 2e-3, "\(key) \(clip) joins smoothly")
            }
        }
    }

    /// Every company, struck, reels: hardest just after the blow, at guard
    /// again before the next, so a rank can take blow after blow.
    func testEveryCompanyReelsWhenStruckAndRecovers() {
        for key in Library.catalogue where CatalogueTests.isCompany(key) {
            let model = Library.model(key)
            guard model.motion != nil || model.skeleton != nil else { continue }
            let guardPose = model.pose(.hit, at: 0), worst = model.pose(.hit, at: 0.14 * Clip.hit.period)
            XCTAssertGreaterThan(ClipTests.difference(guardPose, worst), 0.02, "\(key) reels when struck")
            XCTAssertLessThan(ClipTests.difference(guardPose, model.pose(.hit, at: 0.9 * Clip.hit.period)), 1e-3,
                              "\(key) back at guard before the next blow")
            XCTAssertGreaterThan(ClipTests.difference(worst, model.pose(.attack, at: 0.14 * Clip.attack.period)), 0.02,
                                 "\(key) taking a blow is not giving one")
        }
    }

    func testTheDeadFallAndLieStill() {
        for key in Library.catalogue where CatalogueTests.isCompany(key) {
            let model = Library.model(key)
            let end = Clip.death.period
            XCTAssertEqual(model.pose(.death, at: end), model.pose(.death, at: end + 5), "\(key) lies still")
            XCTAssertLessThan(ClipTests.difference(model.pose(.death, at: end - 0.2), model.pose(.death, at: end)), 0.01,
                              "\(key) has come to rest before the end")
            // A founder's cart stands where it was let go, and a Mangonel's engine where it was struck.
            let engine: Bool
            if case .figure(.mangonel, _) = key { engine = true } else { engine = false }
            let cart: Set<UInt16> = key == .figure(.founder, tier: 1) ? [Cart.body, Cart.wheelL, Cart.wheelR]
                : engine ? [Engine.body, Engine.wheelL, Engine.wheelR, Engine.arm, Engine.stone] : []
            let standing = ClipTests.top(model, .idle, 0, leaving: cart)
            let lying = ClipTests.top(model, .death, end, leaving: cart)
            XCTAssertLessThan(lying, standing * 0.45, "\(key) ends lying low")
            XCTAssertLessThan(ClipTests.difference(model.pose(.death, at: 0), model.pose(.idle, at: 0)), 1.5,
                              "\(key) falls from where it stood")
        }
    }

    /// Each kind strikes in its own way, and moves on the march.
    func testClipsMoveTheRightParts() {
        func moved(_ key: ModelKey, _ clip: Clip, _ part: UInt16) -> Float {
            let model = Library.model(key)
            // Moments that fall out of step with any beat a clip keeps.
            let poses = (0..<17).map { model.pose(clip, at: clip.period * Float($0) / 17) }
            return poses.map { ClipTests.difference([$0[Int(part)]], [poses[0][Int(part)]]) }.max() ?? 0
        }
        // A spear is levelled and thrust.
        let spear = Library.model(.figure(.spear, tier: 3))
        let tip = { (time: Float) -> Vec3 in
            spear.pose(.attack, at: time)[Int(Limb.heldR)].transformDirection(Vec3(0, 1, 0)).normalized
        }
        XCTAssertGreaterThan(tip(Clip.attack.period * 0.5).z, 0.9, "the spear points at the foe")
        XCTAssertGreaterThan(spear.pose(.idle, at: 0)[Int(Limb.heldR)].transformDirection(Vec3(0, 1, 0)).normalized.y, 0.98,
                             "and stands upright at rest")
        // A bow is drawn with its arrow on the string, then loosed.
        let size = { (m: Mat4) in Vec3(m.c0.x, m.c0.y, m.c0.z).length }
        let bow = Library.model(.figure(.bow, tier: 2))
        XCTAssertGreaterThan(size(bow.pose(.attack, at: Clip.attack.period * 0.55)[Int(Limb.extra)]), 0.9, "the arrow is drawn")
        XCTAssertLessThan(size(bow.pose(.attack, at: Clip.attack.period * 0.9)[Int(Limb.extra)]), 0.01, "and loosed")
        XCTAssertLessThan(size(bow.pose(.idle, at: 1)[Int(Limb.extra)]), 0.01, "no arrow at rest")
        XCTAssertLessThan(size(bow.pose(.attack, at: Clip.attack.period * 0.4)[Int(Bowman.string)]), 0.01, "the string drawn back")
        // A lantern is raised high.
        let lantern = Library.model(.figure(.lantern, tier: 1))
        let lit = lantern.mesh.vertices.first { $0.material == .glow }!
        let high = lantern.pose(.attack, at: Clip.attack.period * 0.5)[Int(lit.part)].transformPoint(lit.position).y
        let low = lantern.pose(.idle, at: 0)[Int(lit.part)].transformPoint(lit.position).y
        XCTAssertGreaterThan(high, low + 0.1, "the lantern is lifted")
        // The legs stride on the march; the rider's horse gallops; a cart's wheels turn.
        XCTAssertGreaterThan(moved(.figure(.spear, tier: 1), .march, Limb.thighL), 0.05)
        XCTAssertGreaterThan(moved(.figure(.rider, tier: 2), .march, Steed.foreL), 0.05)
        XCTAssertGreaterThan(moved(.figure(.founder, tier: 1), .march, Cart.wheelL), 0.5)
        // A Mangonel's arm flies up to its stop bar and its stone is gone; its wheels roll.
        XCTAssertGreaterThan(moved(.figure(.mangonel, tier: 3), .attack, Engine.arm), 1)
        XCTAssertGreaterThan(moved(.figure(.mangonel, tier: 1), .march, Engine.wheelR), 0.5)
        XCTAssertLessThan(moved(.figure(.mangonel, tier: 2), .idle, Engine.arm), 0.1, "the arm at rest only creaks")
        let engine = Library.model(.figure(.mangonel, tier: 5))
        XCTAssertGreaterThan(size(engine.pose(.attack, at: 0)[Int(Engine.stone)]), 0.9, "a stone in the cup, cocked")
        XCTAssertLessThan(size(engine.pose(.attack, at: Clip.attack.period * 0.5)[Int(Engine.stone)]), 0.01, "and thrown")
        let flung = engine.pose(.attack, at: Clip.attack.period * 0.35)[Int(Engine.arm)].transformDirection(Vec3(0, 0, -1))
        XCTAssertGreaterThan(flung.y, 0.5, "the arm thrown up from where it lay back")
        XCTAssertGreaterThan(moved(.prop(.cart), .march, 1), 0.5)
        XCTAssertEqual(moved(.prop(.cart), .idle, 1), 0, "a cart at rest is still")
        // A tool comes out to gather, and is put away otherwise.
        let gatherer = Library.model(.figure(.bow, tier: 4))
        XCTAssertEqual(size(gatherer.pose(.gather, at: 0.3)[Int(Limb.tool)]), 1, accuracy: 1e-3)
        XCTAssertLessThan(size(gatherer.pose(.march, at: 0.3)[Int(Limb.tool)]), 0.01)
        XCTAssertLessThan(size(gatherer.pose(.gather, at: 0.3)[Int(Limb.heldL)]), 0.01, "the bow put by")
        // Works turn and flicker; a bird beats its wings.
        let gin = Library.model(.work(.sawpit, level: 4)).rig.index(of: "gin") ?? 0
        XCTAssertGreaterThan(moved(.work(.sawpit, level: 4), .idle, UInt16(gin)), 0.5, "the horse walks the gin")
        XCTAssertGreaterThan(moved(.work(.quarry, level: 5), .idle, 1), 0.3, "the crane slews")
        let fire = Library.model(.work(.beacon, level: 2)).rig.index(of: "beacon fire") ?? 0
        XCTAssertGreaterThan(moved(.work(.beacon, level: 2), .idle, UInt16(fire)), 0.05, "the beacon's fire leaps")
        XCTAssertGreaterThan(moved(.prop(.bird), .idle, 1), 0.5)
        XCTAssertGreaterThan(moved(.prop(.puff), .idle, 1), 0.1, "smoke rises")
        XCTAssertGreaterThan(moved(.commander(variant: 4), .attack, Steed.heldR), 0.3, "the standard is waved")
        XCTAssertGreaterThan(moved(.commander(variant: 0), .attack, Steed.heldR), 0.3, "the blade is swung")
    }

    /// The renderer moves a marching figure at its pace so its feet hold the ground.
    func testMarchingPacesAreGiven() {
        for key in Library.catalogue {
            if case .folk = key {
                XCTAssertGreaterThan(key.marchSpeed ?? 0, 0.1, "\(key) walks")
                XCTAssertLessThan(key.marchSpeed ?? 1, ModelKey.figure(.spear, tier: 1).marchSpeed ?? 0, "\(key) walks, unhurried")
            } else if CatalogueTests.isCompany(key) || key == .prop(.cart) {
                XCTAssertGreaterThan(key.marchSpeed ?? 0, 0.1, "\(key) marches")
            } else {
                XCTAssertNil(key.marchSpeed, "\(key) does not march")
            }
        }
        XCTAssertGreaterThan(ModelKey.figure(.rider, tier: 1).marchSpeed ?? 0, ModelKey.figure(.spear, tier: 1).marchSpeed ?? 0)
        XCTAssertEqual(ModelKey.prop(.cart).marchSpeed, ModelKey.figure(.bow, tier: 2).marchSpeed, "a cart keeps pace with those on foot")
        XCTAssertGreaterThan(ModelKey.wild(tier: 3).marchSpeed ?? 0, 0)
        let foot = Gait().marchSpeed, horse = Ride().marchSpeed
        XCTAssertGreaterThan(foot, 0.1)
        XCTAssertLessThan(foot, 0.5)
        XCTAssertGreaterThan(horse, foot, "riders outpace those on foot")
    }

    /// A cart's wheels roll over the ground its puller walks, not skidding:
    /// between two moments of the walk the rim turns as far as the ground
    /// they cover, a turn of them each march period.
    func testCartWheelsRollOverTheGroundWalked() throws {
        for key: ModelKey in [.figure(.founder, tier: 1), .figure(.mangonel, tier: 1), .folk(of: .sawpit), .folk(of: .quarry)] {
            let model = Library.model(key), mesh = model.mesh
            let speed = try XCTUnwrap(key.marchSpeed)
            let far = Set(mesh.indices[..<mesh.coarseIndexCount].map(Int.init))
            let rim = far.map { mesh.vertices[$0] }.filter { $0.part == Cart.wheelL }.map(\.position)
            XCTAssertFalse(rim.isEmpty, "\(key) has wheels")
            guard let first = rim.first else { continue }
            let low = rim.reduce(first) { Vec3(min($0.x, $1.x), min($0.y, $1.y), min($0.z, $1.z)) }
            let high = rim.reduce(first) { Vec3(max($0.x, $1.x), max($0.y, $1.y), max($0.z, $1.z)) }
            let axle = (low + high) * 0.5
            let radius = rim.map { Vec3(0, $0.y - axle.y, $0.z - axle.z).length }.max() ?? 0
            let (early, later) = (Clip.march.period * 0.1, Clip.march.period * 0.35)
            func spoke(_ time: Float) -> Vec3 {
                let wheel = model.pose(.march, at: time)[Int(Cart.wheelL)]
                let out = wheel.transformPoint(axle + Vec3(0, radius, 0)) - wheel.transformPoint(axle)
                return Vec3(0, out.y, out.z).normalized
            }
            let a = spoke(early), b = spoke(later)
            let turned = acos(min(max(a.y * b.y + a.z * b.z, -1), 1))
            let walked = speed * (later - early)
            XCTAssertEqual(turned * radius, walked, accuracy: walked * 0.04, "\(key)'s wheels roll, not skid")
        }
    }
}
