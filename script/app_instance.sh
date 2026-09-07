#!/usr/bin/env bash
# Match a staged executable literally; app names and checkout paths can contain regex characters.
app_instance_pids() {
  local target="$1" canonical="$1" pid executable
  if [[ -d "$(dirname "$target")" ]]; then
    canonical="$(cd "$(dirname "$target")" && pwd -P)/$(basename "$target")"
  fi
  while read -r pid executable; do
    if [[ "${executable##*/}" == "${target##*/}" && -d "${executable%/*}" ]]; then
      executable="$(cd "${executable%/*}" && pwd -P)/${executable##*/}"
    fi
    if [[ "$executable" == "$target" || "$executable" == "$canonical" ]]; then
      printf '%s\n' "$pid"
    fi
  done < <(/bin/ps -axww -o pid=,comm=)
}

require_app_stopped() {
  local running
  running="$(app_instance_pids "$1")"
  if [[ -n "$running" ]]; then
    echo "The development app is running at $1. Finish its session and quit it before replacing this bundle." >&2
    return 1
  fi
}
