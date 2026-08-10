#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/YouGlass.app"
DMG_PATH="${1:-$DIST_DIR/YouGlass-Apple-Silicon.dmg}"
BUILD_CONFIGURATION="${YOUGLASS_BUILD_CONFIGURATION:-release}"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/youglass-dmg.XXXXXX")"

cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

YOUGLASS_BUILD_CONFIGURATION="$BUILD_CONFIGURATION" "$ROOT_DIR/script/build_and_run.sh" build

test -d "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"

ditto "$APP_BUNDLE" "$STAGING_DIR/YouGlass.app"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_PATH"
mkdir -p "$(dirname "$DMG_PATH")"
hdiutil create \
  -volname "YouGlass" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  "$DMG_PATH"

hdiutil verify "$DMG_PATH"
echo "$DMG_PATH"
