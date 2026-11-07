#!/usr/bin/env bash
# Builds Nullmere Companion, the keeper's iPhone app, for the iOS Simulator
# with the Swift package (no Xcode project), and bundles it with its
# Info.plist: build/companion/Nullmere Companion.app, signed to run on this
# Mac's simulators. Its entitlements go in the binary, as Xcode puts them in
# a simulator build, so its keychain is its own there too.
#
#   scripts/build-companion.sh [--configuration debug|release]
#   VERSION=0.3.0 scripts/build-companion.sh   # the marketing version, as the Mac app's
#
# A build for a keeper's own iPhone is signed with an Apple developer team
# in Xcode: open Package.swift, choose the NullmereCompanion scheme and a
# device, and set the team; the app and its Info.plist are the same.
set -Eeuo pipefail
# A step that stops the script says where, so no failure is a silent one.
trap 'echo "error: build-companion.sh stopped at line $LINENO: $BASH_COMMAND" >&2' ERR
cd "$(dirname "$0")/.."

CONFIGURATION=debug
while [ $# -gt 0 ]; do
    case "$1" in
        --configuration) CONFIGURATION="$2"; shift 2 ;;
        -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
        *) echo "error: unknown argument $1" >&2; exit 2 ;;
    esac
done

BUNDLE_ID=online.nullmere.companion
if ! SDK="$(xcrun --sdk iphonesimulator --show-sdk-path 2>/dev/null)"; then
    echo "error: this Xcode has no iOS Simulator SDK: add the iOS platform in Xcode's Settings, Components (or: xcodebuild -downloadPlatform iOS)" >&2
    exit 1
fi
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
# The marketing version, as scripts/build-app.sh gives the Mac app: three
# numbers, as iOS compares them.
VERSION="${VERSION:-0.3.0}"
echo "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || { echo "error: VERSION must be three numbers, such as 1.0.0 (not $VERSION)" >&2; exit 1; }

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

# The icon: the Liquid Glass document the Mac app's is made from, compiled
# by actool for the phone into an asset catalog, its keys added to the
# Info.plist. Without actool the phone shows the system's blank icon.
ICON_DIR=build/companion/icon
rm -rf "$ICON_DIR"
mkdir -p "$ICON_DIR"
if xcrun --find actool >/dev/null 2>&1 && xcrun actool Packaging/AppIcon.icon \
        --compile "$ICON_DIR" --platform iphonesimulator --minimum-deployment-target 26.0 \
        --target-device iphone --target-device ipad --app-icon AppIcon \
        --output-partial-info-plist "$ICON_DIR/icon-info.plist" \
        --errors --warnings --output-format human-readable-text >"$ICON_DIR/actool.log" 2>&1 \
        && [ -s "$ICON_DIR/Assets.car" ]; then
    cp "$ICON_DIR"/Assets.car "$APP/"
    for png in "$ICON_DIR"/*.png; do
        [ -e "$png" ] && cp "$png" "$APP/"
    done
    /usr/libexec/PlistBuddy -c "Merge $ICON_DIR/icon-info.plist" "$APP/Info.plist" >/dev/null
    echo "Compiled the Liquid Glass icon for the phone."
else
    echo "warning: could not compile Packaging/AppIcon.icon for the phone; it shows the system's blank icon" >&2
    cat "$ICON_DIR/actool.log" >&2 2>/dev/null || true
fi
plutil -lint "$APP/Info.plist" >/dev/null
codesign --force --sign - --timestamp=none "$APP"
echo "Bundled $APP ($(du -sh "$APP" | cut -f1))."
