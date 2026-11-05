import Foundation

/// The clips of horse and rider, keyed: the canter stride by stride, each
/// leg on its own beat; the charge for each way of bearing arms; the horse
/// shying from a blow; and both going down.
enum RiderClips {
    /// Each leg's beat in the canter, as a share of the stride: the hind
    /// pair first, a little apart, then the fore pair, the leading fore last.
    static let beats: [(upper: UInt16, lower: UInt16, beat: Float, fore: Bool)] = [
        (Steed.hindL, Steed.hindShinL, 0, false), (Steed.hindR, Steed.hindShinR, 0.12, false),
        (Steed.foreR, Steed.foreShinR, 0.45, true), (Steed.foreL, Steed.foreShinL, 0.57, true),
    ]

    /// Keys laid round a stride from a leg's beat on, sorted by moment.
    static func round(_ beat: Float, _ keys: [(Float, Vec3)]) -> [(Float, Vec3)] {
        keys.map { (t, v) in
            let at = t + beat
            return (at - at.rounded(.down), v)
        }.sorted { $0.0 < $1.0 }
    }

    /// One stride of the canter; its reach given as the stride when played.
    static let canter: Keyed = {
        var tracks: [Track] = []
        for leg in beats {
            // Swung forward, planted, driven back under, lifted and carried through.
            tracks.append(Track(leg.upper, scale: .stride, round(leg.beat, [k(0, 0), k(0.25, -0.5), k(0.5, 0), k(0.75, 0.5)])))
            if leg.fore {
                tracks.append(Track(leg.lower, round(leg.beat, [k(0, 1.3), k(0.12, 0.7), k(0.25, 0), k(0.75, 0), k(0.88, 0.7)])))
            } else {
                tracks.append(Track(leg.lower, round(leg.beat, [k(0, -0.6), k(0.12, -0.25), k(0.25, 0.1), k(0.75, 0.1), k(0.88, -0.25)])))
            }
        }
        tracks += [
            Track(Steed.body, scale: .stride, [k(0.1, 0), k(0.35, 0.14), k(0.6, 0), k(0.85, -0.14)]),
            Track(Steed.body, .shift, [k(0.1, 0, 0.01), k(0.35, 0, 0), k(0.6, 0, -0.01), k(0.85, 0, 0)]),
            Track(Steed.neck, [k(0.1, -0.08), k(0.35, -0.2), k(0.6, -0.08), k(0.85, 0.04)]),
            Track(Steed.head, [k(0.1, 0), k(0.35, 0.06), k(0.6, 0), k(0.85, -0.06)]),
            Track(Steed.tail, [k(0, -0.3), k(0.25, -0.4), k(0.5, -0.3), k(0.75, -0.2)]),
            // The rider sits the stride, leaning into it, rising and falling with it.
            Track(Steed.seat, [k(0.1, 0), k(0.35, -0.05), k(0.6, 0), k(0.85, 0.05)]),
            Track(Steed.seat, .shift, [k(0, 0, 0.004), k(0.25, 0, -0.004), k(0.5, 0, 0.004), k(0.75, 0, -0.004)]),
            Track(Steed.torso, [k(0, 0.1)]),
        ]
        return Keyed(loops: true, tracks)
    }()

    /// Three breaths a period, swelling a part by `depth` at full.
    static func breath(_ part: UInt16, _ depth: Vec3) -> Track {
        var keys: [(Float, Vec3)] = []
        for index in 0..<6 {
            let sign: Float = index % 2 == 0 ? 1 : -1
            keys.append((Float(index) / 6 + 1 / 12, depth * sign))
        }
        return Track(part, .stretch, keys)
    }

    /// Horse and rider at rest: the horse breathing, its head nodding, its
    /// tail switching, a hind hoof rested and set down again; its rider
    /// looking about.
    static let idle = Keyed(loops: true, [
        breath(Steed.body, Vec3(0.02, 0.015, 0)),
        Track(Steed.neck, [k(0, -0.05), k(0.25, 0.01), k(0.5, -0.05), k(0.75, -0.11)]),
        Track(Steed.head, [k(0, 0), k(0.2, 0.08), k(0.45, -0.06), k(0.7, 0.08), k(0.9, -0.04)]),
        Track(Steed.tail, [k(0, 0, 0, 0.1), k(0.125, 0, 0.35, 0), k(0.375, 0, -0.35, -0.1), k(0.625, 0, 0.35, 0), k(0.875, 0, -0.35, 0.1)]),
        Track(Steed.hindR, [k(0, 0), k(0.35, 0), k(0.45, -0.08), k(0.8, -0.08), k(0.9, 0)]),
        Track(Steed.hindShinR, [k(0, 0), k(0.35, 0), k(0.45, -0.35), k(0.8, -0.35), k(0.9, 0)]),
        Track(Steed.body, .shift, [k(0, 0), k(0.35, 0), k(0.45, 0.002, -0.003), k(0.8, 0.002, -0.003), k(0.9, 0)]),
        Track(Steed.riderHead, [k(0, 0), k(0.2, 0), k(0.3, 0, -0.5), k(0.48, 0, -0.5), k(0.6, 0, 0.35), k(0.75, 0, 0.35), k(0.85, 0)]),
        breath(Steed.torso, Vec3(0.01, 0.01, 0.02)),
    ])

    /// A standard stirring at rest.
    static let standardStirs = Keyed(loops: true, [
        Track(Steed.heldR, [k(0, 0), k(0.125, 0, 0, 0.05), k(0.375, 0, 0, -0.05), k(0.625, 0, 0, 0.05), k(0.875, 0, 0, -0.05)]),
    ])

    /// The horse crops the grass, head down, chewing, tail going; its
    /// rider down beside it at work with a mattock, two strokes a period.
    static let chewing: [(Float, Vec3)] = {
        var keys: [(Float, Vec3)] = []
        for index in 0..<12 {
            let nod: Float = index % 2 == 0 ? 0.08 : -0.08
            keys.append(k(Float(index) / 12, 0.45 + nod))
        }
        return keys
    }()

    static let graze = Keyed(loops: true, [
        Track(Steed.neck, [k(0, 0.95), k(0.5, 1.0)]),
        Track(Steed.head, chewing),
        Track(Steed.tail, [k(0, 0, 0.3), k(0.25, 0, -0.3), k(0.5, 0, 0.3), k(0.75, 0, -0.3)]),
    ])
    static let mattock = Keyed(loops: true, [
        Track(Steed.torso, [k(0, 0.2, 0, 0.25), k(0.4, 0.05, 0, 0.25), k(0.55, 0.2225, 0, 0.25), k(0.75, 0.2225, 0, 0.25)]),
        Track(Steed.armR, [k(0, -0.5, 0, -0.3), k(0.4, -2.5, 0, -0.3), k(0.55, -0.2, 0, -0.3), k(0.75, -0.2, 0, -0.3)]),
        Track(Steed.forearmR, [k(0, -0.3)]),
    ])

    /// How far the rider is couched down over the neck through the charge.
    static let couch: [(Float, Float)] = [(0, 0.3), (0.2, 1), (0.85, 1), (1, 0.3)]

    static func charge(_ arms: Ride.Arms) -> Keyed {
        switch arms {
        case .lance:
            // Couched low, the lance levelled, and driven home at the gallop.
            return Keyed(loops: true, [
                Track(Steed.torso, [k(0, 0.06), k(0.2, 0.2), k(0.85, 0.2)]),
                Track(Steed.armR, [k(0, -0.105), k(0.2, -0.35), k(0.45, -0.35), k(0.58, -0.85), k(0.72, -0.85), k(0.85, -0.35)]),
                Track(Steed.forearmR, [k(0, 0), k(0.45, 0), k(0.58, 0.3), k(0.72, 0.3), k(0.85, 0)]),
            ])
        case .chop:
            // The blade raised over the shoulder and cut down across the horse's neck.
            return Keyed(loops: true, [
                Track(Steed.armR, [k(0, 0, 0, -0.25), k(0.38, -2.2, 0, -0.25), k(0.52, 0.1, 0, -0.25), k(0.7, 0.1, 0, -0.25)]),
                Track(Steed.heldR, [k(0, 0), k(0.38, 0.3), k(0.52, 0.7), k(0.7, 0.7)]),
                Track(Steed.torso, [k(0, 0.15), k(0.38, 0, 0.25), k(0.52, 0.225, -0.125), k(0.7, 0.225, -0.125)]),
            ])
        case .raise:
            // A staff raised high and its light flaring over the charge.
            return Keyed(loops: true, [
                Track(Steed.armL, [k(0, -0.69, 0, -0.045), k(0.2, -2.3, 0, -0.15), k(0.85, -2.3, 0, -0.15)]),
                Track(Steed.forearmL, [k(0, 0.12), k(0.2, 0.4), k(0.85, 0.4)]),
            ])
        case .wave:
            // A standard swung high and swept from side to side.
            return Keyed(loops: true, [
                Track(Steed.armR, [k(0, -0.36), k(0.2, -1.2), k(0.85, -1.2)]),
                Track(Steed.heldR, [k(0, 0, 0, 0), k(0.125, 0, 0, 0.55), k(0.375, 0, 0, -0.55), k(0.625, 0, 0, 0.55), k(0.875, 0, 0, -0.55)]),
            ])
        }
    }

    /// The horse shies from a blow and half rears, fore hooves pawing; its
    /// rider rocked back; both down to the line again before the next.
    static func shy(shield: Bool) -> Keyed {
        func s(_ part: UInt16, _ kind: Track.Kind, _ scale: Track.Scale, _ worst: Vec3) -> Track {
            FootClips.struck(part, kind, scale: scale, worst)
        }
        var tracks = [
            s(Steed.body, .turn, .none, Vec3(-0.3, 0, 0.04)), s(Steed.body, .shift, .none, Vec3(0, 0.016, -0.026)),
            s(Steed.foreL, .turn, .none, Vec3(-0.75, 0, 0)), s(Steed.foreR, .turn, .none, Vec3(-0.6, 0, 0)),
            s(Steed.foreShinL, .turn, .none, Vec3(1.3, 0, 0)), s(Steed.foreShinR, .turn, .none, Vec3(1.2, 0, 0)),
            s(Steed.hindL, .turn, .none, Vec3(0.25, 0, 0)), s(Steed.hindR, .turn, .none, Vec3(0.25, 0, 0)),
            s(Steed.hindShinL, .turn, .none, Vec3(-0.2, 0, 0)), s(Steed.hindShinR, .turn, .none, Vec3(-0.2, 0, 0)),
            s(Steed.neck, .turn, .none, Vec3(-0.5, 0.25, 0)), s(Steed.head, .turn, .none, Vec3(-0.35, 0, 0)),
            s(Steed.tail, .turn, .none, Vec3(-0.5, 0.3, 0)),
            s(Steed.seat, .turn, .none, Vec3(0.12, 0, 0)), s(Steed.torso, .turn, .none, Vec3(-0.3, 0.2, 0)),
            s(Steed.riderHead, .turn, .none, Vec3(-0.25, -0.3, 0)),
        ]
        tracks += shield ? [s(Steed.armL, .turn, .none, Vec3(-0.5, 0, 0))]
            : [s(Steed.armL, .turn, .none, Vec3(-0.9, 0, -0.3)), s(Steed.forearmL, .turn, .none, Vec3(-0.8, 0, 0))]
        return Keyed(loops: true, tracks)
    }

    /// Down: the horse rears, then goes over on its side; its rider is
    /// thrown clear on the far side and lies with arms flung. Still at the end.
    static func fall(scale h: Float) -> Keyed {
        Keyed(loops: false, [
            Track(Steed.body, [k(0, 0), k(0.2, -0.35), k(0.45, -0.07, 0, -0.42), k(0.8, 0, 0, -1.48), k(0.85, 0, 0, -1.571), k(0.9, 0, 0, -1.571)]),
            Track(Steed.body, .shift, [k(0, 0), k(0.2, 0, 0, -0.01 * h), k(0.45, 0, -0.03 * h, -0.002 * h), k(0.85, 0, -0.118 * h, 0),
                                       k(0.9, 0, -0.118 * h, 0)]),
            Track(Steed.foreL, [k(0, 0), k(0.2, -0.6), k(0.45, -0.17), k(0.85, -0.3), k(0.9, -0.3)]),
            Track(Steed.foreR, [k(0, 0), k(0.2, -0.6), k(0.45, -0.17), k(0.85, -0.3), k(0.9, -0.3)]),
            Track(Steed.foreShinL, [k(0, 0), k(0.2, 1.2), k(0.45, 0.4), k(0.85, 0.5), k(0.9, 0.5)]),
            Track(Steed.foreShinR, [k(0, 0), k(0.2, 1.2), k(0.45, 0.4), k(0.85, 0.5), k(0.9, 0.5)]),
            Track(Steed.hindL, [k(0, 0), k(0.25, 0), k(0.85, 0.3), k(0.9, 0.3)]),
            Track(Steed.hindR, [k(0, 0), k(0.25, 0), k(0.85, 0.3), k(0.9, 0.3)]),
            Track(Steed.hindShinL, [k(0, 0), k(0.25, 0), k(0.85, -0.3), k(0.9, -0.3)]),
            Track(Steed.hindShinR, [k(0, 0), k(0.25, 0), k(0.85, -0.3), k(0.9, -0.3)]),
            Track(Steed.neck, [k(0, 0), k(0.2, -0.4), k(0.85, 0.3, 0.4), k(0.9, 0.3, 0.4)]),
            Track(Steed.head, [k(0, 0), k(0.25, 0), k(0.85, 0.4), k(0.9, 0.4)]),
            Track(Steed.seat, [k(0, 0), k(0.25, 0), k(0.85, 0, 0, -0.6), k(0.9, 0, 0, -0.6)]),
            Track(Steed.seat, .shift, [k(0, 0), k(0.25, 0), k(0.85, 0, 0.03 * h, 0), k(0.9, 0, 0.03 * h, 0)]),
            Track(Steed.armL, [k(0, 0), k(0.25, 0), k(0.85, 0, 0, 1.2), k(0.9, 0, 0, 1.2)]),
            Track(Steed.armR, [k(0, 0), k(0.25, 0), k(0.85, 0, 0, -1.2), k(0.9, 0, 0, -1.2)]),
            Track(Steed.riderHead, [k(0, 0), k(0.25, 0), k(0.85, -0.3), k(0.9, -0.3)]),
        ])
    }
}
