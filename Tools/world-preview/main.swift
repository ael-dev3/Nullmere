// Writes a world's tile texture for Tools/world-preview: the same bytes the
// game's map shader reads, for a keeper at an age's opening, or with the
// whole world known. Built and run by scripts/world-preview-data.sh.
//
//   generate <seed> <houses> <radius> <opening|whole> <out.json>
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 6, let houses = Int(arguments[2]), let radius = Int(arguments[3]) else {
    print("usage: generate <seed> <houses> <radius> <opening|whole> <out.json>")
    exit(2)
}
var state = GameState(settings: GameSettings(seedText: arguments[1], houseCount: houses, radius: radius, keepers: 1))
if arguments[4] == "whole" {
    state.houses[state.player].explored = Array(repeating: true, count: state.map.count)
}
let moon = MoonMirror.place(in: state.map)
let seat = HexLayout(size: 1).center(of: state.seat(of: state.player)!.position)
let tiles: [String: Any] = [
    "side": TileTexture.side(for: state.map),
    "radius": state.map.radius,
    "bytes": Data(TileTexture.bytes(for: state, viewer: state.player)).base64EncodedString(),
    "moon": [moon.x, moon.y, moon.z, moon.w].map(Double.init),
    "seat": [seat.x, seat.y],
]
try JSONSerialization.data(withJSONObject: tiles).write(to: URL(fileURLWithPath: arguments[5]))
print("Wrote \(arguments[5])")
