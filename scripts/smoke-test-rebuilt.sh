#!/usr/bin/env bash
# Opens Nullmere Online on the rebuilt realm (realm/): its module built
# and published to the SpacetimeDB server already running on this Mac, a
# dozen players played into it, and the app opened on it as one more, who
# is settled beside them. The app must still be running after a while,
# and its world must be rendering with Metal. Saves three pictures, each
# at noon of the world's day: the player's first sight of their city and
# their neighbours (rebuilt-world.png), the city's buildings open
# (rebuilt-city.png), and the nearest barrow of the Unquiet chosen
# (rebuilt-barrow.png).
#
#   swift build && scripts/smoke-test-rebuilt.sh
#
# SERVER names the SpacetimeDB server (http://127.0.0.1:3000) and
# DATABASE the name to publish under (nullmere-rebuilt). Whatever is
# published under that name is replaced.
#
# Only debug builds honour NULLMERE_REBUILT_REALM, NULLMERE_REBUILT_NAME,
# NULLMERE_REBUILT_SHOW and NULLMERE_HOUR.
set -euo pipefail
export NULLMERE_HOUR="${NULLMERE_HOUR:-12}"

cd "$(dirname "$0")/.."

BIN="${BIN:-$(swift build --show-bin-path)/NullmereLauncher}"
EXECUTABLE="NullmereLauncher"
WAIT="${WAIT:-30}"
SERVER="${SERVER:-http://127.0.0.1:3000}"
DATABASE="${DATABASE:-nullmere-rebuilt}"
IDENTITY="$PWD/build/rebuilt-identity"
mkdir -p build
rm -f "$IDENTITY"

if pgrep -x "$EXECUTABLE" >/dev/null; then
    echo "error: $EXECUTABLE is already running; quit it first" >&2
    exit 1
fi
if ! curl -s -o /dev/null -X POST "$SERVER/v1/identity"; then
    echo "error: no SpacetimeDB server answers at $SERVER" >&2
    exit 1
fi

echo "Building the rebuilt realm's module…"
rustup target add wasm32-unknown-unknown >/dev/null 2>&1 || true
(cd realm && cargo build --release --target wasm32-unknown-unknown 2>&1 | tail -n 3)
spacetime publish --server "$SERVER" --bin-path realm/target/wasm32-unknown-unknown/release/realm.wasm --yes --delete-data "$DATABASE"
# Sixty times its written pace while the players settle in; they slow it
# to twice before their armies set out.
spacetime call --server "$SERVER" "$DATABASE" set_pace 60
python3 realm/people.py "$SERVER" "$DATABASE" 12 -- spacetime call --server "$SERVER" "$DATABASE" set_pace

LOG=""
# run <screenshot> [what to show]
run() {
    local shot="$1"
    local show="${2:-}"
    echo "Opening Nullmere Online on the rebuilt realm…"
    NULLMERE_REBUILT_REALM="$SERVER/$DATABASE" NULLMERE_REBUILT_NAME="Ilsen" NULLMERE_REBUILT_SHOW="$show" \
        NULLMERE_IDENTITY_FILE="$IDENTITY" "$BIN" >build/rebuilt-stdout.log 2>&1 &
    local pid=$!
    sleep "$WAIT"
    if ! kill -0 "$pid" 2>/dev/null; then
        echo "error: Nullmere Online quit or crashed within $WAIT seconds of opening on the rebuilt realm" >&2
        cat build/rebuilt-stdout.log >&2 || true
        for report in "$HOME/Library/Logs/DiagnosticReports/$EXECUTABLE"*; do
            [ -f "$report" ] && head -n 80 "$report" >&2
        done
        exit 1
    fi
    screencapture -x "$shot" || echo "warning: could not take a screenshot" >&2
    kill -TERM "$pid" || true
    wait "$pid" 2>/dev/null || true
    LOG="$LOG
$(grep -hE "renders with Metal|did not compile|could not be built|could not be made|No Metal device" build/rebuilt-stdout.log 2>/dev/null || true)"
}

run build/rebuilt-world.png ""
run build/rebuilt-city.png city
run build/rebuilt-barrow.png barrow

# The player the app joined as is in the realm, with a city of their own.
PLAYERS="$(python3 realm/people.py "$SERVER" "$DATABASE" --names || true)"
if ! echo "$PLAYERS" | grep -q "Ilsen"; then
    echo "error: the app did not join the rebuilt realm as Ilsen" >&2
    echo "$PLAYERS" | tail -n 20 >&2
    exit 1
fi
echo "$LOG" | grep -E "renders with Metal|did not compile|could not be built|could not be made|No Metal device" || true
if echo "$LOG" | grep -qE "did not compile|could not be built|could not be made|No Metal device"; then
    echo "error: the world's Metal renderer failed on the rebuilt realm" >&2
    exit 1
fi
if ! echo "$LOG" | grep -q "renders with Metal"; then
    echo "error: the rebuilt realm's world did not start rendering with Metal within $WAIT seconds" >&2
    exit 1
fi
echo "Nullmere Online joined the rebuilt realm as Ilsen, and its world renders with Metal."
