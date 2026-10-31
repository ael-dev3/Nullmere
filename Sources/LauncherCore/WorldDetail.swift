/// How much of the world's detail is drawn: the land's furniture (heather,
/// ferns, pebbles and birches between the holds) in full, in part, or
/// none of it. Auto reads the Mac: the memory its graphics may work in.
public enum WorldDetail: String, CaseIterable, Sendable {
    case auto
    case high
    case medium
    case low

    public var title: String {
        switch self {
        case .auto: return "Auto"
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }

    /// What Auto comes to on a Mac whose graphics may work in
    /// `gpuMemoryGB` of memory (none when it can't be read); any other
    /// choice is itself.
    public func resolved(gpuMemoryGB: Double) -> WorldDetail {
        guard self == .auto else { return self }
        if gpuMemoryGB >= 10 { return .high }
        if gpuMemoryGB >= 5 { return .medium }
        return .low
    }

    /// One step down, after the Mac's graphics faltered at this detail;
    /// none below the lowest, when only the painting is left.
    public var steppedDown: WorldDetail? {
        switch self {
        case .auto, .high: return .medium
        case .medium: return .low
        case .low: return nil
        }
    }

    /// The share of the land's furniture drawn.
    public var furnitureShare: Float {
        switch self {
        case .auto, .high: return 1
        case .medium: return 0.5
        case .low: return 0
        }
    }
}
