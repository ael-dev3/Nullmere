#!/usr/bin/env bash
# Opens Nullmere Online from a debug build, presses Play, and enters a realm
# across the network: a SpacetimeDB server with the realm module published
# and the steward running beside it (see "Raising the realm" in the README).
# The app must reach the realm, arrive as a keeper and render the world with
# Metal. Saves a screenshot of the keeper's first watch, with the card that
# briefs a keeper taking up their House.
#
#   NULLMERE_REALM=http://127.0.0.1:3000/nullmere scripts/smoke-test-network.sh
#
# Only debug builds honour NULLMERE_MODEL_STATE, NULLMERE_LAUNCHER_KEYS,
# NULLMERE_REALM and NULLMERE_KEEPER.
set -euo pipefail

cd "$(dirname "$0")/.."

BIN="${BIN:-$(swift build --show-bin-path)/NullmereLauncher}"
EXECUTABLE="NullmereLauncher"
WAIT="${WAIT:-30}"
SUBSYSTEM="online.nullmere.game"
REALM="${NULLMERE_REALM:-http://127.0.0.1:3000/nullmere}"
KEEPER="${KEEPER:-Ilsen}"
IDENTITY="$PWD/build/smoke-network-identity"
mkdir -p build

if pgrep -x "$EXECUTABLE" >/dev/null; then
    echo "error: $EXECUTABLE is already running; quit it first" >&2
    exit 1
fi

rm -f "$IDENTITY"
started="$(date '+%Y-%m-%d %H:%M:%S')"
echo "Opening Nullmere Online and entering $REALM as ${KEEPER}…"
NULLMERE_MODEL_STATE=ready NULLMERE_LAUNCHER_KEYS=return NULLMERE_REALM="$REALM" \
    NULLMERE_IDENTITY_FILE="$IDENTITY" NULLMERE_KEEPER="$KEEPER" NULLMERE_SHOW=briefing \
    "$BIN" >build/network-stdout.log 2>&1 &
pid=$!
sleep "$WAIT"
if ! kill -0 "$pid" 2>/dev/null; then
    echo "error: Nullmere Online quit or crashed within $WAIT seconds of launch" >&2
    cat build/network-stdout.log >&2 || true
    exit 1
fi
screencapture -x build/game-network.png || echo "warning: could not take a screenshot" >&2
kill -TERM "$pid" || true
wait "$pid" 2>/dev/null || true
LOG="$(log show --start "$started" --style compact --predicate "subsystem == \"$SUBSYSTEM\"" 2>/dev/null || true)"
rm -f "$IDENTITY"

echo "$LOG" | grep -E "Entered the realm|renders with Metal|unreachable|refused" || true
if ! echo "$LOG" | grep -q "Entered the realm as $KEEPER"; then
    echo "error: Nullmere Online did not enter $REALM as $KEEPER within $WAIT seconds" >&2
    exit 1
fi
if ! echo "$LOG" | grep -q "renders with Metal"; then
    echo "error: the world did not start rendering with Metal" >&2
    exit 1
fi
echo "Nullmere Online entered the realm across the network and its world renders with Metal."
