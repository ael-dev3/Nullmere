#!/usr/bin/env bash
# Opens a debug build of the launcher as if Apple's on-device model were in
# a given state, so every screen can be seen on a Mac without Apple
# Intelligence, such as CI. Photographs the menu, News and Settings with
# the model ready, the realm's front door that Play crosses to, and the
# requirement screen with Apple Intelligence off and with its model
# downloading. Checks the launcher keeps running and its
# lake renders with Metal.
#
#   swift build && scripts/smoke-test-launcher-menu.sh
#
# Only debug builds honour NULLMERE_MODEL_STATE and
# NULLMERE_LAUNCHER_KEYS (keys typed once the opening is over, through the
# same path as the window's); release builds always ask Foundation Models.
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=settled-log.sh
. scripts/settled-log.sh

BIN="${BIN:-$(swift build --show-bin-path)/NullmereLauncher}"
EXECUTABLE="NullmereLauncher"
WAIT="${WAIT:-14}"
SUBSYSTEM="online.nullmere.launcher"
# News downloads from the same place as in a release: news/news.json on
# main. Set NEWS_URL to try another feed, such as a branch's copy.
NEWS_URL="${NEWS_URL:-}"
mkdir -p build

if pgrep -x "$EXECUTABLE" >/dev/null; then
    echo "error: $EXECUTABLE is already running; quit it first" >&2
    exit 1
fi

# run <screenshot> [keys] [model state]
run() {
    local shot="$1"
    local keys="${2:-}"
    local state="${3:-ready}"
    local started
    started="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "Opening the launcher${keys:+, then typing $keys}…"
    NULLMERE_MODEL_STATE="$state" NULLMERE_LAUNCHER_KEYS="$keys" NULLMERE_NEWS_URL="$NEWS_URL" "$BIN" >build/launcher-stdout.log 2>&1 &
    local pid=$!
    sleep "$WAIT"
    if ! kill -0 "$pid" 2>/dev/null; then
        echo "error: the launcher quit or crashed within $WAIT seconds of launch" >&2
        cat build/launcher-stdout.log >&2 || true
        exit 1
    fi
    screencapture -x "$shot" || echo "warning: could not take a screenshot" >&2
    kill -TERM "$pid" || true
    wait "$pid" 2>/dev/null || true
    local log
    log="$(settled_log "$started" "$SUBSYSTEM" "renders with Metal")"
    # A debug build says it on its own output too, the moment it happens;
    # the unified log can lag behind.
    if ! grep -q "renders with Metal" build/launcher-stdout.log && ! echo "$log" | grep -q "renders with Metal"; then
        echo "error: the lake did not render with Metal" >&2
        cat build/launcher-stdout.log >&2 || true
        exit 1
    fi
    LOG="$log"
}

run build/launcher-menu.png
run build/launcher-news.png right,return
echo "$LOG" | grep -E "News (updated|not updated)" || true
if ! echo "$LOG" | grep -q "News updated"; then
    echo "error: News did not download its feed from ${NEWS_URL:-main}" >&2
    exit 1
fi
run build/launcher-settings.png right,right,return,down
# Play: Return on the lit Play crosses into the realm's front door, in the
# same window, with a realm hosted on this Mac and a throwaway identity.
# Whatever realm and keeper this Mac had are put back however it ends.
. scripts/smoke-realm.sh
set_aside_realm "$EXECUTABLE" "$PWD/build/smoke-identity-door"
NULLMERE_REALM=local NULLMERE_IDENTITY_FILE="$PWD/build/smoke-identity-door" run build/launcher-play.png return
echo "$LOG" | grep -E "Crossing into the realm" || true
if ! echo "$LOG" | grep -q "Crossing into the realm"; then
    echo "error: Play did not cross into the realm" >&2
    exit 1
fi
echo "Play crossed into the realm's front door."

# The requirement screen for the states a real Mac passes through.
run build/launcher-off.png "" notEnabled
run build/launcher-downloading.png "" downloading
echo "The launcher's menu, News, Settings and requirement screens opened, and its lake renders with Metal."
