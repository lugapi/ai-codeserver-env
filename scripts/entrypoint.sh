#!/usr/bin/env bash
set -euo pipefail

# Docker named volumes are often created as root. The entrypoint starts as root,
# fixes ownership on mounted paths, then re-execs itself as the coder user.
if [[ "$(id -u)" -eq 0 ]] && [[ "${CODER_ENTRYPOINT_DROPPED:-}" != "1" ]]; then
  echo "Fixing volume permissions for coder user (UID 1000)..."
  mkdir -p \
    /home/coder/.local/share/code-server \
    /home/coder/.config/code-server \
    /home/coder/workspace \
    /home/coder/.ssh
  chown -R coder:coder \
    /home/coder/.local \
    /home/coder/.config \
    /home/coder/workspace \
    /home/coder/.ssh
  exec gosu coder env CODER_ENTRYPOINT_DROPPED=1 "$0" "$@"
fi

EXTENSIONS_FILE="/etc/codeserver/extensions.txt"
SETTINGS_SOURCE="/etc/codeserver/settings.json"
SETTINGS_DIR="/home/coder/.local/share/code-server/User"
MARKER="/home/coder/.local/share/code-server/.extensions-installed"
WORKSPACE="/home/coder/workspace"

mkdir -p "$SETTINGS_DIR" "$WORKSPACE"

if [ ! -f "$SETTINGS_DIR/settings.json" ]; then
  cp "$SETTINGS_SOURCE" "$SETTINGS_DIR/settings.json"
fi

install_extensions() {
  while IFS= read -r ext || [ -n "$ext" ]; do
    ext="${ext%%#*}"
    ext="$(echo "$ext" | xargs)"
    [ -z "$ext" ] && continue
    echo "Installing extension: $ext"
    code-server --install-extension "$ext" --force
  done < "$EXTENSIONS_FILE"
}

if [ "${OPTIONAL_EXTENSION_UPDATE:-false}" = "true" ] || [ ! -f "$MARKER" ]; then
  install_extensions
  touch "$MARKER"
fi

exec code-server --bind-addr 0.0.0.0:8080 "$WORKSPACE"
