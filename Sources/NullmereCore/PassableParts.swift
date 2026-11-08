extension WorldMap {
    /// The stretches of ground a march may cross, each hex's by its index:
    /// -1 where no company may step, and two hexes share a number only where
    /// passable ground joins them, whatever stands on it. A march from one
    /// number to another has no way, so no search for one need be made.
    public func passableParts() -> [Int32] {
        var part = [Int32](repeating: -1, count: count)
        var next: Int32 = 0
        var stack: [Int] = []
        for start in 0..<count where steps[start] != 0 && part[start] < 0 {
            part[start] = next
            stack.append(start)
            while let at = stack.popLast() {
                for side in 0..<6 {
                    let index = Int(neighbours[at * 6 + side])
                    guard index >= 0, steps[index] != 0, part[index] < 0 else { continue }
                    part[index] = next
                    stack.append(index)
                }
            }
            next += 1
        }
        return part
    }
}
