#!/usr/bin/env bash
# Raises the Nullmere Online realm in one command: publishes the realm
# module to a SpacetimeDB server and starts the steward beside it.
#
#   scripts/raise-realm.sh maincloud     # the realm proper, on maincloud
#   scripts/raise-realm.sh local         # a realm on this machine
#
# For maincloud, sign in once first with `spacetime login` (it opens a
# GitHub sign-in); the identity you sign in with owns the realm and its
# steward. Everything else this script does itself.
#
# Settings, all optional:
#   REALM_DB=nullmere        the database name (maincloud names are global)
#   STEWARD=docker|background|foreground|none
#                            how the steward runs (default: docker for
#                            maincloud when Docker is there, else background)
#   NULLMERE_REALM_NAME, NULLMERE_REALM_SEED, NULLMERE_REALM_SEATS,
#   NULLMERE_WATCH_SECONDS   shape a new realm (an existing one is kept)
#   SPACETIME_CLEAR=1        publish with --delete-data: a fresh realm
#   CONFIGURATION=release    how the steward is built when run by Swift
#   STEWARD_LOG=...          where a background steward writes
set -euo pipefail

cd "$(dirname "$0")/.."

TARGET="${1:-}"
case "$TARGET" in
    maincloud) HOST="https://maincloud.spacetimedb.com" ;;
    local) HOST="http://127.0.0.1:3000" ;;
    *) echo "usage: scripts/raise-realm.sh maincloud|local" >&2; exit 2 ;;
esac
DB="${REALM_DB:-nullmere}"
ADDRESS="$HOST/$DB"
STATE_DIR="${NULLMERE_STATE_DIR:-$HOME/.config/nullmere}"
TOKEN_FILE="$STATE_DIR/steward-token-$TARGET"
LOG="${STEWARD_LOG:-$STATE_DIR/steward-$TARGET.log}"
mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"

say() { printf '\n== %s\n' "$*"; }
need() {
    command -v "$1" >/dev/null 2>&1 || { echo "error: $1 is needed. $2" >&2; exit 1; }
}

case "$DB" in
    *[!a-z0-9-]*|"") echo "error: REALM_DB may hold lowercase letters, digits and hyphens only" >&2; exit 1 ;;
esac

say "Checking tools"
export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
need spacetime "Install it: curl -sSf https://install.spacetimedb.com | sh"
need cargo "Install Rust: curl -sSf https://sh.rustup.rs | sh"
if command -v rustup >/dev/null 2>&1; then
    rustup target add wasm32-unknown-unknown >/dev/null
fi
spacetime --version | head -n 1

if [ "$TARGET" = local ]; then
    if ! curl -s -o /dev/null -X POST "$HOST/v1/identity"; then
        say "Starting SpacetimeDB on this machine"
        (nohup spacetime start > "$STATE_DIR/spacetime-local.log" 2>&1 &)
        for _ in $(seq 1 90); do
            curl -s -o /dev/null -X POST "$HOST/v1/identity" && break
            sleep 1
        done
        curl -s -o /dev/null -X POST "$HOST/v1/identity" || { echo "error: SpacetimeDB didn't start; see $STATE_DIR/spacetime-local.log" >&2; exit 1; }
    fi
    if ! spacetime login show --token >/dev/null 2>&1; then
        spacetime login --server-issued-login local
    fi
else
    if ! spacetime login show --token >/dev/null 2>&1; then
        echo "error: sign in to SpacetimeDB first: run \`spacetime login\` (it opens a GitHub sign-in), then this again." >&2
        exit 1
    fi
fi

say "Publishing the realm module to $ADDRESS"
CLEAR=()
[ "${SPACETIME_CLEAR:-}" = 1 ] && CLEAR=(--delete-data)
(cd realm-server && spacetime publish --server "$TARGET" --yes "${CLEAR[@]+"${CLEAR[@]}"}" "$DB")

# The steward acts as the identity that published the module.
token="$(spacetime login show --token | awk '{print $NF}' | tail -n 1)"
[ -n "$token" ] || { echo "error: couldn't read the SpacetimeDB token" >&2; exit 1; }
( umask 077; printf '%s\n' "$token" > "$TOKEN_FILE" )

MODE="${STEWARD:-}"
if [ -z "$MODE" ]; then
    if [ "$TARGET" = maincloud ] && command -v docker >/dev/null 2>&1; then MODE=docker; else MODE=background; fi
fi

steward_env() {
    env NULLMERE_STEWARD_TOKEN_FILE="$TOKEN_FILE" \
        ${NULLMERE_REALM_NAME:+NULLMERE_REALM_NAME="$NULLMERE_REALM_NAME"} \
        ${NULLMERE_REALM_SEED:+NULLMERE_REALM_SEED="$NULLMERE_REALM_SEED"} \
        ${NULLMERE_REALM_SEATS:+NULLMERE_REALM_SEATS="$NULLMERE_REALM_SEATS"} \
        ${NULLMERE_WATCH_SECONDS:+NULLMERE_WATCH_SECONDS="$NULLMERE_WATCH_SECONDS"} \
        "$@"
}

case "$MODE" in
    none)
        say "The module is published; start the steward yourself"
        ;;
    docker)
        say "Building and starting the steward container"
        docker build -q -f Dockerfile.steward -t nullmere-steward . >/dev/null
        docker rm -f "nullmere-steward-$DB" >/dev/null 2>&1 || true
        docker run -d --name "nullmere-steward-$DB" --restart unless-stopped \
            -e NULLMERE_STEWARD_TOKEN="$token" \
            ${NULLMERE_REALM_NAME:+-e NULLMERE_REALM_NAME="$NULLMERE_REALM_NAME"} \
            ${NULLMERE_REALM_SEED:+-e NULLMERE_REALM_SEED="$NULLMERE_REALM_SEED"} \
            ${NULLMERE_REALM_SEATS:+-e NULLMERE_REALM_SEATS="$NULLMERE_REALM_SEATS"} \
            ${NULLMERE_WATCH_SECONDS:+-e NULLMERE_WATCH_SECONDS="$NULLMERE_WATCH_SECONDS"} \
            nullmere-steward "$ADDRESS" >/dev/null
        for _ in $(seq 1 30); do
            docker logs "nullmere-steward-$DB" 2>&1 | grep -q "Stewarding" && break
            sleep 1
        done
        docker logs "nullmere-steward-$DB" 2>&1 | tail -n 5
        docker logs "nullmere-steward-$DB" 2>&1 | grep -q "Stewarding" || { echo "error: the steward didn't take up the realm" >&2; exit 1; }
        ;;
    background|foreground)
        say "Building the steward"
        swift build -c "${CONFIGURATION:-release}" --product NullmereSteward >/dev/null
        BIN="$(swift build -c "${CONFIGURATION:-release}" --show-bin-path)/NullmereSteward"
        if [ "$MODE" = foreground ]; then
            say "Stewarding $ADDRESS (Ctrl-C to stop)"
            steward_env "$BIN" "$ADDRESS"
            exit $?
        fi
        pkill -f "NullmereSteward $ADDRESS" 2>/dev/null || true
        steward_env nohup "$BIN" "$ADDRESS" > "$LOG" 2>&1 &
        for _ in $(seq 1 30); do
            grep -q "Stewarding" "$LOG" 2>/dev/null && break
            sleep 1
        done
        tail -n 5 "$LOG"
        grep -q "Stewarding" "$LOG" || { echo "error: the steward didn't take up the realm; see $LOG" >&2; exit 1; }
        ;;
    *) echo "error: STEWARD must be docker, background, foreground or none" >&2; exit 2 ;;
esac

say "The realm is up at $ADDRESS"
if [ "$ADDRESS" != "https://maincloud.spacetimedb.com/nullmere" ]; then
    echo "Build the app for it:  REALM_ADDRESS=$ADDRESS scripts/build-app.sh"
    echo "Or try a debug build:  NULLMERE_REALM=$ADDRESS swift run NullmereLauncher"
else
    echo "Release builds of Nullmere Online go here already: scripts/build-app.sh"
fi
