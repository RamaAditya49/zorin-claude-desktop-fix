---
type: plan
id: 20261107-public-release
status: done           # draft | in-progress | blocked | done
spec: internal/spec/20261107-public-release.md
created: 2026-11-07
updated: 2026-11-07
---

# Plan: rilis publik zorin-claude-desktop-fix

## Pendekatan

Porting kode dari setup private maintainer menjadi versi generik.
Jumlah profil dan nama profil datang dari `profiles.conf`, bukan dari kode.
Satu launcher `claude-profile <N>` menggantikan skrip `claude-desktop-2..5`.
Semua path user datang dari `$HOME` dan variabel XDG. Path Claude Desktop datang dari `command -v claude-desktop`.
Installer merender template saat install. Repo tidak memuat path absolut.

## Desain

### Lokasi (semua dari XDG, nilai default di kurung)

| Nama | Nilai |
|------|-------|
| `BIN_DIR` | `$HOME/.local/bin` |
| `DATA` | `${XDG_DATA_HOME:-$HOME/.local/share}` |
| `CONFIG` | `${XDG_CONFIG_HOME:-$HOME/.config}` |
| `CACHE` | `${XDG_CACHE_HOME:-$HOME/.cache}` |
| Folder state | `$DATA/claude-profiles/` (library, template launcher, manifest) |
| Konfigurasi profil | `$CONFIG/claude-profiles/profiles.conf` |
| Data profil 1 | `$CONFIG/Claude` (default Electron) |
| Data profil N | `$CONFIG/Claude-N` |
| Log dan lock | `$CACHE/claude-profiles/` |
| Launcher bayangan profil 1 | `$DATA/applications/com.anthropic.Claude.desktop` |

### `profiles.conf`

Format: satu baris `<nomor> <nama tampilan>`. Baris `#` adalah komentar. Profil 1 wajib ada. Nomor 1 sampai 9.

### Komponen

| Berkas repo | Terpasang di | Fungsi |
|-------------|--------------|--------|
| `bin/claude-profile` | `BIN_DIR` | `claude-profile <N> [args]`. Tanpa argumen dan tanpa `CLAUDE_PLAIN_LAUNCH`: jalankan `claude-profile-raise <N>`. Dengan argumen: jalankan Claude Desktop. |
| `bin/claude-profile-raise` | `BIN_DIR` | Python. Port dari versi private. Argumen `<N>`. Launch memakai `claude-profile <N>` dengan `CLAUDE_PLAIN_LAUNCH=1`. |
| `bin/claude-url-router` | `BIN_DIR` | Arahkan link dan berkas `.mcpb`/`.skill` ke profil. Satu profil: langsung ke profil 1. |
| `bin/claude-profiles-guard` | `BIN_DIR` | Jaga launcher, launcher bayangan, dan handler `claude://`. |
| `lib/claude-app-id.c` | `DATA/claude-profiles/` | Library `LD_PRELOAD`. Path exe masuk lewat `-DCLAUDE_EXE` saat build. |
| `lib/make-icons.py` | dijalankan installer | Ubah warna ikon Claude yang terpasang. Kalau gagal: ikon SVG nomor. |
| `templates/*.in` | dirender installer | Launcher profil N, autostart profil N, unit systemd. |
| `vendor/computer-use-linux@avifenesh.dev/` | `DATA/gnome-shell/extensions/` | Extension upstream MIT, tanpa perubahan. |
| `install.sh`, `uninstall.sh` | — | Install dan uninstall berbasis manifest. |
| `tests/run.sh` | — | Cek statis dan uji sandbox. |

### Launcher bayangan profil 1

Guard membuat `$DATA/applications/com.anthropic.Claude.desktop` dari berkas paket.
Guard mengganti baris `Exec=` pertama di grup `[Desktop Entry]` menjadi `Exec=<BIN_DIR>/claude-url-router %U`.
Guard mengganti baris `Name=` pertama di grup itu dengan nama profil 1.
Launcher ini tetap tampil di menu. Ikon pin dock yang lama tetap jalan karena id-nya sama.

### Mode uji (tanpa efek ke sistem)

| Variabel | Efek |
|----------|------|
| `CLAUDE_PROFILE_DRY=1` | `claude-profile` mencetak environment dan perintah, lalu keluar 0 |
| `CLAUDE_ROUTER_DRY=1` | `claude-url-router` mencetak perintah, lalu keluar 0 |
| `CLAUDE_ROUTER_PICK=<N>` | Router memakai profil N tanpa dialog |
| `CLAUDE_ICON_SOURCE=<path>` | `make-icons.py` membaca ikon dari path ini |

## Langkah

- [x] 1. Tulis `bin/claude-profile` — berkas: `bin/claude-profile` — AC: AC-02, AC-05, AC-06, AC-07 — verifikasi: `tests/run.sh`
- [x] 2. Port `claude-profile-raise` — berkas: `bin/claude-profile-raise` — AC: AC-02, AC-10 — verifikasi: `python3 -m py_compile` dan review
- [x] 3. Port router — berkas: `bin/claude-url-router` — AC: AC-08, AC-09 — verifikasi: `tests/run.sh`
- [x] 4. Port guard dan unit systemd — berkas: `bin/claude-profiles-guard`, `templates/claude-profiles-guard.*.in` — AC: AC-11 — verifikasi: `tests/run.sh`
- [x] 5. Port library — berkas: `lib/claude-app-id.c` — AC: AC-12 — verifikasi: `gcc -Wall -Wextra -Werror`
- [x] 6. Tulis generator ikon — berkas: `lib/make-icons.py` — AC: AC-13 — verifikasi: `tests/run.sh`
- [x] 7. Tulis installer dan uninstaller — berkas: `install.sh`, `uninstall.sh`, `templates/*.in` — AC: AC-03, AC-04 — verifikasi: `tests/run.sh`
- [x] 8. Tulis test — berkas: `tests/run.sh` — AC: AC-03 sampai AC-13 — verifikasi: `bash tests/run.sh` di host build
- [x] 9. Tulis dokumentasi — berkas: `README.md`, `README.id.md`, `docs/how-it-works.md`, `LICENSE` — AC: AC-14 — verifikasi: review
- [x] 10. Audit rahasia dan path — berkas: semua — AC: AC-01, AC-02 — verifikasi: `gitleaks detect`, `grep`
- [x] 11. Buat repo GitHub publik dan push — AC: AC-15 — verifikasi: `gh repo view --json visibility`

## Risiko dan rollback

- Update Claude Desktop memindah path exe → profil kembali ke satu ikon, app tetap jalan. Jalankan `install.sh` lagi untuk build ulang library.
- Data pribadi ikut terbit → audit sebelum push. Kalau lolos, hapus repo publik, tulis ulang history, buat ulang.
- Installer merusak setup pengguna → `uninstall.sh` hanya menghapus berkas di manifest. Folder data profil tidak tersentuh.

## Log progres

- 2026-11-07: plan dibuat.
- 2026-11-07: langkah 1-9 selesai (kode, test, docs). tests/run.sh di host build: semua PASS, exit 0. Audit grep dan gitleaks bersih (langkah 10 belum ditandai).
- 2026-11-07: review coordinator. Perbaikan: nilai zenity "2|2", nilai awk lewat ENVIRON, profil 1 selalu ada, cadangan launcher milik pengguna, label log dikutip (shellcheck SC2209). README: Zorin OS 17 dihapus karena memakai GNOME 43. Test tambahan lulus.
- 2026-11-07: nama host build dan nama repo private dihapus dari internal/. Audit grep dan gitleaks bersih.
