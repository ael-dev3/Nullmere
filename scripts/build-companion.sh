#!/usr/bin/env bash
# Builds Nullmere Companion, the keeper's iPhone app, for the iOS Simulator
# with the Swift package (no Xcode project), and bundles it with its
# Info.plist: build/companion/Nullmere Companion.app, signed to run on this
# Mac's simulators. Its entitlements go in the binary, as Xcode puts them in
# a simulator build, so its keychain is its own there too.
#
#   scripts/build-companion.sh [--configuration debug|release]
#
# A build for a keeper's own iPhone is signed with an Apple developer team
# in Xcode: open Package.swift, choose the NullmereCompanion scheme and a
# device, and set the team; the app and its Info.plist are the same.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIGURATION=debug
while [ $# -gt 0 ]; do
    case "$1" in
        --configuration) CONFIGURATION="$2"; shift 2 ;;
        -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
        *) echo "error: unknown argument $1" >&2; exit 2 ;;
    esac
done

BUNDLE_ID=online.nullmere.companion
SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
SDK_VERSION="$(xcrun --sdk iphonesimulator --show-sdk-version)"
TRIPLE="$(uname -m)-apple-ios26.0-simulator"
SCRATCH=.build/companion-simulator
APP="build/companion/Nullmere Companion.app"
ENTITLEMENTS="build/companion/Companion.entitlements"
mkdir -p build/companion

cat > "$ENTITLEMENTS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>application-identifier</key>
    <string>NULLMERE.${BUNDLE_ID}</string>
    <key>keychain-access-groups</key>
    <array>
        <string>NULLMERE.${BUNDLE_ID}</string>
    </array>
</dict>
</plist>
PLIST

echo "Building Nullmere Companion ($CONFIGURATION) for the iOS $SDK_VERSION Simulator, ${TRIPLE}…"
build() {
    swift build -c "$CONFIGURATION" --product NullmereCompanion --triple "$TRIPLE" --sdk "$SDK" --scratch-path "$SCRATCH" \
        -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __entitlements -Xlinker "$PWD/$ENTITLEMENTS" "$@"
}
build
BIN="$(build --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP"
cp "$BIN/NullmereCompanion" "$APP/NullmereCompanion"
for bundle in "$BIN"/*.bundle; do
    [ -e "$bundle" ] && cp -R "$bundle" "$APP/"
done
VERSION="$(sed -n 's/^## \[\{0,1\}\([0-9][0-9.]*\).*/\1/p' CHANGELOG.md 2>/dev/null | head -n 1)"
VERSION="${VERSION:-0.4.0}"

cat > "$APP/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleDisplayName</key><string>Nullmere</string>
    <key>CFBundleExecutable</key><string>NullmereCompanion</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>Nullmere Companion</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleSupportedPlatforms</key><array><string>iPhoneSimulator</string></array>
    <key>DTPlatformName</key><string>iphonesimulator</string>
    <key>DTSDKName</key><string>iphonesimulator${SDK_VERSION}</string>
    <key>MinimumOSVersion</key><string>26.0</string>
    <key>LSRequiresIPhoneOS</key><true/>
    <key>UIDeviceFamily</key><array><integer>1</integer><integer>2</integer></array>
    <key>UILaunchScreen</key><dict/>
    <key>UIApplicationSceneManifest</key>
    <dict><key>UIApplicationSupportsMultipleScenes</key><false/></dict>
    <key>UISupportedInterfaceOrientations</key>
    <array><string>UIInterfaceOrientationPortrait</string><string>UIInterfaceOrientationLandscapeLeft</string><string>UIInterfaceOrientationLandscapeRight</string></array>
    <key>CFBundleURLTypes</key>
    <array><dict>
        <key>CFBundleURLName</key><string>${BUNDLE_ID}.link</string>
        <key>CFBundleURLSchemes</key><array><string>nullmere</string></array>
    </dict></array>
    <key>NSAppTransportSecurity</key>
    <dict><key>NSAllowsLocalNetworking</key><true/></dict>
</dict>
</plist>
PLIST
plutil -lint "$APP/Info.plist" >/dev/null
codesign --force --sign - --timestamp=none "$APP"
echo "Bundled $APP ($(du -sh "$APP" | cut -f1))."
