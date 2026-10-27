#!/usr/bin/env bash
# Opens Nullmere Online from a debug build, presses Play, and steps into a
# realm hosted on this Mac as a keeper, past the on-device model check. It
# must still be running after a while, and its world must be rendering
# with Metal. Saves screenshots of the keeper's first watch with a company
# selected and the Houses panel open, and of the same realm forty watches
# on, a steward having played the keeper's House, with the larger type.
#
#   swift build && scripts/smoke-test-game.sh
#
# Only debug builds honour NULLMERE_MODEL_STATE, NULLMERE_LAUNCHER_KEYS,
# NULLMERE_REALM and NULLMERE_KEEPER.
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=settled-log.sh
. scripts/settled-log.sh

BIN="${BIN:-$(swift build --show-bin-path)/NullmereLauncher}"
EXECUTABLE="NullmereLauncher"
WAIT="${WAIT:-24}"
SUBSYSTEM="online.nullmere.game"
SEED="${SEED:-black moon}"
REALM_FILE="$HOME/Library/Application Support/Nullmere Online/hosted-realm.json"
IDENTITY="$PWD/build/smoke-identity"
mkdir -p build

if pgrep -x "$EXECUTABLE" >/dev/null; then
    echo "error: $EXECUTABLE is already running; quit it first" >&2
    exit 1
fi

# run <screenshot> [watches to autoplay] [what to show]
run() {
    local shot="$1"
    local autoplay="${2:-0}"
    local show="${3:-}"
    local started
    started="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "Opening Nullmere Online and entering the realm as Ilsen…"
    NULLMERE_MODEL_STATE=ready NULLMERE_LAUNCHER_KEYS=return NULLMERE_REALM=local NULLMERE_REALM_SEED="$SEED" \
        NULLMERE_IDENTITY_FILE="$IDENTITY" NULLMERE_KEEPER=Ilsen NULLMERE_AUTOPLAY="$autoplay" NULLMERE_SHOW="$show" \
        "$BIN" >build/game-stdout.log 2>&1 &
    local pid=$!
    sleep "$WAIT"
    if ! kill -0 "$pid" 2>/dev/null; then
        echo "error: Nullmere Online quit or crashed within $WAIT seconds of launch" >&2
        cat build/game-stdout.log >&2 || true
        for report in "$HOME/Library/Logs/DiagnosticReports/$EXECUTABLE"*; do
            [ -f "$report" ] && head -n 80 "$report" >&2
        done
        exit 1
    fi
    screencapture -x "$shot" || echo "warning: could not take a screenshot" >&2
    kill -TERM "$pid" || true
    wait "$pid" 2>/dev/null || true
    LOG="$(settled_log "$started" "$SUBSYSTEM" "renders with Metal")"
    # A debug build says it on its own output too, the moment it happens;
    # the unified log can lag behind.
    LOG="$LOG
$(grep -h "renders with Metal" build/game-stdout.log 2>/dev/null || true)"
}

# A fresh realm, and a fresh keeper; whatever was here is put back after.
[ -f "$REALM_FILE" ] && mv "$REALM_FILE" "$REALM_FILE.smoke-backup"
defaults delete "$EXECUTABLE" keeper.name.hosted >/dev/null 2>&1 || true
rm -f "$IDENTITY"
run build/game-world.png 0 unit,houses
WORLD_LOG="$LOG"
# The same realm later on, the keeper returning by identity alone, with the
# larger type a reader can choose.
NULLMERE_TEXT=larger NULLMERE_WATCH_AFTER=3 WAIT=30 run build/game-later.png 40 seat,watch
rm -f "$REALM_FILE" "$IDENTITY"
defaults delete "$EXECUTABLE" keeper.name.hosted >/dev/null 2>&1 || true
[ -f "$REALM_FILE.smoke-backup" ] && mv "$REALM_FILE.smoke-backup" "$REALM_FILE"

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
echo "Nullmere Online entered a realm and its world renders with Metal."
