#!/usr/bin/env bash
# Launches the bundled app and checks that it really starts: it must still be
# running after a few seconds, and its lake must be rendering with Metal (the
# launcher falls back to a still painting, and logs why, if the shader or
# pipeline fails). Saves a screenshot of the screen, Dock included.
#
#   scripts/build-app.sh && scripts/smoke-test-app.sh
#
# On a Mac without Apple Intelligence, such as a CI runner, the launcher
# opens on its requirement screen; that is expected.
set -euo pipefail

cd "$(dirname "$0")/.."

APP="${APP:-build/Nullmere Online.app}"
EXECUTABLE="NullmereLauncher"
WAIT="${WAIT:-15}"
SHOT="${SHOT:-build/launcher.png}"
SUBSYSTEM="online.nullmere.launcher"

if pgrep -x "$EXECUTABLE" >/dev/null; then
    echo "error: $EXECUTABLE is already running; quit it first" >&2
    exit 1
fi

started="$(date '+%Y-%m-%d %H:%M:%S')"
echo "Opening ${APP}…"
open "$APP"
sleep "$WAIT"

if ! pgrep -x "$EXECUTABLE" >/dev/null; then
    echo "error: Nullmere Online quit or crashed within $WAIT seconds of launch" >&2
    for report in "$HOME/Library/Logs/DiagnosticReports/$EXECUTABLE"*; do
        [ -f "$report" ] && head -n 80 "$report" >&2
    done
    exit 1
fi

backdrop_log="$(log show --start "$started" --style compact --predicate "subsystem == \"$SUBSYSTEM\"" 2>/dev/null || true)"

screencapture -x "$SHOT" || echo "warning: could not take a screenshot" >&2
# A signal rather than an Apple Event, which could wait on a privacy prompt.
pkill -TERM -x "$EXECUTABLE" || true

echo "$backdrop_log" | grep -E "renders with Metal|did not compile|could not be built|No Metal device" || true
if echo "$backdrop_log" | grep -qE "did not compile|could not be built|No Metal device"; then
    echo "error: the lake's Metal renderer failed, so the launcher fell back to its still painting" >&2
    exit 1
fi
if ! echo "$backdrop_log" | grep -q "renders with Metal"; then
    echo "error: the lake did not start rendering with Metal within $WAIT seconds" >&2
    exit 1
fi

# The release app asks the Foundation Models framework itself; it must have
# had an answer and shown the matching screen.
echo "$backdrop_log" | grep "On-device model:" || true
if ! echo "$backdrop_log" | grep "On-device model:" | grep -qv "Checking"; then
    echo "error: the launcher never had an answer about the on-device model" >&2
    exit 1
fi

echo "Nullmere Online started and its lake renders with Metal."
if [ -s "$SHOT" ]; then
    echo "Screenshot: $SHOT"
fi
