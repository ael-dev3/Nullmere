#!/usr/bin/env bash
# Opens Nullmere Online from a debug build, presses Play, and steps into a
# realm hosted on this Mac as a keeper, past the on-device model check. It
# must still be running after a while, and its world must be rendering
# with Metal. Saves screenshots of the keeper's first watch with a company
# selected and the Houses panel open, and the same with the night drawn
# Bright, as a keeper may choose it; of the same realm eight watches on
# as a keeper sees it most of the time, nothing chosen and no panel open,
# the land's growth drawn in full, as a Mac with ten gigabytes or more for
# its graphics draws it (each launch says the detail it drew at in
# build/game-detail.log, and what this Mac's Auto comes to);
# and forty watches on, a steward having played the keeper's House, with
# the larger type; and the Still from low over its deepest water; and
# counsel taken of the House's first free commander, a question put to
# them as the keeper would put it, with what came of it: the answer of
# Apple's on-device model where this Mac's can be asked, or why none came
# where it can't, as on CI's virtual Macs; and forty watches more on, the
# commander who led in the House's latest battle asked of it, as from its
# report, beside the House's reports with their two sides painted, or the
# reports alone where none names one (which, kept in
# build/game-counsel-battle.log).
#
#   swift build && scripts/smoke-test-game.sh
#
# Only debug builds honour NULLMERE_MODEL_STATE, NULLMERE_LAUNCHER_KEYS,
# NULLMERE_REALM, NULLMERE_KEEPER, NULLMERE_NIGHT and NULLMERE_DETAIL.
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=settled-log.sh
. scripts/settled-log.sh

BIN="${BIN:-$(swift build --show-bin-path)/NullmereLauncher}"
EXECUTABLE="NullmereLauncher"
WAIT="${WAIT:-24}"
SUBSYSTEM="online.nullmere.game"
SEED="${SEED:-black moon}"
IDENTITY="$PWD/build/smoke-identity"
mkdir -p build
: > build/game-detail.log

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
    grep -h "draws the land's growth" build/game-stdout.log 2>/dev/null | head -1 | sed "s|^|$(basename "$shot"): |" >> build/game-detail.log || true
    LOG="$(settled_log "$started" "$SUBSYSTEM" "renders with Metal")"
    # A debug build says it on its own output too, the moment it happens;
    # the unified log can lag behind.
    LOG="$LOG
$(grep -h "renders with Metal" build/game-stdout.log 2>/dev/null || true)"
}

# A fresh realm, and a fresh keeper; whatever was here is put back
# however the test ends.
. scripts/smoke-realm.sh
set_aside_realm "$EXECUTABLE" "$IDENTITY"
run build/game-world.png 0 unit,houses
WORLD_LOG="$LOG"
# The first view again, at the same watch, with the night drawn Bright, as a
# keeper may choose it in the realm's Settings, to judge beside the night as
# it was made.
NULLMERE_NIGHT=bright run build/game-world-bright.png 0 unit,houses
WORLD_LOG="$WORLD_LOG
$LOG"
# The same realm as a keeper sees it most of the time: nothing chosen, no
# panel open, how much of the world the interface leaves in view; the
# land's growth in full, as a Mac with memory enough for its graphics draws
# it, where a virtual Mac's Auto may draw less.
NULLMERE_DETAIL=high run build/game-plain.png 8 ""
WORLD_LOG="$WORLD_LOG
$LOG"
# The Still close and low, nothing chosen: the black water, the moon's
# road on it and the far shore, to judge the lake by.
run build/game-lakes.png 0 lake
WORLD_LOG="$WORLD_LOG
$LOG"
# The same view with one pass of the renderer left out at a time, to tell
# which draws what (debug builds only; DEBUG_PASSES=1 asks for them, as
# they add five launches to the run).
if [ "${DEBUG_PASSES:-0}" = 1 ]; then
    for pass in ${DEBUG_PASS_LIST:-land furniture models water motes}; do
        NULLMERE_DEBUG_PASSES="$pass" run "build/game-lakes-no-$pass.png" 0 lake
    done
fi
# Counsel of a commander, asked a question as the keeper would ask it, and
# what came of it half a minute after the launch.
WAIT=30 run build/game-counsel.png 0 counsel
WORLD_LOG="$WORLD_LOG
$LOG"
# The same realm later on, the keeper returning by identity alone, with the
# larger type a reader can choose.
NULLMERE_TEXT=larger NULLMERE_WATCH_AFTER=3 WAIT=30 run build/game-later.png 40 seat,watch
WORLD_LOG="$WORLD_LOG
$LOG"
# Forty watches more, played by the steward, then counsel of the commander
# who led in the House's latest battle, asked of it as from its report; or,
# where no report names one, the House's reports as the Chronicle keeps them.
WAIT=30 run build/game-counsel-battle.png 40 battlecounsel
grep -h "^Counsel asked of" build/game-stdout.log > build/game-counsel-battle.log 2>/dev/null || true
cat build/game-counsel-battle.log

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
