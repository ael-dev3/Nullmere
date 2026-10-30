#!/usr/bin/env bash
# Opens Nullmere Online through Xcode's UI testing, as VoiceOver and
# Accessibility Inspector meet it: every screen put to Xcode's
# accessibility audit, and the lake's map walked through the elements
# VoiceOver reads.
#
#   scripts/ui-test.sh
#
# Builds the debug app (only a debug build opens as if the on-device model
# were ready, with a realm of its own), registers it with Launch Services,
# and runs UITests/NullmereUITests.xcodeproj. The first run on a Mac asks
# to let Xcode's UI testing control it. Needs Xcode 26 and macOS 26.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build

CONFIGURATION=debug OUTPUT_DIR=build/ui scripts/build-app.sh
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -f "build/ui/Nullmere Online.app"

rm -rf build/ui.xcresult
set +e
xcodebuild test -project UITests/NullmereUITests.xcodeproj -scheme NullmereUITests \
    -destination 'platform=macOS,arch=arm64' -resultBundlePath build/ui.xcresult 2>&1 \
    | tee build/ui-test.log | grep -E "UIAUDIT|UIWALK|UIMAP|error:|Test Case .* (passed|failed)|\*\* TEST"
set -e
if ! grep -q "\*\* TEST SUCCEEDED \*\*" build/ui-test.log; then
    echo "error: the UI tests found something, or couldn't run; see build/ui-test.log and build/ui.xcresult" >&2
    exit 1
fi
echo "Every screen passed Xcode's accessibility audit, and the map was walked as VoiceOver walks it."
