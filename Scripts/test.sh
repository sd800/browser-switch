#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
export CLANG_MODULE_CACHE_PATH="$ROOT/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT/.build/ModuleCache"
cd "$ROOT"
swift test --scratch-path "${BROWSER_SWITCH_TEST_BUILD_DIR:-$ROOT/.build}" \
    --cache-path "$ROOT/.build/Cache" --config-path "$ROOT/.build/Configuration" \
    --security-path "$ROOT/.build/Security" "$@"
