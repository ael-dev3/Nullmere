#!/usr/bin/env bash
# Checks a Metal shader's syntax, names and types with clang, away from a
# Mac: the source's constructors (float4(…)) are rewritten as calls
# msl_shim.h declares and its unsuffixed literals marked float, as Metal
# takes them, then it is parsed as C++. A clean pass doesn't promise Metal
# will compile it; a failure here would fail there too.
#
#   Tools/msl-check/check.sh <shader.metal>
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
python3 -I - "$1" "$work/shader.cpp" <<'PY'
import re, sys
source = open(sys.argv[1]).read()
source = re.sub(r'#include <(metal_stdlib|simd/simd.h)>', '', source)
source = re.sub(r'\b(float|half|int|uint|short|ushort|char|uchar|bool)([234](?:x[234])?)\s*\(', r'make_\1\2(', source)
source = re.sub(r'(?<![\w.])(\d+\.\d*|\.\d+)([eE][-+]?\d+)?(?![\w.])', lambda m: m.group(0) + 'f', source)
open(sys.argv[2], 'w').write(source)
PY
clang++ -std=c++17 -fsyntax-only -Wno-unknown-attributes -Wno-unused-value -include "$here/msl_shim.h" \
    -ferror-limit=40 "$work/shader.cpp"
echo "msl-check: $(basename "$1") passed"
