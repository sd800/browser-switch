#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${BROWSER_SWITCH_BUILD_DIR:-$ROOT/build}"
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

xcodebuild -project "$ROOT/BrowserSwitch.xcodeproj" \
    -scheme BrowserSwitch -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    -destination 'generic/platform=macOS' \
    ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
    MARKETING_VERSION="$(cat "$ROOT/VERSION")" \
    CURRENT_PROJECT_VERSION="$(cat "$ROOT/BUILD_NUMBER")" \
    CODE_SIGNING_ALLOWED=NO \
    SDK_STAT_CACHE_ENABLE=NO \
    CLANG_MODULE_CACHE_PATH="$BUILD_DIR/ModuleCache" \
    build

mkdir -p "$ROOT/dist"
APP="$ROOT/dist/Browser Switch.app"
rm -rf "$APP"
ditto "$BUILD_DIR/Build/Products/Release/Browser Switch.app" "$APP"
# File-provider metadata on a generated bundle can invalidate code signing.
xattr -cr "$APP"
codesign --force --sign "${SIGNING_IDENTITY:--}" --options runtime \
    --entitlements "$ROOT/Resources/BrowserSwitch.entitlements" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
ditto -c -k --keepParent "$APP" "$ROOT/dist/Browser-Switch-$(cat "$ROOT/VERSION").zip"
printf '\nBuilt: %s\n' "$APP"
