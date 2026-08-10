#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/YouGlass.app"
BUILD_CONFIGURATION="${YOUGLASS_BUILD_CONFIGURATION:-release}"
if [[ $# -ge 1 ]]; then
  VERSION="$1"
else
  VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/Sources/YouTubeMac/Info.plist")"
fi
ARCHIVE_PATH="${2:-$DIST_DIR/YouGlass-${VERSION}-arm64.zip}"

YOUGLASS_BUILD_CONFIGURATION="$BUILD_CONFIGURATION" "$ROOT_DIR/script/build_and_run.sh" build

test -d "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"
mkdir -p "$(dirname "$ARCHIVE_PATH")"
rm -f "$ARCHIVE_PATH"
ditto -c -k --keepParent "$APP_BUNDLE" "$ARCHIVE_PATH"

echo "$ARCHIVE_PATH"
