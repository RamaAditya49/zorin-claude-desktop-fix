#!/usr/bin/env bash
# Remove everything that install.sh installed. Profile data folders stay.
set -euo pipefail

ACTIVATE=1
case "${1:-}" in
  "") ;;
  --no-activate) ACTIVATE=0 ;;
  -h|--help) echo "usage: uninstall.sh [--no-activate]"; exit 0 ;;
  *) echo "error: unknown option: $1" >&2; exit 2 ;;
esac

DATA=${XDG_DATA_HOME:-$HOME/.local/share}
CONFIG=${XDG_CONFIG_HOME:-$HOME/.config}
STATE=$DATA/claude-profiles
MANIFEST=$STATE/manifest
EXT_ID=computer-use-linux@avifenesh.dev
EXT_DIR=$DATA/gnome-shell/extensions/$EXT_ID

warn() { echo "warning: $*" >&2; }

if [ ! -f "$MANIFEST" ]; then
  echo "Nothing to remove: no install record was found."
  exit 0
fi

FILES=()
EXT_OURS=0
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    extension=installed) EXT_OURS=1 ;;
    /*) FILES+=("$line") ;;
  esac
done < "$MANIFEST"

if [ "$ACTIVATE" -eq 1 ]; then
  systemctl --user disable --now claude-profiles-guard.path claude-profiles-guard.timer 2>/dev/null \
    || warn "could not disable the guard units"
  if [ "$EXT_OURS" -eq 1 ]; then gnome-extensions disable "$EXT_ID" 2>/dev/null || true; fi
fi

for f in "${FILES[@]+"${FILES[@]}"}"; do
  case "$f" in
    "$HOME"/*) ;;
    *) warn "skipped a path outside your home folder: $f"; continue ;;
  esac
  case "$f" in
    *..*) warn "skipped a suspicious path: $f"; continue ;;
  esac
  if [ -f "$f" ] || [ -L "$f" ]; then rm -f "$f"; fi
done

# Put back the Claude launcher that the user had before the install.
BACKUP=$STATE/backup/com.anthropic.Claude.desktop
if [ -f "$BACKUP" ]; then
  mkdir -p "$DATA/applications"
  mv -f "$BACKUP" "$DATA/applications/com.anthropic.Claude.desktop"
  echo "Restored your own Claude launcher."
fi

# Remove empty folders that the install made.
dirs=("$EXT_DIR" "$STATE/desktop" "$STATE/backup" "$STATE" "${XDG_CACHE_HOME:-$HOME/.cache}/claude-profiles")
for d in "${dirs[@]}"; do
  rmdir "$d" 2>/dev/null || true
done
rm -f "$MANIFEST"
rmdir "$STATE/desktop" "$STATE" 2>/dev/null || true

if [ "$ACTIVATE" -eq 1 ]; then
  systemctl --user daemon-reload 2>/dev/null || true
  update-desktop-database "$DATA/applications" 2>/dev/null || true
  if command -v xdg-mime >/dev/null 2>&1; then
    xdg-mime default com.anthropic.Claude.desktop x-scheme-handler/claude || true
  fi
fi

echo "Removed. Your profile data folders (Claude, Claude-2, ...) are kept."
echo "The profile list is kept at: $CONFIG/claude-profiles/profiles.conf"
