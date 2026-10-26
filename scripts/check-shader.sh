#!/usr/bin/env bash
# Compiles the lake shader with Apple's offline Metal compiler, so shader
# errors surface without a GPU (for example on virtualised CI runners).
#
# Xcode 26 ships the Metal toolchain as a separate download, so this tries
# the selected Xcode first and then any other installed Xcode. If none has a
# usable compiler it prints a warning and exits successfully; the GPU test in
# LauncherKitTests covers the shader on Macs with Metal.
set -euo pipefail

cd "$(dirname "$0")/.."

SOURCE_FILE="Sources/LauncherKit/Backdrop/LakeShader.swift"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# The Metal source is the body of the raw string literal in LakeShader.swift.
awk '/static let source = #"""/ { inside = 1; next } /^ *"""#/ { inside = 0 } inside' "$SOURCE_FILE" > "$WORK/LakeShader.metal"
if [ ! -s "$WORK/LakeShader.metal" ]; then
    echo "error: could not extract the Metal source from $SOURCE_FILE" >&2
    exit 1
fi

candidates=("")
for app in /Applications/Xcode*.app; do
    [ -d "$app/Contents/Developer" ] && candidates+=("$app/Contents/Developer")
done

for developer_dir in "${candidates[@]}"; do
    label="${developer_dir:-$(xcode-select -p 2>/dev/null || echo "default toolchain")}"
    set +e
    if [ -n "$developer_dir" ]; then
        output="$(DEVELOPER_DIR="$developer_dir" xcrun -sdk macosx metal -c "$WORK/LakeShader.metal" -o "$WORK/LakeShader.air" 2>&1)"
    else
        output="$(xcrun -sdk macosx metal -c "$WORK/LakeShader.metal" -o "$WORK/LakeShader.air" 2>&1)"
    fi
    status=$?
    set -e
    if [ "$status" -eq 0 ]; then
        [ -n "$output" ] && echo "$output"
        echo "Lake shader compiled with $label."
        exit 0
    fi
    if echo "$output" | grep -qiE "missing Metal Toolchain|unable to find utility|cannot execute tool|xcrun: error"; then
        echo "No usable Metal compiler in $label."
        continue
    fi
    echo "$output" >&2
    echo "error: the lake shader failed to compile with $label" >&2
    exit 1
done

echo "::warning::No Metal compiler is installed; skipped offline shader compilation. Install it with: xcodebuild -downloadComponent MetalToolchain"
