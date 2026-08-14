#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REMOTE_TARGET="${YOUGLASS_REMOTE_TARGET:-}"
CONFIG_PATH="${YOUGLASS_DEPLOY_CONFIG:-$ROOT_DIR/.youglass-remote}"
SSH_KEY="${YOUGLASS_SSH_KEY:-$HOME/.ssh/youglass-neo}"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  echo "usage: remote_logs.sh [user@host]"
  exit 0
fi
if [[ $# -gt 1 ]]; then
  echo "Only one remote target may be provided." >&2
  echo "usage: remote_logs.sh [user@host]" >&2
  exit 2
fi
if [[ $# -eq 1 ]]; then
  REMOTE_TARGET="$1"
fi
if [[ -z "$REMOTE_TARGET" && -f "$CONFIG_PATH" ]]; then
  REMOTE_TARGET="$(awk 'NF && $1 !~ /^#/ { print $1; exit }' "$CONFIG_PATH")"
fi
if [[ -z "$REMOTE_TARGET" ]]; then
  echo "No remote target configured. Run configure_remote_deploy.sh first." >&2
  exit 2
fi
if [[ ! -f "$SSH_KEY" ]]; then
  echo "SSH key not found at $SSH_KEY." >&2
  exit 2
fi

exec ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 "$REMOTE_TARGET" \
  'log stream --style compact --info --predicate "process == \\"YouGlass\\" OR subsystem == \\"com.kevinhowe.YouGlass\\""'
