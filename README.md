# zorin-claude-desktop-fix

English | [Bahasa Indonesia](README.id.md)

Fixes for the official Claude Desktop app on GNOME with Wayland (Zorin OS and others).
On this desktop, a click on the dock icon often shows no window.
Each extra profile also lands under the icon of profile 1.
This project fixes both problems and lets you run up to nine profiles, each with its own icon.

Not affiliated with Anthropic. Claude is a trademark of Anthropic.

## What it fixes

| Symptom | Fix |
|---------|-----|
| You click the dock icon and no window appears. | A helper asks GNOME Shell to show and activate the window. |
| A window that returns from the tray is invisible (size 0x0). | The helper sets the size and position, then activates the window. |
| All profiles share one dock icon. | A small preload library gives each profile its own window id and icon. |
| Sign-in links (`claude://`) open the wrong profile. | A router opens the link in the profile that started the sign-in. A guard keeps this setting. |

See [docs/how-it-works.md](docs/how-it-works.md) for the causes.

## Requirements

- Zorin OS 18, or another distribution with GNOME 45 to 51 on Wayland.
- The official `claude-desktop` package (see "Install Claude Desktop").
- Packages: `git gcc python3 zenity libnotify-bin libglib2.0-bin xdg-utils desktop-file-utils`

```bash
sudo apt install git gcc python3 zenity libnotify-bin libglib2.0-bin xdg-utils desktop-file-utils
```

## Install Claude Desktop

Skip this section if `claude-desktop` is already installed.

1. Download the signing key of the Claude Desktop package:

```bash
sudo curl -fsSL https://downloads.claude.ai/keys/claude-code.asc \
  -o /usr/share/keyrings/claude-desktop-archive-keyring.asc
```

2. Check the key fingerprint. The output must show `31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE`.
   If it shows a different value, stop and delete the key file.
   A matching fingerprint shows that the file is the Anthropic release key, not a changed copy. apt then installs only packages that this key signed.

```bash
gpg --show-keys /usr/share/keyrings/claude-desktop-archive-keyring.asc
```

3. Add the package source and install Claude Desktop:

```bash
echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/claude-desktop-archive-keyring.asc] https://downloads.claude.ai/claude-desktop/apt/stable stable main" \
  | sudo tee /etc/apt/sources.list.d/claude-desktop.list
sudo apt update && sudo apt install claude-desktop
```

## Install

```bash
git clone https://github.com/RamaAditya49/zorin-claude-desktop-fix
cd zorin-claude-desktop-fix
./install.sh
```

Then log out and log in once. GNOME on Wayland loads a new extension only at login.
Open Claude from its dock icon. It now shows its window on every click.

The installer is safe to run again.
Use `./install.sh --no-activate` to copy files only. It does not touch systemd, GNOME, or the `claude://` handler.

## Multiple profiles

Each profile has its own sign-in and its own data folder.
Profile 1 is the normal Claude (`~/.config/Claude`). Profile N uses `~/.config/Claude-N`.

```bash
./install.sh --profiles 3
```

This sets up profiles 1 to 3. Each profile 2 and up gets a launcher in the app menu, with its own coloured icon.
Pin the launchers to the dock.

The profile names are in `~/.config/claude-profiles/profiles.conf`:

```
1 Claude
2 Work
3 Personal
```

Edit the names, then run `./install.sh` again.
The number must be 1 to 9. A name can have up to 60 characters.

## Autostart

Run `./install.sh --profiles 3 --autostart` to start profiles 2 and up at login.
This is useful when a profile has scheduled tasks.
Profile 1 uses the autostart setting of the app itself.
Run the installer again without `--autostart` to remove the autostart files.

## Uninstall

```bash
./uninstall.sh
```

The uninstaller removes only the files in its record (`~/.local/share/claude-profiles/manifest`).
It keeps your profile data folders and `profiles.conf`.
If you had your own `com.anthropic.Claude.desktop` in `~/.local/share/applications` before the install, the installer saves a copy and the uninstaller puts it back.

## How to check

List the windows and their ids:

```bash
gdbus call --session --dest dev.avifenesh.ComputerUseLinux.WindowControl \
  --object-path /dev/avifenesh/ComputerUseLinux/WindowControl \
  --method dev.avifenesh.ComputerUseLinux.WindowControl.ListWindows
```

The `wm_class` of profile N must be `claude-desktop-N`.

| Log | Content |
|-----|---------|
| `~/.cache/claude-profiles/raise.log` | Window events |
| `~/.cache/claude-profiles/router.log` | Link scheme, host, and chosen profile |
| `~/.cache/claude-profiles/guard.log` | Changes made by the guard |

## Troubleshooting

| Symptom | Check | Fix |
|---------|-------|-----|
| A click on the dock icon shows no window. | `gnome-extensions info computer-use-linux@avifenesh.dev` must show `State: ACTIVE`. Read `~/.cache/claude-profiles/raise.log`. | Run `./install.sh` again. Log out and log in. |
| A message says the window is stuck. | The window stayed at size 0x0 after five tries. | Right-click the Claude icon in the system tray. Choose Quit. Open it again from the dock. |
| The window of profile 2 or higher is under the icon of profile 1. | `wm_class` in `ListWindows`. | Open the profile from its own launcher, not with the `claude-desktop` command. Run `./install.sh` again. |
| A sign-in link opens the wrong profile. | `xdg-mime query default x-scheme-handler/claude` must show `com.anthropic.Claude.desktop`. | Run `~/.local/bin/claude-profiles-guard`. |
| An edit to a profile launcher disappears. | The guard restores launchers from their templates. | Edit the template in `~/.local/share/claude-profiles/desktop/`, then run `./install.sh` again. |
| The profile icon has no colour. | Look in `~/.local/share/icons/hicolor/`. | Run `gtk-update-icon-cache -f -t ~/.local/share/icons/hicolor`. Log out and log in. |
| The extension is off after a GNOME upgrade. | `gnome-shell --version`. The extension supports GNOME 45 to 51. | Get a newer version from the upstream project (see `vendor/computer-use-linux@avifenesh.dev/UPSTREAM.md`). |

Profile 1 keeps the normal Claude icon. This is correct.

## After a Claude Desktop update

1. Run the `ListWindows` command above.
2. Check that the `wm_class` of profile N is `claude-desktop-N`.
3. If the path of the Claude program changed, run `./install.sh` again. It builds the library for the new path.
4. Do not change the `app.asar` file of Claude. An update overwrites it.

## Security notes

- The `LD_PRELOAD` library is active only inside the Claude program. In other programs it does nothing.
- The library changes one environment lookup (`CHROME_DESKTOP`). It has no network access and collects no data.
- The logs store only the link scheme and host, for example `claude://claude.ai`. They never store a path, a query, or a token.
- The window-control extension offers a D-Bus API to every process in your session. That API lists window titles and can move and activate windows.
  Review the code in `vendor/` before you install.
- The installer writes only inside your home folder. The uninstaller refuses any path outside it.

## Credits

The window-control extension `computer-use-linux@avifenesh.dev` comes from
[avifenesh/codex-desktop-linux](https://github.com/avifenesh/codex-desktop-linux) (MIT license).
This repository ships an unchanged copy. See `vendor/computer-use-linux@avifenesh.dev/UPSTREAM.md`.

## License

MIT. See [LICENSE](LICENSE).
