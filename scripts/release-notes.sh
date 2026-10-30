#!/usr/bin/env bash
# Prints a release's notes, for its page on GitHub: what Nullmere Online
# needs, how to install it, and what waits inside.
#
#   scripts/release-notes.sh <version> [signed]
#
# Without "signed" the notes say the app is ad-hoc signed and not
# notarized, and how to open it anyway (scripts/go-live-status.sh reads
# that to tell a notarized release from one that isn't).
set -euo pipefail
version="${1:?the version, such as v1.0.0}"
signed="${2:-}"
cat <<NOTES
Nullmere Online ${version}

**Installing.** Open the disk image and drag Nullmere Online into Applications. Open it, press Play, and enter the realm under a name of your choosing. There is no account to make: this Mac's keychain keeps a random key the realm knows you by.

**What it needs.** A Mac with Apple silicon, macOS 26 or later, and Apple Intelligence turned on with its model downloaded. The envoys and the chronicler speak through Apple's on-device model, on your Mac. Where something is missing, the app says what, and opens System Settings where that helps.

**The realm.** One persistent world on the dead lake, shared by every keeper, twelve seats around it. When every seat is held, newcomers wait at the door for one to fall free. Your orders take effect at once; when the watch turns, the stewards act and the lake yields.
NOTES
if [ -z "$signed" ]; then
    echo
    echo "**Ad-hoc signed and not notarized.** The first time, open Nullmere Online and macOS will refuse it; then, in System Settings > Privacy & Security, choose Open Anyway beside Nullmere Online and confirm. (macOS 15 and later no longer open it from a right-click.)"
fi
