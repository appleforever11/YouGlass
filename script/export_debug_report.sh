#!/usr/bin/env bash
set -euo pipefail

APP_NAME="YouGlass"
BUNDLE_ID="com.kevinhowe.YouGlass"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUTPUT_ROOT="${1:-$ROOT_DIR/dist/debug-export-$TIMESTAMP}"
DIAGNOSTICS_DIR="$HOME/Library/Application Support/YouGlass/Diagnostics"
CRASH_DIR="$HOME/Library/Logs/DiagnosticReports"

if [[ -e "$OUTPUT_ROOT" ]]; then
  echo "Output already exists: $OUTPUT_ROOT" >&2
  exit 2
fi

mkdir -p "$OUTPUT_ROOT/diagnostics" "$OUTPUT_ROOT/crash-reports"

if [[ -d "$DIAGNOSTICS_DIR" ]]; then
  find "$DIAGNOSTICS_DIR" -maxdepth 1 -type f \
    \( -name '*.json' -o -name '*.jsonl' \) \
    -exec cp {} "$OUTPUT_ROOT/diagnostics/" \;
fi

if [[ -d "$CRASH_DIR" ]]; then
  find "$CRASH_DIR" -maxdepth 1 -type f \
    \( -name "$APP_NAME-*.ips" -o -name "$APP_NAME-*.crash" \) \
    -exec cp {} "$OUTPUT_ROOT/crash-reports/" \;
fi

if ! /usr/bin/log show \
  --style compact \
  --last 24h \
  --predicate "process == \"$APP_NAME\" OR subsystem == \"$BUNDLE_ID\"" \
  > "$OUTPUT_ROOT/unified.log" 2>&1; then
  printf '%s\n' 'Unified log capture was unavailable in this environment.' > "$OUTPUT_ROOT/unified.log"
fi

{
  printf '%s\n' 'YouGlass debug export'
  printf 'Generated (UTC): %s\n' "$TIMESTAMP"
  printf 'Repository: %s\n' "$ROOT_DIR"
  printf 'App: %s\n' "$APP_NAME"
  printf 'Bundle ID: %s\n' "$BUNDLE_ID"
  printf 'Configuration: %s\n' "${YOUGLASS_BUILD_CONFIGURATION:-debug}"
  printf 'Diagnostics source: %s\n' "$DIAGNOSTICS_DIR"
  printf 'Crash report source: %s\n' "$CRASH_DIR"
  printf '%s\n' ''
  printf '%s\n' 'This export contains redacted YouGlass diagnostics and native crash reports.'
  printf '%s\n' 'It intentionally excludes credentials, cookies, tokens, and browser data.'
} > "$OUTPUT_ROOT/README.txt"

ARCHIVE_PATH="${OUTPUT_ROOT}.zip"
ditto -c -k --sequesterRsrc --keepParent "$OUTPUT_ROOT" "$ARCHIVE_PATH"

printf 'Debug export: %s\n' "$OUTPUT_ROOT"
printf 'Archive: %s\n' "$ARCHIVE_PATH"
