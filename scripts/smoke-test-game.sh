#!/usr/bin/env bash
# Opens the game from a debug build, past the on-device model check, and
# checks that it really starts: it must still be running after a few
# seconds, and its world must be rendering with Metal. Saves screenshots of
# the title screen, of a new game with the seat selected and the Houses
# panel open, and of the same game forty watches on, played by a steward.
#
#   swift build && scripts/smoke-test-game.sh
#
# Only debug builds honour NULLMERE_MODEL_STATE and NULLMERE_NEW_GAME, so a
# runner without Apple Intelligence can see the gate in any state, and past it.
set -euo pipefail

cd "$(dirname "$0")/.."

BIN="${BIN:-$(swift build --show-bin-path)/Nullmere}"
EXECUTABLE="Nullmere"
WAIT="${WAIT:-15}"
SUBSYSTEM="online.nullmere.game"
SEED="${SEED:-black moon}"
mkdir -p build

if pgrep -x "$EXECUTABLE" >/dev/null; then
    echo "error: $EXECUTABLE is already running; quit it first" >&2
    exit 1
fi

# run <screenshot> [seed] [watches to autoplay] [what to show]
run() {
    local shot="$1"
    local seed="${2:-}"
    local autoplay="${3:-0}"
    local show="${4:-}"
    local started
    started="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "Opening the game${seed:+ on \"$seed\"}…"
    NULLMERE_MODEL_STATE="${MODEL_STATE:-ready}" NULLMERE_NEW_GAME="$seed" NULLMERE_AUTOPLAY="$autoplay" NULLMERE_SHOW="$show" "$BIN" >build/game-stdout.log 2>&1 &
    local pid=$!
    sleep "$WAIT"
    if ! kill -0 "$pid" 2>/dev/null; then
        echo "error: the game quit or crashed within $WAIT seconds of launch" >&2
        cat build/game-stdout.log >&2 || true
        for report in "$HOME/Library/Logs/DiagnosticReports/$EXECUTABLE"*; do
            [ -f "$report" ] && head -n 80 "$report" >&2
        done
        exit 1
    fi
    screencapture -x "$shot" || echo "warning: could not take a screenshot" >&2
    kill -TERM "$pid" || true
    wait "$pid" 2>/dev/null || true
    LOG="$(log show --start "$started" --style compact --predicate "subsystem == \"$SUBSYSTEM\"" 2>/dev/null || true)"
}

MODEL_STATE=notEnabled run build/game-gate.png
echo "The model gate opened."
run build/game-title.png
echo "The title screen opened."

# A new game's saved state would otherwise be continued next time.
SAVE="$HOME/Library/Application Support/Nullmere/autosave.json"
[ -f "$SAVE" ] && mv "$SAVE" "$SAVE.smoke-backup"
run build/game-world.png "$SEED" 0 unit,houses
WORLD_LOG="$LOG"
# Later in the game, with the larger type a reader can choose.
NULLMERE_TEXT=larger NULLMERE_WATCH_AFTER=9 run build/game-later.png "$SEED" 40 seat,watch
rm -f "$SAVE"
[ -f "$SAVE.smoke-backup" ] && mv "$SAVE.smoke-backup" "$SAVE"

LOG="$WORLD_LOG
$LOG"
echo "$LOG" | grep -E "renders with Metal|did not compile|could not be built|could not be made|No Metal device" || true
if echo "$LOG" | grep -qE "did not compile|could not be built|could not be made|No Metal device"; then
    echo "error: the world's Metal renderer failed, so the game fell back to its still painting" >&2
    exit 1
fi
if ! echo "$LOG" | grep -q "renders with Metal"; then
    echo "error: the world did not start rendering with Metal within $WAIT seconds" >&2
    exit 1
fi
echo "Nullmere started a new game and its world renders with Metal."
