#!/usr/bin/env bash
# Compiles the game's two shaders, the launcher's lake and the world map,
# with Apple's offline Metal compiler, so shader errors surface without a
# GPU (for example on virtualised CI runners).
#
# Xcode 26 ships the Metal toolchain as a separate download, so this tries
# the selected Xcode first and then any other installed Xcode. If none has a
# usable compiler it prints a warning and exits successfully; the GPU tests
# in LauncherKitTests and NullmereKitTests cover the shaders on Macs with
# Metal.
set -euo pipefail

cd "$(dirname "$0")/.."

SOURCES=(
    "Sources/LauncherKit/Backdrop/LakeShader.swift"
    "Sources/NullmereKit/World/WorldShader.swift"
)
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Each Metal source is the body of the raw string literal in its Swift file.
for source_file in "${SOURCES[@]}"; do
    name="$(basename "$source_file" .swift)"
    awk '/static let source = #"""/ { inside = 1; next } /^ *"""#/ { inside = 0 } inside' "$source_file" > "$WORK/$name.metal"
    if [ ! -s "$WORK/$name.metal" ]; then
        echo "error: could not extract the Metal source from $source_file" >&2
        exit 1
    fi
done

candidates=("")
for app in /Applications/Xcode*.app; do
    [ -d "$app/Contents/Developer" ] && candidates+=("$app/Contents/Developer")
done

compile() {
    local developer_dir="$1" name="$2"
    if [ -n "$developer_dir" ]; then
        DEVELOPER_DIR="$developer_dir" xcrun -sdk macosx metal -c "$WORK/$name.metal" -o "$WORK/$name.air" 2>&1
    else
        xcrun -sdk macosx metal -c "$WORK/$name.metal" -o "$WORK/$name.air" 2>&1
    fi
}

for developer_dir in "${candidates[@]}"; do
    label="${developer_dir:-$(xcode-select -p 2>/dev/null || echo "default toolchain")}"
    usable=true
    for source_file in "${SOURCES[@]}"; do
        name="$(basename "$source_file" .swift)"
        set +e
        output="$(compile "$developer_dir" "$name")"
        status=$?
        set -e
        if [ "$status" -eq 0 ]; then
            [ -n "$output" ] && echo "$output"
            echo "$name compiled with $label."
            continue
        fi
        if echo "$output" | grep -qiE "missing Metal Toolchain|unable to find utility|cannot execute tool|xcrun: error"; then
            echo "No usable Metal compiler in $label."
            usable=false
            break
        fi
        echo "$output" >&2
        echo "error: $name failed to compile with $label" >&2
        exit 1
    done
    if $usable; then
        exit 0
    fi
done

echo "::warning::No Metal compiler is installed; skipped offline shader compilation. Install it with: xcodebuild -downloadComponent MetalToolchain"
