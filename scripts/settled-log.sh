#!/usr/bin/env bash
# Sourced by the smoke tests. macOS's unified log can take a few seconds to
# hold what an app wrote, so a test that reads it the moment the app stops
# can miss a line that was written.
#
#   settled_log <start> <subsystem> <pattern>...
#
# Prints the log of <subsystem> since <start>, read again until every
# <pattern> is in it, for up to ten seconds.
settled_log() {
    local start="$1" subsystem="$2"
    shift 2
    local log="" pattern missing
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        log="$(log show --start "$start" --style compact --predicate "subsystem == \"$subsystem\"" 2>/dev/null || true)"
        missing=0
        for pattern in "$@"; do
            echo "$log" | grep -q -- "$pattern" || missing=1
        done
        [ "$missing" = 0 ] && break
        sleep 1
    done
    printf '%s\n' "$log"
}
