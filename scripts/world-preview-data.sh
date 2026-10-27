#!/usr/bin/env bash
# Writes the tile textures Tools/world-preview renders the map from: a
# keeper's view as a game opens, and the whole world known. The rules and
# the map's own packing code are compiled together into one small program,
# so this runs anywhere Swift does, Linux included.
#
#   scripts/world-preview-data.sh [seed]
#   python3 -m http.server, then open
#   http://localhost:8000/Tools/world-preview/?data=../../build/world-preview/opening.json
set -euo pipefail
cd "$(dirname "$0")/.."
SEED="${1:-the still water}"
OUT=build/world-preview
mkdir -p "$OUT"
libm=""
[ "$(uname)" = Linux ] && libm="-lm"
# One module: the files' own "import NullmereCore" is then ignored, with a warning.
swiftc -O -module-name NullmereCore -suppress-warnings $libm \
    Sources/NullmereCore/*.swift Sources/NullmereKit/World/TileTexture.swift Sources/NullmereKit/World/MoonMirror.swift \
    Tools/world-preview/main.swift -o "$OUT/generate" 2>&1 | grep -v "^$" || true
[ -x "$OUT/generate" ] || { echo "error: the generator didn't build" >&2; exit 1; }
"$OUT/generate" "$SEED" 12 36 opening "$OUT/opening.json"
"$OUT/generate" "$SEED" 12 36 whole "$OUT/whole.json"
