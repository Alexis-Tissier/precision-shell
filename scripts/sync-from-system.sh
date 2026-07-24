#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p \
  "$REPO_ROOT/system-config/quickshell/precision-shell" \
  "$REPO_ROOT/system-config/niri"

rsync -a --delete \
  --exclude='*.log' \
  --exclude='*.backup-*' \
  --exclude='*.bak-*' \
  --exclude='__pycache__/' \
  --exclude='preferences.json' \
  --exclude='weather-cache.json' \
  --exclude='wifi-cache.json' \
  --exclude='wallpaper.jpg' \
  --exclude='wallpaper.png' \
  "$HOME/.config/quickshell/precision-shell/" \
  "$REPO_ROOT/system-config/quickshell/precision-shell/"

for file in config.kdl precision-style.kdl; do
    if [ -f "$HOME/.config/niri/$file" ]; then
        cp "$HOME/.config/niri/$file" \
           "$REPO_ROOT/system-config/niri/$file"
    fi
done

echo "Configuration active synchronisée dans le dépôt."

echo "Anonymisation de la copie destinée à GitHub..."
python3 "$REPO_ROOT/scripts/sanitize-repo.py"
