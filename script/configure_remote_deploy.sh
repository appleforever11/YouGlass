#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-}"
KEY_PATH="${YOUGLASS_SSH_KEY:-$HOME/.ssh/youglass-neo}"
CONFIG_PATH="${YOUGLASS_DEPLOY_CONFIG:-$ROOT_DIR/.youglass-remote}"

usage() {
  cat <<'USAGE'
usage: configure_remote_deploy.sh <user@host>

Creates a passwordless development SSH key, installs the public key on the
remote Mac, and remembers the target for script/deploy_dev.sh.

The first run requires the remote Mac's account password. Remote Login must
be enabled in System Settings > General > Sharing on that Mac.
USAGE
}

if [[ $# -gt 1 ]]; then
  echo "Only one remote target may be provided." >&2
  usage >&2
  exit 2
fi

if [[ -z "$TARGET" || "$TARGET" == "-h" || "$TARGET" == "--help" ]]; then
  usage
  [[ "$TARGET" == "-h" || "$TARGET" == "--help" ]] && exit 0
  exit 2
fi

if [[ "$TARGET" == -* ]]; then
  echo "Remote target must look like user@host, not $TARGET." >&2
  usage >&2
  exit 2
fi

mkdir -p "$(dirname "$KEY_PATH")"
chmod 700 "$(dirname "$KEY_PATH")"

if [[ ! -f "$KEY_PATH" ]]; then
  echo "Creating $KEY_PATH"
  ssh-keygen -q -t ed25519 -N "" -f "$KEY_PATH" -C "youglass-dev-deploy"
fi

echo "Installing the deployment key on $TARGET (this is the only password prompt)."
cat "${KEY_PATH}.pub" | ssh -o ConnectTimeout=10 "$TARGET" \
  'umask 077; mkdir -p ~/.ssh; touch ~/.ssh/authorized_keys; key=$(cat); grep -qxF "$key" ~/.ssh/authorized_keys || printf "%s\\n" "$key" >> ~/.ssh/authorized_keys'

printf '%s\n' "$TARGET" > "$CONFIG_PATH"
chmod 600 "$CONFIG_PATH"

echo
echo "Remote deployment is configured. Future updates use:"
echo "  ./script/deploy_dev.sh"
echo
echo "Development app path on the remote Mac: ~/Applications/YouGlass-Dev.app"
