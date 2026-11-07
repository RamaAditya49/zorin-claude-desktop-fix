---
type: done
id: 20261107-public-release
status: done
spec: internal/spec/20261107-public-release.md
plan: internal/plan/20261107-public-release.md
completed: 2026-11-07
commit: 6aaa23030e9e9674e11459ed3afc236a303d6800
---

# Done: rilis publik zorin-claude-desktop-fix

## Hasil

Repo publik `RamaAditya49/zorin-claude-desktop-fix` terbit dengan launcher, raise, router, guard, library app id, generator ikon, installer, dan uninstaller.
Semua 76 cek di `tests/run.sh` lulus di host build. Audit gitleaks dan grep bersih.

## Matriks acceptance criteria

| ID | Hasil | Bukti |
|----|-------|-------|
| AC-01 | PASS | `gitleaks detect --source . -v` (dengan history) → `no leaks found`. `grep -rniE 'rama-tuf\|rama-workstation\|ramaaditya\|/home/\|konektor\|shinta\|biver\|wulan\|aibuilders'` → hanya URL GitHub repo ini. Author commit memakai email noreply GitHub. |
| AC-02 | PASS | `grep -rnE '/usr/' bin lib install.sh uninstall.sh templates` → hanya fallback `claude-desktop`, `CLAUDE_EXE`, dan default `XDG_DATA_DIRS`. |
| AC-03 | PASS | `tests/run.sh`: `install-1`, `install-files`, `no-unresolved-markers`, `desktop-validate`, `install-idempotent` |
| AC-04 | PASS | `tests/run.sh`: `uninstall-removed-manifest-files`, `uninstall-keeps-profile-data`, `uninstall-keeps-conf`, `own-restored` |
| AC-05 | PASS | `tests/run.sh`: `dry-raise` |
| AC-06 | PASS | `tests/run.sh`: `dry-app-id`, `dry-preload`, `dry-user-data-dir` |
| AC-07 | PASS | `tests/run.sh`: `dry-p1-preload`, `dry-p1-no-app-id`, `dry-p1-no-data-dir`, `dry-p1-preload-empty` |
| AC-08 | PASS | `tests/run.sh`: `router-one-profile`, `router-log-no-secret` |
| AC-09 | PASS | `tests/run.sh`: `router-pick`, `router-recent-login`, `router-zenity-double` |
| AC-10 | PASS | indirect: review `bin/claude-profile-raise`. `GetMonitorLayout` gagal → log, lalu `os.execve` plain launch. |
| AC-11 | PASS | `tests/run.sh`: `guard-log-unchanged`, `guard-shadow-mtime` |
| AC-12 | PASS | `tests/run.sh`: `gcc-strict` (`-Wall -Wextra -Werror`) |
| AC-13 | PASS | `tests/run.sh`: `icons-fallback`, `icons-fallback-svg-count`. Ikon asli Claude di host build juga ter-decode: 5 ukuran PNG. |
| AC-14 | PASS | Review `README.md` dan `README.id.md`: Requirements, Install, Multiple profiles, Uninstall, Troubleshooting, Security notes, Credits, disclaimer merek. |
| AC-15 | PASS | `gh repo view --json visibility` → `PUBLIC`. `git ls-remote origin main` = HEAD `6aaa230`. |

## Berkas yang berubah

- `bin/`, `lib/`, `templates/` — kode perbaikan, generik
- `install.sh`, `uninstall.sh` — install dan uninstall berbasis manifest, dengan cadangan launcher milik pengguna
- `tests/run.sh` — cek statis dan sandbox
- `vendor/computer-use-linux@avifenesh.dev/` — extension upstream MIT, tanpa perubahan kode
- `README.md`, `README.id.md`, `docs/how-it-works.md`, `LICENSE`, `.gitignore`
- `internal/` — bootstrap docs, riset, spec, plan, done

## Verifikasi

- `bash tests/run.sh` di host build (Fedora 44 KDE) dari clone GitHub → `ALL PASSED`, exit 0.
- `shellcheck` (lewat `uvx --from shellcheck-py`) di host build → tanpa warning. Satu info SC2016 di `tests/run.sh` disengaja.

## Dokumen pusat yang diperbarui

- `internal/docs/blueprint.md`, `brd.md`, `prd.md`, `frd.md`, `erd.md` — dibuat dari nol untuk repo baru.

## Sisa risiko dan tindak lanjut

- Belum ada uji live di sesi GNOME Wayland bersih. Mesin maintainer memakai setup private, dan host build tidak punya GNOME.
- Update Claude Desktop bisa mengubah cara app id dibuat. Cek `ListWindows` setelah tiap update.
