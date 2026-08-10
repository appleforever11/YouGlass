#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_CONFIGURATION="${YOUGLASS_BUILD_CONFIGURATION:-debug}"
FRAMEWORK_ROOT="$ROOT_DIR/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64"
FRAMEWORK_SOURCE="$FRAMEWORK_ROOT/Sparkle.framework"

cd "$ROOT_DIR"
swift package resolve
swift build --build-tests --configuration "$BUILD_CONFIGURATION"
PRODUCTS_DIR="$(swift build --show-bin-path --configuration "$BUILD_CONFIGURATION")"
FRAMEWORK_DEST="$PRODUCTS_DIR/PackageFrameworks/Sparkle.framework"

if [[ ! -d "$FRAMEWORK_SOURCE" ]]; then
  FRAMEWORK_SOURCE="$(find "$ROOT_DIR/.build/artifacts/sparkle" -type d -path '*/Sparkle.framework' -print -quit 2>/dev/null || true)"
fi
if [[ ! -d "$FRAMEWORK_SOURCE" ]]; then
  echo "Sparkle.framework was not found after dependency resolution." >&2
  exit 1
fi

# SwiftPM's test bundle links Sparkle with an @rpath that points at PackageFrameworks,
# but does not stage binary-target frameworks there automatically.
mkdir -p "$(dirname "$FRAMEWORK_DEST")"
ditto "$FRAMEWORK_SOURCE" "$FRAMEWORK_DEST"

swift test --skip-build "$@"
