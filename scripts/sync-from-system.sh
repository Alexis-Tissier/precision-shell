#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p \
  "$REPO_ROOT/system-config/quickshell/precision-shell" \
  "$REPO_ROOT/system-config/niri" \
  "$REPO_ROOT/system-config/bin" \
  "$REPO_ROOT/system-config/applications" \
  "$REPO_ROOT/system-config/gtklock/precision"

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
  --exclude='.horizon-launcher-final-backup-*/' \
  --exclude='.horizon-launch-backup-*/' \
  --exclude='.horizon-backup-*/' \
  --exclude='.horizon-fix-backup-*/' \
  "$HOME/.config/quickshell/precision-shell/" \
  "$REPO_ROOT/system-config/quickshell/precision-shell/"

for file in config.kdl precision-style.kdl; do
    if [[ -f "$HOME/.config/niri/$file" ]]; then
        cp "$HOME/.config/niri/$file" \
           "$REPO_ROOT/system-config/niri/$file"
    fi
done

find "$REPO_ROOT/system-config/bin" \
  -mindepth 1 -maxdepth 1 -type f -delete

if [[ -d "$HOME/.local/bin" ]]; then
    find "$HOME/.local/bin" \
      -maxdepth 1 \
      -type f \
      -name 'precision-*' \
      -exec cp {} "$REPO_ROOT/system-config/bin/" \;
fi

find "$REPO_ROOT/system-config/applications" \
  -mindepth 1 -maxdepth 1 -type f -delete

if [[ -d "$HOME/.local/share/applications" ]]; then
    find "$HOME/.local/share/applications" \
      -maxdepth 1 \
      -type f \
      \( -iname 'precision*.desktop' \
         -o -iname 'darktable-ai.desktop' \
         -o -iname 'horizon.desktop' \) \
      -exec cp {} "$REPO_ROOT/system-config/applications/" \;
fi

if [[ -d "$HOME/.config/gtklock/precision" ]]; then
    rsync -a --delete \
      --exclude='wallpaper.jpg' \
      --exclude='wallpaper.png' \
      "$HOME/.config/gtklock/precision/" \
      "$REPO_ROOT/system-config/gtklock/precision/"
fi

echo "Anonymisation de la copie GitHub..."
python3 "$REPO_ROOT/scripts/sanitize-repo.py"

echo "Configuration active synchronisée dans le dépôt."
