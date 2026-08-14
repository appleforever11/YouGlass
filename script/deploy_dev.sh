#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="YouGlass"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
BUILD_CONFIGURATION="${YOUGLASS_BUILD_CONFIGURATION:-release}"
SSH_KEY="${YOUGLASS_SSH_KEY:-$HOME/.ssh/youglass-neo}"
CONFIG_PATH="${YOUGLASS_DEPLOY_CONFIG:-$ROOT_DIR/.youglass-remote}"
REMOTE_TARGET="${YOUGLASS_REMOTE_TARGET:-}"
REMOTE_APP_DIR="${YOUGLASS_REMOTE_APP_DIR:-}"
SKIP_BUILD=0
NO_LAUNCH=0

usage() {
  cat <<'USAGE'
usage: deploy_dev.sh [user@host] [options]

Builds the current release configuration, copies it atomically to a separate
development app on the remote Mac, quits the previous dev copy, and relaunches
the new build. The GitHub/Sparkle release app is never touched.

Options:
  --configuration <debug|release>  Build configuration (default: release)
  --skip-build                     Deploy the existing dist/YouGlass.app
  --no-launch                      Copy the app without launching it remotely
  -h, --help                       Show this help

Environment overrides:
  YOUGLASS_REMOTE_TARGET           SSH target, for example kevin@MacBook-Neo.local
  YOUGLASS_SSH_KEY                 SSH identity file (default: ~/.ssh/youglass-neo)
  YOUGLASS_REMOTE_APP_DIR          Remote path (default: ~/Applications/YouGlass-Dev.app)
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --configuration)
      [[ $# -ge 2 ]] || { echo "--configuration requires debug or release" >&2; exit 2; }
      BUILD_CONFIGURATION="$2"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    --no-launch)
      NO_LAUNCH=1
      shift
      ;;
    --*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      if [[ -n "$REMOTE_TARGET" ]]; then
        echo "Remote target was provided more than once." >&2
        exit 2
      fi
      REMOTE_TARGET="$1"
      shift
      ;;
  esac
done

if [[ -z "$REMOTE_TARGET" && -f "$CONFIG_PATH" ]]; then
  REMOTE_TARGET="$(awk 'NF && $1 !~ /^#/ { print $1; exit }' "$CONFIG_PATH")"
fi

if [[ -z "$REMOTE_TARGET" ]]; then
  echo "No remote target configured." >&2
  echo "Run: ./script/configure_remote_deploy.sh user@MacBook-Neo.local" >&2
  echo "Or set YOUGLASS_REMOTE_TARGET=user@host for a one-off deploy." >&2
  exit 2
fi

if [[ "$BUILD_CONFIGURATION" != "debug" && "$BUILD_CONFIGURATION" != "release" ]]; then
  echo "Build configuration must be debug or release." >&2
  exit 2
fi

if [[ ! -f "$SSH_KEY" ]]; then
  echo "SSH key not found at $SSH_KEY." >&2
  echo "Run: ./script/configure_remote_deploy.sh $REMOTE_TARGET" >&2
  exit 2
fi

SSH_ARGS=(-i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 -o ServerAliveInterval=10 -o ServerAliveCountMax=2)
ssh_remote() {
  ssh "${SSH_ARGS[@]}" "$REMOTE_TARGET" "$@"
}

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  echo "Building YouGlass ($BUILD_CONFIGURATION)..."
  YOUGLASS_BUILD_CONFIGURATION="$BUILD_CONFIGURATION" "$ROOT_DIR/script/build_and_run.sh" build
fi

if [[ ! -d "$APP_BUNDLE" || ! -x "$APP_BUNDLE/Contents/MacOS/$APP_NAME" ]]; then
  echo "Built app bundle not found at $APP_BUNDLE." >&2
  exit 1
fi

echo "Checking SSH connection to $REMOTE_TARGET..."
REMOTE_HOME="$(ssh_remote 'printf %s "$HOME"')"
if [[ -z "$REMOTE_HOME" ]]; then
  echo "Could not determine the remote home directory." >&2
  exit 1
fi

if [[ -z "$REMOTE_APP_DIR" ]]; then
  REMOTE_APP_DIR="$REMOTE_HOME/Applications/YouGlass-Dev.app"
fi
if [[ "$REMOTE_APP_DIR" == *$'\n'* || "$REMOTE_APP_DIR" == *" "* ]]; then
  echo "YOUGLASS_REMOTE_APP_DIR must not contain spaces or newlines." >&2
  exit 2
fi

REMOTE_NEW_DIR="${REMOTE_APP_DIR}.new"

echo "Stopping the previous development copy on the remote Mac..."
ssh_remote /bin/sh -s -- "$REMOTE_APP_DIR" "$REMOTE_NEW_DIR" <<'REMOTE_PREPARE'
set -eu
app_dir=$1
new_dir=$2
mkdir -p "$(dirname "$app_dir")"
# The stable Sparkle install has the same executable name. Match the full
# development bundle path so an open release copy is never terminated.
dev_binary="$app_dir/Contents/MacOS/YouGlass"
pids=$(ps -axo pid=,command= | awk -v path="$dev_binary" 'index($0, path) { print $1 }' || true)
if [ -n "$pids" ]; then
  kill $pids >/dev/null 2>&1 || true
  sleep 0.4
fi
sleep 0.4
rm -rf "$new_dir"
REMOTE_PREPARE

echo "Copying the app bundle to $REMOTE_APP_DIR..."
RSYNC_SSH="ssh -i $(printf '%q' "$SSH_KEY") -o BatchMode=yes -o ConnectTimeout=8 -o ServerAliveInterval=10 -o ServerAliveCountMax=2"
rsync -a --delete --human-readable -e "$RSYNC_SSH" \
  "$APP_BUNDLE/" "$REMOTE_TARGET:$REMOTE_NEW_DIR/"

echo "Activating the new development build..."
ssh_remote /bin/sh -s -- "$REMOTE_APP_DIR" "$REMOTE_NEW_DIR" "$NO_LAUNCH" <<'REMOTE_ACTIVATE'
set -eu
app_dir=$1
new_dir=$2
no_launch=${3:-0}
rm -rf "$app_dir"
mv "$new_dir" "$app_dir"
if [ "$no_launch" -eq 0 ]; then
  open -n "$app_dir"
fi
REMOTE_ACTIVATE

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || printf 'unknown')"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || printf 'unknown')"
echo "Deployed YouGlass $VERSION ($BUILD) to $REMOTE_TARGET."
if [[ "$NO_LAUNCH" -eq 0 ]]; then
  echo "Running remotely from ~/Applications/YouGlass-Dev.app"
fi
