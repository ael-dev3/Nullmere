#!/usr/bin/env bash
# Sourced by the smoke tests that host a realm on this Mac: the realm and
# keeper's name already here are set aside for the test, and put back
# however it ends, a crash included.
#
#   . scripts/smoke-realm.sh
#   set_aside_realm "$EXECUTABLE" build/smoke-identity

REALM_FILE="$HOME/Library/Application Support/Nullmere Online/hosted-realm.json"
REALM_BACKUP="$REALM_FILE.smoke-backup"

set_aside_realm() {
    SMOKE_EXECUTABLE="$1"
    SMOKE_IDENTITY="$2"
    if [ -e "$REALM_BACKUP" ]; then
        echo "error: $REALM_BACKUP is left from a smoke test that didn't finish." >&2
        echo "It is the realm this Mac hosted: put it back with" >&2
        echo "  mv \"$REALM_BACKUP\" \"$REALM_FILE\"" >&2
        exit 1
    fi
    SMOKE_SAVED_NAME="$(defaults read "$SMOKE_EXECUTABLE" keeper.name.hosted 2>/dev/null || true)"
    trap put_back_realm EXIT
    if [ -f "$REALM_FILE" ]; then mv "$REALM_FILE" "$REALM_BACKUP"; fi
    defaults delete "$SMOKE_EXECUTABLE" keeper.name.hosted >/dev/null 2>&1 || true
    rm -f "$SMOKE_IDENTITY"
}

put_back_realm() {
    rm -f "$REALM_FILE" "$SMOKE_IDENTITY"
    if [ -f "$REALM_BACKUP" ]; then mv "$REALM_BACKUP" "$REALM_FILE"; fi
    defaults delete "$SMOKE_EXECUTABLE" keeper.name.hosted >/dev/null 2>&1 || true
    if [ -n "$SMOKE_SAVED_NAME" ]; then defaults write "$SMOKE_EXECUTABLE" keeper.name.hosted -string "$SMOKE_SAVED_NAME"; fi
}
