#!/usr/bin/env bash
# Raises the Nullmere Online realm in one command: publishes the realm
# module to a SpacetimeDB server and starts the steward beside it.
#
#   scripts/raise-realm.sh maincloud             # the realm proper, on maincloud
#   scripts/raise-realm.sh local                 # a realm on this machine
#   scripts/raise-realm.sh maincloud --dry-run   # check and build everything,
#                                                # publish and start nothing
#   scripts/raise-realm.sh local --stop          # stop a background steward
#
# When the steward is up, the script reads the realm's status back as any
# keeper would, and fails if the realm doesn't answer.
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
#   NULLMERE_STATE_DIR=...   where the steward's token and log are kept
#                            (default ~/.config/nullmere)
set -euo pipefail

cd "$(dirname "$0")/.."

TARGET="${1:-}"
ACTION="${2:-}"
case "$TARGET" in
    maincloud) HOST="https://maincloud.spacetimedb.com" ;;
    local) HOST="http://127.0.0.1:3000" ;;
    *) echo "usage: scripts/raise-realm.sh maincloud|local [--dry-run|--stop]" >&2; exit 2 ;;
esac
case "$ACTION" in
    ""|--dry-run|--stop) ;;
    *) echo "usage: scripts/raise-realm.sh maincloud|local [--dry-run|--stop]" >&2; exit 2 ;;
esac
DB="${REALM_DB:-nullmere}"
ADDRESS="$HOST/$DB"
STATE_DIR="${NULLMERE_STATE_DIR:-$HOME/.config/nullmere}"
TOKEN_FILE="$STATE_DIR/steward-token-$TARGET"
LOG="${STEWARD_LOG:-$STATE_DIR/steward-$TARGET.log}"
PID_FILE="$STATE_DIR/steward-$TARGET-$DB.pid"
mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"

say() { printf '\n== %s\n' "$*"; }
# A steward in a container can't reach a realm on this machine's 127.0.0.1.
docker_reaches_realm() {
    if [ "$MODE" = docker ] && [ "$TARGET" = local ]; then
        echo "error: a steward in a container can't reach a realm on this machine; use STEWARD=background or foreground" >&2
        exit 2
    fi
}
plan() { printf '   would: %s\n' "$*"; }
need() {
    command -v "$1" >/dev/null 2>&1 || { echo "error: $1 is needed. $2" >&2; exit 1; }
}

# The background steward this script started for this realm, by the pid it
# kept: only that process, never another that happens to share its words.
stop_background_steward() {
    local pid
    pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    rm -f "$PID_FILE"
    case "$pid" in
        "")
            # Started before pids were kept: by its command line, whole.
            pkill -f "(^|/)NullmereSteward $ADDRESS\$" 2>/dev/null
            return
            ;;
        *[!0-9]*) return 1 ;;
    esac
    ps -p "$pid" -o command= 2>/dev/null | grep -q "NullmereSteward" || return 1
    kill "$pid" 2>/dev/null || return 1
    for _ in $(seq 1 20); do
        kill -0 "$pid" 2>/dev/null || return 0
        sleep 0.25
    done
    kill -9 "$pid" 2>/dev/null || true
}

case "$DB" in
    *[!a-z0-9-]*|"") echo "error: REALM_DB may hold lowercase letters, digits and hyphens only" >&2; exit 1 ;;
esac

if [ "$ACTION" = --stop ]; then
    say "Stopping the steward of $ADDRESS"
    docker rm -f "nullmere-steward-$DB" >/dev/null 2>&1 && echo "Stopped its container." || true
    if stop_background_steward; then echo "Stopped it."; else echo "No steward of $ADDRESS was running here."; fi
    exit 0
fi

# Who issued the SpacetimeDB CLI's sign-in, read from its token. A realm on
# this machine signs the CLI in with a token its own server issued, which
# maincloud won't take: that is not a sign-in for maincloud.
token_issuer() {
    local payload
    payload="$(spacetime login show --token 2>/dev/null | awk '{print $NF}' | tail -n 1 | cut -d. -f2 | tr '_-' '/+')"
    while [ $(( ${#payload} % 4 )) -ne 0 ]; do payload="$payload="; done
    printf '%s' "$payload" | base64 -d 2>/dev/null | sed -n 's/.*"iss" *: *"\([^"]*\)".*/\1/p'
}
signed_in_for_maincloud() {
    spacetime login show --token >/dev/null 2>&1 || return 1
    case "$(token_issuer)" in
        *localhost*|*127.0.0.1*) return 1 ;;
    esac
}

# Reads the realm's status as a keeper would: a fresh identity, and SQL.
realm_answers() {
    local token
    token="$(curl -s -X POST "$HOST/v1/identity" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')"
    [ -n "$token" ] || return 1
    curl -s -X POST -H "Authorization: Bearer $token" --data "SELECT version, status FROM status" \
        "$HOST/v1/database/$DB/sql" | grep -o 'watch[\\"]*:[0-9]*' | head -n 1 | grep -o '[0-9]*$'
}

say "Checking tools"
export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
need spacetime "Install it: curl -sSf https://install.spacetimedb.com | sh"
need cargo "Install Rust: curl -sSf https://sh.rustup.rs | sh"
if command -v rustup >/dev/null 2>&1; then
    rustup target add wasm32-unknown-unknown >/dev/null
fi
spacetime --version | head -n 1

if [ "$ACTION" = --dry-run ]; then
    say "Rehearsing: nothing is published or started"
    if [ "$TARGET" = maincloud ]; then
        if signed_in_for_maincloud; then
            echo "Signed in to SpacetimeDB; the realm will belong to that identity."
        else
            echo "Not signed in for maincloud yet: run \`spacetime login\` (it opens a GitHub sign-in) before the real run."
        fi
    fi
    say "Building the realm module"
    (cd realm-server && spacetime build)
    MODE="${STEWARD:-}"
    if [ -z "$MODE" ]; then
        if [ "$TARGET" = maincloud ] && command -v docker >/dev/null 2>&1; then MODE=docker; else MODE=background; fi
    fi
    docker_reaches_realm
    case "$MODE" in
        docker)
            say "Building the steward's container"
            docker build -q -f Dockerfile.steward -t nullmere-steward . >/dev/null
            ;;
        background|foreground|none)
            say "Building the steward"
            swift build -c "${CONFIGURATION:-release}" --product NullmereSteward >/dev/null
            ;;
        *) echo "error: STEWARD must be docker, background, foreground or none" >&2; exit 2 ;;
    esac
    say "The plan"
    [ "$TARGET" = local ] && plan "start SpacetimeDB on this machine if it isn't running"
    plan "publish realm-server to $ADDRESS${SPACETIME_CLEAR:+, clearing its data}"
    plan "keep the publishing identity's token in $TOKEN_FILE (readable by you alone)"
    [ "$MODE" = none ] || plan "start the steward ($MODE) as that identity, and wait for it to take up the realm"
    [ "$MODE" = none ] || plan "read the realm's status back as a keeper would"
    echo
    if [ "$TARGET" = maincloud ] && ! signed_in_for_maincloud; then
        # Not ready: the last line says so, not that all is well.
        echo "Everything builds, but you aren't signed in: run \`spacetime login\`, then this again."
    else
        echo "Everything builds. Run it again without --dry-run to raise the realm."
    fi
    exit 0
fi

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
    if ! signed_in_for_maincloud; then
        echo "error: sign in to SpacetimeDB for maincloud first: run \`spacetime login\` (it opens a GitHub sign-in), then this again." >&2
        echo "(A realm raised on this machine signs the CLI in with its own server's token, which maincloud won't take.)" >&2
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
docker_reaches_realm

# `exec`, so the steward takes this shell's place: a steward started in the
# background is then the very process whose pid is kept.
steward_env() {
    exec env NULLMERE_STEWARD_TOKEN_FILE="$TOKEN_FILE" \
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
        # The token is read from its file, mounted read-only, so it is never
        # kept in the container's settings for `docker inspect` to show.
        docker run -d --name "nullmere-steward-$DB" --restart unless-stopped \
            --user "$(id -u):$(id -g)" \
            -v "$TOKEN_FILE:/run/nullmere/steward-token:ro" \
            -e NULLMERE_STEWARD_TOKEN_FILE=/run/nullmere/steward-token \
            ${NULLMERE_REALM_NAME:+-e NULLMERE_REALM_NAME="$NULLMERE_REALM_NAME"} \
            ${NULLMERE_REALM_SEED:+-e NULLMERE_REALM_SEED="$NULLMERE_REALM_SEED"} \
            ${NULLMERE_REALM_SEATS:+-e NULLMERE_REALM_SEATS="$NULLMERE_REALM_SEATS"} \
            ${NULLMERE_WATCH_SECONDS:+-e NULLMERE_WATCH_SECONDS="$NULLMERE_WATCH_SECONDS"} \
            nullmere-steward "$ADDRESS" >/dev/null
        # A steward started again waits up to a minute for its old hold.
        for _ in $(seq 1 90); do
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
        fi
        stop_background_steward || true
        # Emptied first, so a line from an earlier steward can't pass for
        # this one's.
        : > "$LOG"
        ( steward_env nohup "$BIN" "$ADDRESS" ) >> "$LOG" 2>&1 &
        pid=$!
        echo "$pid" > "$PID_FILE"
        for _ in $(seq 1 90); do
            grep -q "Stewarding" "$LOG" 2>/dev/null && break
            kill -0 "$pid" 2>/dev/null || break
            sleep 1
        done
        tail -n 5 "$LOG"
        grep -q "Stewarding" "$LOG" || { echo "error: the steward didn't take up the realm; see $LOG" >&2; exit 1; }
        ;;
    *) echo "error: STEWARD must be docker, background, foreground or none" >&2; exit 2 ;;
esac

if [ "$MODE" != none ]; then
    say "Asking the realm how it stands, as a keeper would"
    answered=""
    for _ in $(seq 1 60); do
        answered="$(realm_answers || true)"
        [ -n "$answered" ] && break
        sleep 1
    done
    [ -n "$answered" ] || { echo "error: the realm at $ADDRESS doesn't answer a keeper" >&2; exit 1; }
    echo "The realm answers: it stands at watch $answered."
fi

say "The realm is up at $ADDRESS"
if [ "$ADDRESS" != "https://maincloud.spacetimedb.com/nullmere" ]; then
    echo "Build the app for it:  REALM_ADDRESS=$ADDRESS scripts/build-app.sh"
    echo "Or try a debug build:  NULLMERE_REALM=$ADDRESS swift run NullmereLauncher"
else
    echo "Release builds of Nullmere Online go here already: scripts/build-app.sh"
fi
