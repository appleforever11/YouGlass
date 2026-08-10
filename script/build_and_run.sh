#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="YouGlass"
BUNDLE_ID="com.kevinhowe.YouGlass"
BUILD_CONFIGURATION="${YOUGLASS_BUILD_CONFIGURATION:-debug}"
SIGNING_IDENTITY="${YOUGLASS_SIGNING_IDENTITY:-}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
FRAMEWORKS="$CONTENTS/Frameworks"

if [[ -z "$SIGNING_IDENTITY" ]]; then
  SIGNING_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/^[[:space:]]*[0-9]+\)/ {print $2; exit}')"
fi
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

cd "$ROOT_DIR"
swift build --product "$APP_NAME" --configuration "$BUILD_CONFIGURATION"
BUILD_BINARY="$(swift build --show-bin-path --configuration "$BUILD_CONFIGURATION")/$APP_NAME"

SPARKLE_FRAMEWORK="${SPARKLE_FRAMEWORK_PATH:-$ROOT_DIR/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework}"
if [[ ! -d "$SPARKLE_FRAMEWORK" ]]; then
  SPARKLE_FRAMEWORK="$(find "$ROOT_DIR/.build/artifacts/sparkle" -type d -path '*/Sparkle.framework' -print -quit 2>/dev/null || true)"
fi
if [[ ! -d "$SPARKLE_FRAMEWORK" ]]; then
  echo "Sparkle.framework was not found. Run swift package resolve first." >&2
  exit 1
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources" "$FRAMEWORKS"
cp "$BUILD_BINARY" "$CONTENTS/MacOS/$APP_NAME"
cp "Sources/YouTubeMac/Info.plist" "$CONTENTS/Info.plist"
cp "Sources/YouTubeMac/Resources/YouGlassIcon.icns" "$CONTENTS/Resources/YouGlassIcon.icns"
ditto "$SPARKLE_FRAMEWORK" "$FRAMEWORKS/Sparkle.framework"
chmod +x "$CONTENTS/MacOS/$APP_NAME"
install_name_tool \
  -change "@rpath/Sparkle.framework/Versions/B/Sparkle" \
  "@loader_path/../Frameworks/Sparkle.framework/Versions/B/Sparkle" \
  "$CONTENTS/MacOS/$APP_NAME"

if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  codesign --force --deep --sign - "$FRAMEWORKS/Sparkle.framework"
  codesign --force --deep --sign - "$APP_BUNDLE"
else
  codesign --force --deep --options runtime --timestamp=none --sign "$SIGNING_IDENTITY" "$FRAMEWORKS/Sparkle.framework"
  codesign --force --deep --options runtime --timestamp=none --sign "$SIGNING_IDENTITY" "$APP_BUNDLE"
fi

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  build|--build)
    ;;
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$CONTENTS/MacOS/$APP_NAME"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null
    codesign --verify --deep --strict "$APP_BUNDLE"
    ;;
  *)
    echo "usage: $0 [build|run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
