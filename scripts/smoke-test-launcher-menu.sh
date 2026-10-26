#!/usr/bin/env bash
# Opens a debug build of the launcher as if Apple's on-device model were
# ready, so the menu and its panels can be seen on a Mac without Apple
# Intelligence, such as CI. Photographs the menu, News and Settings, and
# checks the launcher keeps running and its lake renders with Metal.
#
#   swift build && scripts/smoke-test-launcher-menu.sh
#
# Only debug builds honour NULLMERE_SKIP_MODEL_CHECK and
# NULLMERE_LAUNCHER_KEYS (keys typed once the opening is over, through the
# same path as the window's); release builds always ask Foundation Models.
set -euo pipefail

cd "$(dirname "$0")/.."

BIN="${BIN:-$(swift build --show-bin-path)/NullmereLauncher}"
EXECUTABLE="NullmereLauncher"
WAIT="${WAIT:-14}"
SUBSYSTEM="online.nullmere.launcher"
mkdir -p build

if pgrep -x "$EXECUTABLE" >/dev/null; then
    echo "error: $EXECUTABLE is already running; quit it first" >&2
    exit 1
fi

# run <screenshot> [keys]
run() {
    local shot="$1"
    local keys="${2:-}"
    local started
    started="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "Opening the launcher${keys:+, then typing $keys}…"
    NULLMERE_SKIP_MODEL_CHECK=1 NULLMERE_LAUNCHER_KEYS="$keys" "$BIN" >build/launcher-stdout.log 2>&1 &
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
    log="$(log show --start "$started" --style compact --predicate "subsystem == \"$SUBSYSTEM\"" 2>/dev/null || true)"
    if ! echo "$log" | grep -q "renders with Metal"; then
        echo "error: the lake did not render with Metal" >&2
        exit 1
    fi
}

run build/launcher-menu.png
run build/launcher-news.png right,return
run build/launcher-settings.png right,right,return,down
echo "The launcher's menu, News and Settings opened, and its lake renders with Metal."
