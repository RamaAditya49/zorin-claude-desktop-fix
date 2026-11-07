#!/usr/bin/env bash
# Static checks and sandbox tests. This script never touches the real HOME.
# Run it from any folder: bash tests/run.sh
set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
FAILS=0

pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; FAILS=$((FAILS + 1)); }
# check NAME CMD...: run CMD and report PASS or FAIL by its exit code.
check() {
  local name=$1; shift
  if "$@" >"$tmp/check.out" 2>&1; then pass "$name"; else fail "$name"; sed 's/^/    /' "$tmp/check.out" | head -20; fi
}
# expect NAME EXPECTED ACTUAL
expect() {
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1"; echo "    expected: $2"; echo "    actual:   $3"; fi
}

SCRIPTS=("$REPO"/bin/claude-profile "$REPO"/bin/claude-url-router "$REPO"/bin/claude-profiles-guard "$REPO/install.sh" "$REPO/uninstall.sh" "$REPO/tests/run.sh")
PYFILES=("$REPO/bin/claude-profile-raise" "$REPO/lib/make-icons.py")

# ---- Static checks ----
for s in "${SCRIPTS[@]}"; do check "bash-syntax $(basename "$s")" bash -n "$s"; done
export PYTHONPYCACHEPREFIX="$tmp/pyc"
for p in "${PYFILES[@]}"; do check "py-compile $(basename "$p")" python3 -m py_compile "$p"; done
if command -v shellcheck >/dev/null 2>&1; then
  check shellcheck shellcheck -S warning "${SCRIPTS[@]}"
else
  echo "SKIP shellcheck (not installed)"
fi
check gcc-strict gcc -O2 -Wall -Wextra -Werror -shared -fPIC -DCLAUDE_EXE='"/usr/lib/claude-desktop/claude-desktop"' -o "$tmp/x.so" "$REPO/lib/claude-app-id.c" -ldl

# ---- Sandbox ----
export HOME="$tmp/home"
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME LD_PRELOAD CLAUDE_APP_ID CLAUDE_PLAIN_LAUNCH \
  CLAUDE_DESKTOP_EXE CLAUDE_ICON_SOURCE CLAUDE_ROUTER_PICK
export XDG_DATA_DIRS="$tmp/share"
mkdir -p "$HOME" "$tmp/stubs" "$tmp/share/applications"
export PATH="$tmp/stubs:$PATH"

for c in systemctl gsettings gnome-extensions flatpak notify-send zenity update-desktop-database gtk-update-icon-cache; do
  printf '#!/bin/sh\necho "%s $*" >> "%s/calls.log"\n' "$c" "$tmp" > "$tmp/stubs/$c"
  chmod +x "$tmp/stubs/$c"
done
printf '#!/bin/sh\necho "xdg-mime $*" >> "%s/calls.log"\n[ "$1" = query ] && echo com.anthropic.Claude.desktop\nexit 0\n' "$tmp" > "$tmp/stubs/xdg-mime"
chmod +x "$tmp/stubs/xdg-mime"
printf '#!/bin/sh\nexit 0\n' > "$tmp/stubs/claude-real"; chmod +x "$tmp/stubs/claude-real"
ln -s "$tmp/stubs/claude-real" "$tmp/stubs/claude-desktop"
export CLAUDE_DESKTOP_BIN="$tmp/stubs/claude-desktop"

# A tiny RGBA PNG that uses all five filter types, and a fake package launcher.
python3 - "$tmp" <<'PY'
import struct, sys, zlib
tmp = sys.argv[1]
w = h = 48
rows = [bytes(((x * 5 + y * 3) % 256 if c < 3 else 255) if (x + y) % 7 else 0 for x in range(w) for c in range(4)) for y in range(h)]
def filt(ft, row, prev, bpp=4):
    out = bytearray()
    for i, v in enumerate(row):
        a = row[i - bpp] if i >= bpp else 0
        b = prev[i]
        c = prev[i - bpp] if i >= bpp else 0
        if ft == 0: p = 0
        elif ft == 1: p = a
        elif ft == 2: p = b
        elif ft == 3: p = (a + b) >> 1
        else:
            q = a + b - c
            pa, pb, pc = abs(q - a), abs(q - b), abs(q - c)
            p = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
        out.append((v - p) & 255)
    return bytes([ft]) + bytes(out)
raw, prev = b"", bytes(w * 4)
for y, r in enumerate(rows):
    raw += filt(y % 5, r, prev); prev = r
def chunk(k, b): return struct.pack(">I", len(b)) + k + b + struct.pack(">I", zlib.crc32(k + b) & 0xFFFFFFFF)
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")
open(tmp + "/test.png", "wb").write(png)
open(tmp + "/test.rows", "wb").write(b"".join(rows))
PY
mkdir -p "$tmp/share/icons/hicolor/48x48/apps"
cp "$tmp/test.png" "$tmp/share/icons/hicolor/48x48/apps/claude-desktop.png"
cat > "$tmp/share/applications/com.anthropic.Claude.desktop" <<'DESK'
[Desktop Entry]
Name=Claude
Exec=claude-desktop %U
Icon=claude-desktop
Type=Application
StartupWMClass=com.anthropic.Claude
MimeType=x-scheme-handler/claude;

[Desktop Action NewChat]
Name=New chat
Exec=claude-desktop --new-chat
DESK

CONFIG=$HOME/.config; DATA=$HOME/.local/share; CACHE=$HOME/.cache; BIN=$HOME/.local/bin
mkdir -p "$CONFIG/Claude-2"; echo keep > "$CONFIG/Claude-2/keep.txt"

# ---- Install ----
check install-1 "$REPO/install.sh" --profiles 3 --autostart --no-activate
files_exist() { local f; for f in "$@"; do [ -e "$f" ] || { echo "missing: $f"; return 1; }; done; }
check install-files files_exist \
  "$BIN/claude-profile" "$BIN/claude-profile-raise" "$BIN/claude-url-router" "$BIN/claude-profiles-guard" \
  "$DATA/claude-profiles/claude-app-id.so" \
  "$DATA/applications/claude-desktop-2.desktop" "$DATA/applications/claude-desktop-3.desktop" \
  "$DATA/claude-profiles/desktop/claude-desktop-2.desktop" "$DATA/claude-profiles/desktop/claude-desktop-3.desktop" \
  "$CONFIG/autostart/claude-profile-2.desktop" "$CONFIG/autostart/claude-profile-3.desktop" \
  "$CONFIG/systemd/user/claude-profiles-guard.path" "$CONFIG/systemd/user/claude-profiles-guard.service" \
  "$CONFIG/systemd/user/claude-profiles-guard.timer" \
  "$DATA/gnome-shell/extensions/computer-use-linux@avifenesh.dev/extension.js" \
  "$DATA/gnome-shell/extensions/computer-use-linux@avifenesh.dev/metadata.json" \
  "$CONFIG/claude-profiles/profiles.conf" "$DATA/claude-profiles/manifest"
expect conf-3-profiles 3 "$(grep -cE '^[1-9] ' "$CONFIG/claude-profiles/profiles.conf")"
icons_for() { find "$DATA/icons/hicolor" -name "claude-profile-$1.*" | grep -q .; }
check icons-2 icons_for 2
check icons-3 icons_for 3
check icons-png-made bash -c "find '$DATA/icons/hicolor' -name 'claude-profile-2.png' | grep -q ."
no_markers() { ! grep -rIE '@[A-Z_]+@' "$DATA/claude-profiles" "$DATA/applications" "$CONFIG/autostart" "$CONFIG/systemd" "$CONFIG/claude-profiles" "$BIN"; }
check no-unresolved-markers no_markers
check exec-line-3 grep -qx "Exec=$BIN/claude-profile 3 %U" "$DATA/applications/claude-desktop-3.desktop"
check autostart-delay grep -qx "X-GNOME-Autostart-Delay=30" "$CONFIG/autostart/claude-profile-3.desktop"
check lib-exe-baked grep -aqF "$(readlink -f "$CLAUDE_DESKTOP_BIN")" "$DATA/claude-profiles/claude-app-id.so"
if command -v desktop-file-validate >/dev/null 2>&1; then
  check desktop-validate desktop-file-validate "$DATA"/applications/claude-desktop-[0-9].desktop "$CONFIG"/autostart/claude-profile-[0-9].desktop
else
  echo "SKIP desktop-validate (not installed)"
fi
check no-calls-when-no-activate bash -c "! [ -e '$tmp/calls.log' ]"

# Names with special characters must not break the template.
printf '1 Claude\n2 Work & Home\n3 Third\n' > "$CONFIG/claude-profiles/profiles.conf"
check install-special-name "$REPO/install.sh" --autostart --no-activate
check special-name-literal grep -qx 'Name=Work & Home' "$DATA/applications/claude-desktop-2.desktop"

# ---- Idempotency ----
snap() { (cd "$HOME" && find . -type f -not -path './.cache/*' | sort; md5sum .local/share/claude-profiles/manifest .config/claude-profiles/profiles.conf); }
snap > "$tmp/snap1"
check install-2 "$REPO/install.sh" --autostart --no-activate
snap > "$tmp/snap2"
check install-idempotent cmp -s "$tmp/snap1" "$tmp/snap2"

# ---- claude-profile dry runs ----
LIBPATH="$DATA/claude-profiles/claude-app-id.so"
out=$(CLAUDE_PROFILE_DRY=1 "$BIN/claude-profile" 2)
expect dry-raise "raise 2" "$out"
out=$(CLAUDE_PROFILE_DRY=1 "$BIN/claude-profile" 2 --x)
check dry-app-id grep -qx 'CLAUDE_APP_ID=claude-desktop-2' <<<"$out"
check dry-preload grep -qx "LD_PRELOAD=$LIBPATH" <<<"$out"
check dry-user-data-dir grep -q -- "--user-data-dir=$CONFIG/Claude-2 --class=claude-desktop-2 --x\$" <<<"$out"
out=$(LD_PRELOAD="/other.so:$LIBPATH" CLAUDE_APP_ID=claude-desktop-2 CLAUDE_PROFILE_DRY=1 "$BIN/claude-profile" 1 --x 2>/dev/null)
check dry-p1-preload grep -qx 'LD_PRELOAD=/other.so' <<<"$out"
check dry-p1-no-app-id grep -qx 'CLAUDE_APP_ID=' <<<"$out"
check dry-p1-no-data-dir bash -c "! grep -q -- '--user-data-dir' <<<'$out'"
out=$(LD_PRELOAD="$LIBPATH" CLAUDE_PROFILE_DRY=1 "$BIN/claude-profile" 1 --x)
check dry-p1-preload-empty grep -qx 'LD_PRELOAD=' <<<"$out"
for bad in 0 10 x ""; do
  rc=0; "$BIN/claude-profile" "$bad" >/dev/null 2>&1 || rc=$?
  expect "bad-profile-'$bad'" 2 "$rc"
done

# ---- Router ----
cp "$CONFIG/claude-profiles/profiles.conf" "$tmp/profiles.keep"
printf '1 Claude\n' > "$CONFIG/claude-profiles/profiles.conf"
out=$(CLAUDE_ROUTER_DRY=1 "$BIN/claude-url-router" 'claude://claude.ai/x?code=secret')
expect router-one-profile "claude-profile 1 claude://claude.ai/x?code=secret" "$out"
check router-log-no-secret bash -c "! grep -qE 'secret|/x' '$CACHE/claude-profiles/router.log'"
check router-log-host grep -q 'claude://claude.ai profile=1' "$CACHE/claude-profiles/router.log"
cp "$tmp/profiles.keep" "$CONFIG/claude-profiles/profiles.conf"
out=$(CLAUDE_ROUTER_PICK=2 CLAUDE_ROUTER_DRY=1 "$BIN/claude-url-router" 'claude://claude.ai/y')
expect router-pick "claude-profile 2 claude://claude.ai/y" "$out"
out=$(CLAUDE_ROUTER_DRY=1 "$BIN/claude-url-router")
expect router-no-arg "claude-profile 1" "$out"
# A recent sign-in in profile 3 wins over the picker.
mkdir -p "$CONFIG/Claude-3/logs"
echo "$(date '+%F %T') [Auth] Using system browser" > "$CONFIG/Claude-3/logs/main.log"
out=$(CLAUDE_ROUTER_DRY=1 "$BIN/claude-url-router" 'claude://claude.ai/z')
expect router-recent-login "claude-profile 3 claude://claude.ai/z" "$out"
rm -rf "$CONFIG/Claude-3"
# Some zenity versions print the picked value twice ("2|2").
cp "$tmp/stubs/zenity" "$tmp/zenity.keep"
printf '#!/bin/sh\necho "2|2"\n' > "$tmp/stubs/zenity"
out=$(CLAUDE_ROUTER_DRY=1 "$BIN/claude-url-router" 'claude://claude.ai/p')
expect router-zenity-double "claude-profile 2 claude://claude.ai/p" "$out"
cp "$tmp/zenity.keep" "$tmp/stubs/zenity"

# ---- Guard ----
printf 'x-scheme-handler/claude=claude-desktop-2.desktop;com.anthropic.Claude.desktop;\n' > "$CONFIG/mimeapps.list"
check guard-run-1 "$BIN/claude-profiles-guard"
SHADOW=$DATA/applications/com.anthropic.Claude.desktop
check shadow-exec grep -qx "Exec=$BIN/claude-url-router %U" "$SHADOW"
check shadow-action-exec grep -qx 'Exec=claude-desktop --new-chat' "$SHADOW"
check shadow-keeps-icon grep -qx 'Icon=claude-desktop' "$SHADOW"
expect shadow-exec-count 1 "$(grep -c "^Exec=$BIN/claude-url-router" "$SHADOW")"
check mimeapps-cleaned bash -c "! grep -q 'claude-desktop-2' '$CONFIG/mimeapps.list'"
check guard-log-written test -s "$CACHE/claude-profiles/guard.log"
lines1=$(wc -l < "$CACHE/claude-profiles/guard.log")
m1=$(stat -c %y "$SHADOW")
sleep 1
check guard-run-2 "$BIN/claude-profiles-guard"
expect guard-log-unchanged "$lines1" "$(wc -l < "$CACHE/claude-profiles/guard.log")"
expect guard-shadow-mtime "$m1" "$(stat -c %y "$SHADOW")"
# The guard restores a changed profile launcher.
echo "# junk" >> "$DATA/applications/claude-desktop-2.desktop"
"$BIN/claude-profiles-guard"
check guard-restore cmp -s "$DATA/claude-profiles/desktop/claude-desktop-2.desktop" "$DATA/applications/claude-desktop-2.desktop"

# ---- Icons ----
check icons-fallback bash -c "CLAUDE_ICON_SOURCE=/nonexistent python3 '$REPO/lib/make-icons.py' '$tmp/icons' 2 3"
expect icons-fallback-svg-count 2 "$(find "$tmp/icons" -name '*.svg' | wc -l)"
check icons-png bash -c "CLAUDE_ICON_SOURCE='$tmp/test.png' python3 '$REPO/lib/make-icons.py' '$tmp/icons-png' 4 && test -s '$tmp/icons-png/16x16/apps/claude-profile-4.png'"
check icons-decode python3 - "$REPO/lib/make-icons.py" "$tmp/test.png" "$tmp/test.rows" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("mi", sys.argv[1]); mi = importlib.util.module_from_spec(spec); spec.loader.exec_module(mi)
w, h, rows = mi.decode_png(open(sys.argv[2], "rb").read())
assert (w, h) == (48, 48), (w, h)
assert b"".join(bytes(r) for r in rows) == open(sys.argv[3], "rb").read(), "pixels differ after decode"
w2, h2, rows2 = mi.decode_png(mi.encode_png(w, h, mi.recolour(rows, 140)))
assert (w2, h2) == (48, 48)
PY

# ---- Profile 1 always exists ----
cp "$CONFIG/claude-profiles/profiles.conf" "$tmp/profiles.keep2"
printf '2 Work\n3 Third\n' > "$CONFIG/claude-profiles/profiles.conf"
check install-no-p1 "$REPO/install.sh" --autostart --no-activate
check conf-adds-p1 grep -qx '1 Claude' "$CONFIG/claude-profiles/profiles.conf"
cp "$tmp/profiles.keep2" "$CONFIG/claude-profiles/profiles.conf"
check install-restore-conf "$REPO/install.sh" --autostart --no-activate

# ---- Uninstall ----
check manifest-files-exist bash -c "grep '^/' '$DATA/claude-profiles/manifest' | while read -r f; do test -e \"\$f\" || { echo missing \$f; exit 1; }; done"
cp "$DATA/claude-profiles/manifest" "$tmp/manifest.copy"
check uninstall "$REPO/uninstall.sh" --no-activate
manifest_gone() { local f; while IFS= read -r f; do case "$f" in /*) [ ! -e "$f" ] || { echo "still there: $f"; return 1; } ;; esac; done < "$tmp/manifest.copy"; }
check uninstall-removed-manifest-files manifest_gone
check uninstall-keeps-profile-data test -f "$CONFIG/Claude-2/keep.txt"
check uninstall-keeps-conf test -f "$CONFIG/claude-profiles/profiles.conf"
check uninstall-removes-manifest bash -c "! [ -e '$DATA/claude-profiles/manifest' ]"
check uninstall-removes-extension bash -c "! [ -e '$DATA/gnome-shell/extensions/computer-use-linux@avifenesh.dev' ]"

# ---- A launcher the user made before the install comes back after uninstall ----
printf '[Desktop Entry]\nName=My own Claude\nExec=claude-desktop %%U\nType=Application\n' > "$SHADOW"
cp "$SHADOW" "$tmp/own.desktop"
check install-over-own "$REPO/install.sh" --no-activate
check own-backup test -f "$DATA/claude-profiles/backup/com.anthropic.Claude.desktop"
"$BIN/claude-profiles-guard"
check own-overwritten-by-guard grep -qx "Exec=$BIN/claude-url-router %U" "$SHADOW"
check uninstall-own "$REPO/uninstall.sh" --no-activate
check own-restored cmp -s "$tmp/own.desktop" "$SHADOW"
check own-state-dir-gone bash -c "! [ -e '$DATA/claude-profiles' ]"

echo
if [ "$FAILS" -eq 0 ]; then echo "ALL PASSED"; else echo "$FAILS FAILED"; exit 1; fi
