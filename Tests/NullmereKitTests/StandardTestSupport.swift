@testable import NullmereCore

extension GameState {
    /// Every rising standard stood whole at once, for tests of their land.
    mutating func standStandardsWhole() {
        for index in (standards ?? []).indices { standards![index].built = Standard.raising }
    }
}
