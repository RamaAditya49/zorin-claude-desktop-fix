# How it works

Claude Desktop is an Electron app. On GNOME Wayland, four things go wrong with it.
This page lists each cause and the fix.

## 1. A dock click does not show the window

**Cause.** A dock click starts a second, short launch of the app.
GNOME gives the activation token to that short launch, not to the app that already runs.
The running app then calls `focus()` or `restore()` without a token. GNOME ignores these calls.
The window stays hidden or minimized.

**Fix.** `claude-profile N` with no argument runs `claude-profile-raise N`.
The script finds the main process of the profile. It reads `/proc/<pid>/exe` and skips `--type=` child processes.
It then asks GNOME Shell for the windows, through the window-control extension.
The extension runs inside GNOME Shell, so the focus rules do not block it.
The script calls `ActivateWindow`, which unminimizes the window and raises it.

If the profile does not run, or the extension is not available, the script starts the profile with a plain launch.

## 2. A window from the tray is invisible

**Cause.** A window that returns from the tray can map with size 0x0.
The window exists, but you cannot see it.
The first resize request is sometimes dropped.

**Fix.** The script picks the largest real window of the profile.
If the window has no area, or lies off screen, the script sends `ResizeWindow`.
It uses the saved size from `window-state.json`, capped to the monitor.
If the size stays 0x0, it calls `ActivateWindow` and sends the resize again, up to five times.
After the resize, it calls `MoveWindow` to centre the window on the monitor of the focused window.
GNOME drops a move that arrives before the resize ends, so the order matters.
If the window is still 0x0, the script shows a notification.

When the window is in the tray and has no window at all, the script runs the launch a second time.
The running app then creates its main window. A lock file stops a double click from running the script twice.

## 3. All profiles share one dock icon

**Cause.** Electron sets `CHROME_DESKTOP` from the `desktopName` field in `package.json`.
This value is `com.anthropic.Claude.desktop`.
Electron builds the Wayland `app_id` and the X11 `WM_CLASS` from it.
The `--class` flag has no effect.
GNOME matches the id to the launcher with the same `StartupWMClass`, so every window goes under one icon.

**Fix.** `claude-app-id.so` is a small library that you load with `LD_PRELOAD`.
It replaces `getenv("CHROME_DESKTOP")`.
When `CLAUDE_APP_ID=claude-desktop-N` is set, the call returns `claude-desktop-N.desktop`.
Each profile launcher has the matching `StartupWMClass=claude-desktop-N`, so GNOME shows the right icon.

Design points:

- The library is active only when `/proc/self/exe` is the Claude program. Wrappers and child processes load it, but it does nothing there.
- The library keeps `LD_PRELOAD` and `CLAUDE_APP_ID` in the environment. A restart from inside the app keeps the same id.
- The installer builds the library with the real path of the Claude program (`-DCLAUDE_EXE`). It builds to a temporary file and renames it, so running processes keep their old mapping.
- Profile 1 keeps the package id. Its launch removes the library from `LD_PRELOAD` and unsets `CLAUDE_APP_ID`.

## 4. Sign-in links open the wrong profile

**Cause.** Each profile registers itself as the handler of `claude://` links when it starts.
After a start, the default handler can be a profile launcher or a portal choice.
A sign-in link then opens in a random profile.

**Fix.** Two parts work together.

- `claude-url-router` receives the link. With one profile, it opens profile 1.
  With more profiles, it picks the profile that wrote a "system browser" line in its log less than ten minutes ago.
  If there is none, it asks which profile to use. It logs only the scheme and host of the link.
- `claude-profiles-guard` keeps the setup in place. It runs from a systemd user path unit and a timer.
  It restores the profile launchers from their templates, and it keeps a shadow of the package launcher.
  The shadow has the same id as the package launcher, but its `Exec=` line runs the router.
  The guard removes the `claude://` association from the profile launchers, resets the default handler, and resets a remembered Flatpak portal choice.

Each guard step writes only when the state is wrong, so the path unit does not loop.
A second run with no change writes no file and no log line.
