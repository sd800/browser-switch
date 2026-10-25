#!/bin/bash
set -euo pipefail
umask 077

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${BROWSER_SWITCH_BUILD_DIR:-$ROOT/build}"
VERSION="$(cat "$ROOT/VERSION")"
BUILD_NUMBER="$(cat "$ROOT/BUILD_NUMBER")"
if [[ ! "$VERSION" =~ ^[0-9]{2}\.[0-9]{3,4}\.[1-9][0-9]*$ || ! "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
    printf 'Invalid release metadata.\n' >&2
    exit 1
fi
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

xcodebuild -project "$ROOT/BrowserSwitch.xcodeproj" \
    -scheme BrowserSwitch -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    -destination 'generic/platform=macOS' \
    ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    CODE_SIGNING_ALLOWED=NO \
    SDK_STAT_CACHE_ENABLE=NO \
    CLANG_MODULE_CACHE_PATH="$BUILD_DIR/ModuleCache" \
    build

mkdir -p "$ROOT/dist"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/browser-switch-package.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
APP="$STAGING_DIR/Browser Switch.app"
# Sign outside file-provider folders, where Finder metadata can reappear during signing.
ditto --noextattr --norsrc "$BUILD_DIR/Build/Products/Release/Browser Switch.app" "$APP"
xattr -cr "$APP"
codesign --force --sign "${SIGNING_IDENTITY:--}" --options runtime \
    --entitlements "$ROOT/Resources/BrowserSwitch.entitlements" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
OUTPUT_APP="$ROOT/dist/Browser Switch.app"
rm -rf "$OUTPUT_APP"
ditto --noextattr --norsrc "$APP" "$OUTPUT_APP"
codesign --verify --deep --strict --verbose=2 "$OUTPUT_APP"
ARCHIVE="$ROOT/dist/Browser-Switch-$VERSION.zip"
ditto -c -k --norsrc --noextattr --keepParent "$APP" "$ARCHIVE"
ditto -x -k "$ARCHIVE" "$STAGING_DIR/verification"
codesign --verify --deep --strict --verbose=2 "$STAGING_DIR/verification/Browser Switch.app"
(cd "$ROOT/dist" && shasum -a 256 "Browser-Switch-$VERSION.zip" > SHA256SUMS.txt)
printf '\nBuilt: %s\n' "$OUTPUT_APP"
