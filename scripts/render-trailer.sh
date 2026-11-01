#!/usr/bin/env bash
# Renders the trailer on this Mac: every frame drawn by the game's own
# renderers on its GPU (the world's, and the launcher's lake for the
# opening and the title), and written with the game's own score to an MP4,
# H.264 and AAC, 1920 by 1080 at thirty frames a second; a still from each
# shot beside it, and the score as a WAV.
#
#   scripts/render-trailer.sh [folder]                         # the film (build/trailer)
#   NULLMERE_TRAILER_MODE=stills scripts/render-trailer.sh     # a still from each shot only
#
# The shots, what moves in them and the score are Sources/NullmereTrailer;
# the drawing and the writing, Tests/TrailerRenderTests. Built optimised,
# so a minute and a half of film takes minutes, not hours.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-build/trailer}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
export NULLMERE_TRAILER="$OUT"
swift test -c release -Xswiftc -enable-testing --filter TrailerRenderTests 2>&1 | tee "$OUT/render.log"
if grep -q "skipped" "$OUT/render.log" && ! grep -q "TRAILER stills drawn" "$OUT/render.log"; then
    echo "error: the trailer was not drawn: no Metal device?" >&2
    exit 1
fi
if [ "${NULLMERE_TRAILER_MODE:-film}" != "stills" ]; then
    [ -s "$OUT/nullmere-trailer.mp4" ] || { echo "error: no film was written" >&2; exit 1; }
    echo "The trailer: $OUT/nullmere-trailer.mp4"
fi
