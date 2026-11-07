---
type: spec
id: 20261107-public-release
status: approved       # draft | approved | superseded
created: 2026-11-07
updated: 2026-11-07
plan: internal/plan/20261107-public-release.md
done: internal/done/20261107-public-release.md
frd: [FR-001, FR-002, FR-003, FR-004, FR-005, FR-006, FR-007, FR-008, NFR-001, NFR-002]
---

# Spec: rilis publik zorin-claude-desktop-fix

## Tujuan

Terbitkan perbaikan Claude Desktop untuk GNOME Wayland sebagai repo open source publik yang generik, tanpa kredensial dan tanpa path pribadi.

## Konteks

Rama memakai perbaikan ini di setup private sejak 2026-11-06.
Versi private memuat nama orang, 5 profil tetap, tata letak monitor pribadi, dan path tetap.
Pengguna Zorin OS lain mengalami gejala yang sama: klik ikon dock tidak memunculkan window Claude.
Riset akar masalah: [internal/research/claude-desktop-wayland.md](../research/claude-desktop-wayland.md).

## Ruang lingkup

- Launcher `claude-profile <N>` untuk profil 1 sampai 9.
- `claude-profile-raise`: angkat window lewat extension GNOME window-control.
- `claude-app-id.so`: app id `claude-desktop-N` per profil lewat `LD_PRELOAD`.
- `claude-url-router`: arahkan link `claude://` ke profil yang tepat.
- `claude-profiles-guard` dengan unit systemd user path dan timer.
- Ikon profil: warna diubah dari ikon Claude yang terpasang di mesin pengguna. Repo tidak membawa ikon Claude.
- `install.sh` dan `uninstall.sh` berbasis manifest.
- `tests/run.sh`: cek statis dan uji install di HOME sementara.
- README Inggris, README Bahasa Indonesia, `docs/how-it-works.md`, LICENSE MIT.
- Repo GitHub publik `RamaAditya49/zorin-claude-desktop-fix`.

## Di luar lingkup

- `claude-grid` dan tata letak monitor pribadi.
- Mengganti setup private di mesin Rama. Setup itu tetap seperti sekarang.
- Uji live di sesi GNOME mesin Rama. Install di sana bentrok dengan setup private.
- Extension GNOME buatan sendiri. Repo memakai extension upstream MIT tanpa perubahan.
- Paket `.deb` atau rilis di extensions.gnome.org.

## Batasan

- Repo publik: tidak ada kredensial, token, email selain noreply GitHub, nama orang selain pemegang hak cipta di LICENSE, atau path home absolut.
- Build dan test jalan di host build terpisah (Fedora 44 KDE). Host itu tidak punya GNOME, jadi uji di sana hanya statis dan sandbox.
- Repo tidak membawa aset merek Anthropic.

## Acceptance criteria (EARS)

| ID | Pola | Kriteria | Cara verifikasi |
|----|------|----------|-----------------|
| AC-01 | Ubiquitous | The repository shall contain no credential, token, private key, absolute home path, or personal name other than the copyright holder in `LICENSE`. | `gitleaks detect` dan `grep` daftar nama/path pada seluruh history |
| AC-02 | Ubiquitous | The scripts shall derive every user path from `$HOME` or XDG variables, and every Claude Desktop path from `command -v claude-desktop` or an environment override. | Review kode dan `grep -n '/usr/'` |
| AC-03 | Event-driven | When the user runs `install.sh --profiles 3 --autostart --no-activate` with an empty HOME, the installer shall create every launcher, desktop, icon, unit, and library file with no unresolved `@...@` marker. | `tests/run.sh` di host build |
| AC-04 | Event-driven | When the user runs `uninstall.sh` after an install, the uninstaller shall remove every file in the manifest and keep every `Claude*` profile data folder. | `tests/run.sh` di host build |
| AC-05 | Event-driven | When `claude-profile <N>` starts with no other argument, the launcher shall run `claude-profile-raise <N>`. | Dry run di `tests/run.sh` |
| AC-06 | Event-driven | When profile N of 2 or more starts, the launcher shall add the app-id library to `LD_PRELOAD` and set `CLAUDE_APP_ID=claude-desktop-N`. | Dry run di `tests/run.sh` |
| AC-07 | Event-driven | When profile 1 starts, the launcher shall remove the app-id library from `LD_PRELOAD` and unset `CLAUDE_APP_ID`. | Dry run di `tests/run.sh` |
| AC-08 | Event-driven | When a `claude://` link arrives and only profile 1 exists, the router shall open the link in profile 1 without a picker. | Dry run di `tests/run.sh` |
| AC-09 | Event-driven | When a `claude://` link arrives with no recent login and `CLAUDE_ROUTER_PICK=2`, the router shall open the link in profile 2. | Dry run di `tests/run.sh` |
| AC-10 | Unwanted behavior | If the window-control extension is not available, then `claude-profile-raise` shall start the profile with a plain launch. | indirect: review kode |
| AC-11 | Event-driven | When the guard runs a second time with no change in between, the guard shall write no file and no log line. | `tests/run.sh` |
| AC-12 | Ubiquitous | The app-id library shall build with `gcc -Wall -Wextra -Werror`. | `tests/run.sh` |
| AC-13 | Unwanted behavior | If the installed Claude PNG icon cannot be decoded, then the icon generator shall write one SVG badge icon for each profile from 2 to N. | `tests/run.sh` |
| AC-14 | Ubiquitous | The README shall document requirements, install, profile names, uninstall, troubleshooting, security notes, extension credit, and a trademark disclaimer. | Review manual |
| AC-15 | Event-driven | When the release is ready, GitHub shall show `RamaAditya49/zorin-claude-desktop-fix` as public with branch `main` at the local HEAD. | `gh repo view --json visibility` dan `git ls-remote` |

## Pertanyaan terbuka

- TBD: Apakah versi Claude Desktop berikutnya tetap membaca `CHROME_DESKTOP` lewat `getenv`? Cek `ListWindows` setelah tiap update.
