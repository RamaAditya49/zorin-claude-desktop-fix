#!/usr/bin/env bash
# Install the Claude Desktop multi-profile fix for GNOME Wayland into $HOME.
# Run it again at any time. The result stays the same.
set -euo pipefail

usage() {
  cat <<'USAGE'
usage: install.sh [--profiles N] [--autostart] [--no-activate] [-h|--help]

  --profiles N    Set up profiles 1 to N (1 to 9). Without it, keep the current list.
  --autostart     Start profiles 2 and up at login.
  --no-activate   Copy files only. Do not touch systemd, GNOME, or the claude:// handler.
USAGE
}

PROFILES=""
AUTOSTART=0
ACTIVATE=1
while [ $# -gt 0 ]; do
  case "$1" in
    --profiles)
      [ $# -ge 2 ] || { echo "error: --profiles needs a number" >&2; exit 2; }
      case "$2" in [1-9]) PROFILES=$2 ;; *) echo "error: --profiles must be 1 to 9" >&2; exit 2 ;; esac
      shift 2 ;;
    --autostart) AUTOSTART=1; shift ;;
    --no-activate) ACTIVATE=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DATA=${XDG_DATA_HOME:-$HOME/.local/share}
CONFIG=${XDG_CONFIG_HOME:-$HOME/.config}
BIN_DIR=$HOME/.local/bin
STATE=$DATA/claude-profiles
APP_DIR=$DATA/applications
TPL_DIR=$STATE/desktop
ICON_DIR=$DATA/icons/hicolor
AUTOSTART_DIR=$CONFIG/autostart
SYSTEMD_DIR=$CONFIG/systemd/user
CONF_DIR=$CONFIG/claude-profiles
CONF=$CONF_DIR/profiles.conf
MANIFEST=$STATE/manifest
EXT_ID=computer-use-linux@avifenesh.dev
EXT_DIR=$DATA/gnome-shell/extensions/$EXT_ID

warn() { echo "warning: $*" >&2; }

# 1. Preflight.
for tool in gcc python3 install awk; do
  command -v "$tool" >/dev/null 2>&1 || { echo "error: missing required tool: $tool" >&2; exit 1; }
done
for tool in gdbus notify-send xdg-mime update-desktop-database gtk-update-icon-cache gnome-extensions; do
  command -v "$tool" >/dev/null 2>&1 || warn "missing tool: $tool (some features will not work)"
done
if [ -n "$PROFILES" ] && [ "$PROFILES" -gt 1 ] 2>/dev/null; then
  command -v zenity >/dev/null 2>&1 || warn "missing tool: zenity (the link picker will not work)"
fi
[ "${XDG_SESSION_TYPE:-}" = wayland ] || warn "this session is not Wayland. The fix is made for GNOME on Wayland."
case "${XDG_CURRENT_DESKTOP:-}" in
  *GNOME*) ;;
  *) warn "this desktop is not GNOME. The window control needs GNOME Shell." ;;
esac

# 2. Find Claude Desktop.
BIN=${CLAUDE_DESKTOP_BIN:-}
if [ -z "$BIN" ]; then
  BIN=$(command -v claude-desktop 2>/dev/null || true)
  [ -n "$BIN" ] || BIN=/usr/bin/claude-desktop
fi
if [ ! -x "$BIN" ]; then
  echo "Claude Desktop is not installed. See the section \"Install Claude Desktop\" in README.md." >&2
  exit 1
fi
EXE=${CLAUDE_DESKTOP_EXE:-$(readlink -f "$BIN")}
if [ ! -e "$EXE" ]; then
  echo "error: the Claude Desktop program was not found at $EXE" >&2
  exit 1
fi

# 3. Find the package launcher.
PKG_DESKTOP=""
IFS=':' read -r -a dirs <<< "${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
for d in "${dirs[@]}"; do
  [ -n "$d" ] || continue
  if [ "${d%/}" = "${DATA%/}" ]; then continue; fi
  if [ -f "$d/applications/com.anthropic.Claude.desktop" ]; then
    PKG_DESKTOP=$d/applications/com.anthropic.Claude.desktop
    break
  fi
done
if [ -z "$PKG_DESKTOP" ]; then
  warn "the Claude Desktop launcher file was not found. Using the default location."
  PKG_DESKTOP=/usr/share/applications/com.anthropic.Claude.desktop
fi

# Helpers.
clean_name() { printf '%s' "$1" | tr -d '[:cntrl:]'; }

# Replace @KEY@ markers in a template. Usage: render TEMPLATE OUTPUT KEY=value...
render() {
  local tpl=$1 out=$2 content kv k v
  shift 2
  content=$(<"$tpl")
  for kv in "$@"; do
    k=${kv%%=*}; v=${kv#*=}
    content=${content//"@$k@"/"$v"}
  done
  mkdir -p "$(dirname "$out")"
  printf '%s\n' "$content" > "$out"
  chmod 644 "$out"
}

safe_path() {
  case "$1" in
    "$HOME"/*) ;;
    *) return 1 ;;
  esac
  case "$1" in
    *..*) return 1 ;;
  esac
  return 0
}

# 4. profiles.conf.
declare -A PNAME=()
if [ -f "$CONF" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line%$'\r'}
    case "$line" in ''|'#'*) continue ;; esac
    num=${line%% *}
    case "$num" in [1-9]) ;; *) continue ;; esac
    name=$(clean_name "${line#"$num"}"); name=${name# }
    PNAME[$num]=$name
  done < "$CONF"
fi
if [ -n "$PROFILES" ]; then
  new_conf=()
  for ((i = 1; i <= PROFILES; i++)); do
    if [ -n "${PNAME[$i]:-}" ]; then nm=${PNAME[$i]}
    elif [ "$i" = 1 ]; then nm=Claude
    else nm="Claude $i"; fi
    new_conf+=("$i $nm")
  done
elif [ -f "$CONF" ] && [ "${#PNAME[@]}" -gt 0 ]; then
  new_conf=()
  for i in 1 2 3 4 5 6 7 8 9; do
    if [ -n "${PNAME[$i]+x}" ]; then new_conf+=("$i ${PNAME[$i]:-Claude $i}"); fi
  done
else
  new_conf=("1 Claude")
fi
# Profile 1 must always exist.
case " ${new_conf[*]%% *} " in
  *" 1 "*) ;;
  *) new_conf=("1 Claude" "${new_conf[@]}") ;;
esac
for entry in "${new_conf[@]}"; do
  nm=${entry#* }
  if [ "${#nm}" -gt 60 ]; then
    echo "error: a profile name is longer than 60 characters: $nm" >&2
    exit 1
  fi
done
mkdir -p "$CONF_DIR"
{
  echo "# One profile on each line: <number 1-9> <display name>"
  echo "# Profile 1 is the normal Claude. Run install.sh again after you edit this file."
  printf '%s\n' "${new_conf[@]}"
} > "$CONF.new"
if ! cmp -s "$CONF.new" "$CONF" 2>/dev/null; then mv -f "$CONF.new" "$CONF"; else rm -f "$CONF.new"; fi

declare -A NAME=()
NUMS=()
for entry in "${new_conf[@]}"; do
  NAME[${entry%% *}]=${entry#* }
  NUMS+=("${entry%% *}")
done
EXTRA=()
for n in "${NUMS[@]}"; do
  if [ "$n" -ge 2 ]; then EXTRA+=("$n"); fi
done

# Read the old manifest (for clean-up of removed items and the extension flag).
OLD_FILES=()
OLD_EXT=0
if [ -f "$MANIFEST" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      extension=installed) OLD_EXT=1 ;;
      /*) OLD_FILES+=("$line") ;;
    esac
  done < "$MANIFEST"
fi

# Remove old icons first. The generator writes them again.
for f in "${OLD_FILES[@]+"${OLD_FILES[@]}"}"; do
  case "$f" in
    "$ICON_DIR"/*/apps/claude-profile-[0-9].png|"$ICON_DIR"/*/apps/claude-profile-[0-9].svg)
      if safe_path "$f" && [ -f "$f" ]; then rm -f "$f"; fi ;;
  esac
done

NEW_FILES=()
add() { NEW_FILES+=("$1"); }

# 5. Scripts and library.
for f in "$REPO"/bin/*; do
  install -D -m 755 "$f" "$BIN_DIR/$(basename "$f")"
  add "$BIN_DIR/$(basename "$f")"
done
install -D -m 644 "$REPO/lib/claude-app-id.c" "$STATE/claude-app-id.c"
add "$STATE/claude-app-id.c"
# Build to a temp name, then rename. Running Claude processes keep the old mapping.
gcc -O2 -Wall -Wextra -shared -fPIC -DCLAUDE_EXE="\"$EXE\"" \
  -o "$STATE/claude-app-id.so.new" "$STATE/claude-app-id.c" -ldl
mv -f "$STATE/claude-app-id.so.new" "$STATE/claude-app-id.so"
add "$STATE/claude-app-id.so"

# 6. Launchers for profiles 2 and up.
for n in "${EXTRA[@]+"${EXTRA[@]}"}"; do
  for dest in "$TPL_DIR" "$APP_DIR"; do
    render "$REPO/templates/claude-desktop-N.desktop.in" "$dest/claude-desktop-$n.desktop" \
      "N=$n" "NAME=${NAME[$n]}" "BIN_DIR=$BIN_DIR"
    add "$dest/claude-desktop-$n.desktop"
  done
done
# The guard writes its own copy of the Claude launcher here.
# Keep a launcher that the user made before the first install. The uninstaller puts it back.
SHADOW=$APP_DIR/com.anthropic.Claude.desktop
BACKUP=$STATE/backup/com.anthropic.Claude.desktop
was_ours=0
for f in "${OLD_FILES[@]+"${OLD_FILES[@]}"}"; do [ "$f" = "$SHADOW" ] && was_ours=1; done
if [ -f "$SHADOW" ] && [ "$was_ours" -eq 0 ] && [ ! -e "$BACKUP" ]; then
  install -D -m 644 "$SHADOW" "$BACKUP"
  echo "Saved your own Claude launcher to $BACKUP. The uninstaller puts it back."
fi
add "$SHADOW"

# 8. Icons.
if [ "${#EXTRA[@]}" -gt 0 ]; then
  python3 "$REPO/lib/make-icons.py" "$ICON_DIR" "${EXTRA[@]}"
  for n in "${EXTRA[@]}"; do
    while IFS= read -r f; do add "$f"; done < <(find "$ICON_DIR" -type f \( -name "claude-profile-$n.png" -o -name "claude-profile-$n.svg" \) | sort)
  done
fi

# 9. Autostart for profiles 2 and up.
if [ "$AUTOSTART" -eq 1 ]; then
  for n in "${EXTRA[@]+"${EXTRA[@]}"}"; do
    render "$REPO/templates/claude-profile-N-autostart.desktop.in" "$AUTOSTART_DIR/claude-profile-$n.desktop" \
      "N=$n" "NAME=${NAME[$n]}" "BIN_DIR=$BIN_DIR" "DELAY=$((15 * (n - 1)))"
    add "$AUTOSTART_DIR/claude-profile-$n.desktop"
  done
fi

# 10. systemd units.
render "$REPO/templates/claude-profiles-guard.path.in" "$SYSTEMD_DIR/claude-profiles-guard.path" \
  "DATA=$DATA" "CONFIG=$CONFIG" "PKG_DESKTOP=$PKG_DESKTOP"
render "$REPO/templates/claude-profiles-guard.service.in" "$SYSTEMD_DIR/claude-profiles-guard.service" \
  "BIN_DIR=$BIN_DIR"
install -D -m 644 "$REPO/templates/claude-profiles-guard.timer" "$SYSTEMD_DIR/claude-profiles-guard.timer"
add "$SYSTEMD_DIR/claude-profiles-guard.path"
add "$SYSTEMD_DIR/claude-profiles-guard.service"
add "$SYSTEMD_DIR/claude-profiles-guard.timer"

# 11. GNOME extension.
EXT_OURS=0
if [ ! -e "$EXT_DIR" ] || [ "$OLD_EXT" -eq 1 ]; then
  install -D -m 644 "$REPO/vendor/$EXT_ID/extension.js" "$EXT_DIR/extension.js"
  install -D -m 644 "$REPO/vendor/$EXT_ID/metadata.json" "$EXT_DIR/metadata.json"
  add "$EXT_DIR/extension.js"
  add "$EXT_DIR/metadata.json"
  EXT_OURS=1
else
  echo "The window-control extension is already installed. The installer leaves it as it is."
fi

# 7. Remove files of an older install that the new install no longer owns.
declare -A KEEP=()
for f in "${NEW_FILES[@]}"; do KEEP[$f]=1; done
for f in "${OLD_FILES[@]+"${OLD_FILES[@]}"}"; do
  [ -z "${KEEP[$f]+x}" ] || continue
  safe_path "$f" || continue
  if [ -f "$f" ]; then rm -f "$f"; fi
done

# 12. Manifest.
{
  printf '%s\n' "${NEW_FILES[@]}"
  if [ "$EXT_OURS" -eq 1 ]; then echo "extension=installed"; fi
} > "$MANIFEST.new"
mv -f "$MANIFEST.new" "$MANIFEST"

# 13. Activate.
if [ "$ACTIVATE" -eq 1 ]; then
  systemctl --user daemon-reload || warn "systemctl daemon-reload failed"
  systemctl --user enable --now claude-profiles-guard.path claude-profiles-guard.timer \
    || warn "could not enable the guard units"
  update-desktop-database "$APP_DIR" 2>/dev/null || warn "update-desktop-database failed"
  gtk-update-icon-cache -f -t "$ICON_DIR" 2>/dev/null || warn "gtk-update-icon-cache failed"
  if gnome-extensions enable "$EXT_ID" 2>/dev/null; then
    echo "The window-control extension is enabled."
  else
    # On Wayland, GNOME does not know a new extension before the next login.
    # Add it to the enabled list, so GNOME loads it at the next login.
    cur=$(gsettings get org.gnome.shell enabled-extensions 2>/dev/null || true)
    case "$cur" in
      "") warn "could not read the GNOME extension list. Enable $EXT_ID in the Extensions app." ;;
      *"'$EXT_ID'"*) ;;
      "@as []") gsettings set org.gnome.shell enabled-extensions "['$EXT_ID']" || true ;;
      *) gsettings set org.gnome.shell enabled-extensions "${cur%]}, '$EXT_ID']" || true ;;
    esac
    echo "The window-control extension will load at your next login."
  fi
  "$BIN_DIR/claude-profiles-guard" || true
else
  echo "Skipped activation (--no-activate)."
fi

# 14. Next steps.
echo
echo "Done. Profiles: ${#NUMS[@]} (list: $CONF)"
echo "Next steps:"
echo "  1. Log out and log in once (GNOME on Wayland loads a new extension at login)."
echo "  2. Open each profile from its icon in the dock or the app menu."
echo "  3. Sign in to each profile."
