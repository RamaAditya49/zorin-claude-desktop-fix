---
type: research
topic: claude-desktop-wayland
status: current        # current | stale
created: 2026-11-07
updated: 2026-11-07
---

# Riset: Claude Desktop di GNOME Wayland

Riset asal dibuat 2026-11-06 di repo private. Berkas ini adalah versi publik tanpa data pribadi.

## Pertanyaan

- Kenapa klik ikon dock Claude kadang tidak memunculkan window?
- Kenapa semua window profil tambahan masuk ke satu ikon dock?
- Apakah update Claude Desktop merusak perbaikan?

## Ringkasan temuan

- Dock memberi activation token ke proses launch kedua yang singkat, bukan ke app yang sudah berjalan. GNOME Wayland lalu menolak `focus()` dan `restore()` dari app. — sumber: [S1], [S2]
- Window yang kembali dari tray kadang muncul dengan ukuran 0x0. Resize pertama kadang hilang. Activate lalu resize lagi berhasil. — sumber: [S2]
- Electron mengisi `CHROME_DESKTOP` dari `desktopName` di `package.json` (`com.anthropic.Claude.desktop`). Electron membuat Wayland app_id dan X11 WM_CLASS dari nilai itu. Flag `--class` tidak berpengaruh. — sumber: [S3], [S4]
- `LD_PRELOAD` dengan override `getenv("CHROME_DESKTOP")` memberi tiap profil app_id sendiri. — sumber: [S4]
- App mendaftarkan dirinya sebagai handler `claude://` saat start. Dengan app_id baru, profil tambahan mendaftarkan `claude-desktop-N.desktop`. Guard harus mengembalikan default. — sumber: [S3]
- Update lewat apt hanya mengganti `/usr/lib/claude-desktop`. Restart dari dalam app memakai `app.relaunch()`, yang mewarisi environment proses lama. — sumber: [S3]

## Detail

### Klik dock gagal

- Log profil menulis `second-instance: the main window is made; it is shown now`, tetapi window tidak terlihat.
- Fungsi second-instance di `app.asar`: `isMinimized() ? restore()+focus() : isVisible() ? focus() : show()`. Di GNOME Wayland tanpa token, `restore()` dan `focus()` tidak berefek.

### Window 0x0

- Setelah launch kedua, `ListWindows` menunjukkan window baru dengan `width: 0, height: 0` dan `focused: false`.
- `ActivateWindow` saja tidak memberi fokus. `ResizeWindow` lalu `ActivateWindow` memberi `focused: true`.

### App id sama

| Uji | Hasil `wm_class` |
|-----|------------------|
| Wayland, `--class=claude-desktop-N` | `com.anthropic.Claude` |
| `--ozone-platform=x11`, `--class=claude-desktop-N` | `com.anthropic.Claude` |
| `LD_PRELOAD=claude-app-id.so`, `CLAUDE_APP_ID=claude-desktop-N` | `claude-desktop-N` |

### Kesalahan saat membuat library

- Library yang menghapus `LD_PRELOAD` di constructor gagal: `setsid` memuat library lebih dulu dan menghapus variabel sebelum Claude jalan. Perbaikan: library hanya aktif kalau `/proc/self/exe` adalah exe Claude.
- Library yang menghapus variabel di proses Claude merusak `app.relaunch()`. Perbaikan: library menyimpan variabel. Child process memuat library, tetapi library tidak aktif di sana.
- `argv[0]` proses Claude bisa symlink atau path asli. Cari proses utama lewat `/proc/<pid>/exe`.

### Alat

- Extension GNOME `computer-use-linux@avifenesh.dev` versi 3. D-Bus `dev.avifenesh.ComputerUseLinux.WindowControl`. Method: `ListWindows`, `ActivateWindow`, `MoveWindow`, `ResizeWindow`, `GetMonitorLayout`.
- `ActivateWindow` memanggil `unminimize()` dan `Main.activateWindow()` di dalam gnome-shell, jadi aturan fokus tidak menghalangi.

### Lingkungan uji

| Hal | Nilai |
|-----|-------|
| OS | Zorin OS 18.1, GNOME Shell 46.0, Wayland |
| Claude Desktop | paket apt `claude-desktop` 4.23118.0 |
| Dock | `zorin-taskbar@zorinos.com` |

## Keputusan dari riset ini

- Angkat window lewat extension → `bin/claude-profile-raise`.
- App id per profil lewat `LD_PRELOAD` → `lib/claude-app-id.c`.
- Profil 1 tetap memakai `com.anthropic.Claude`. Launch profil 1 membuang library dari `LD_PRELOAD`.
- Guard membuang `claude-desktop-N.desktop` dari asosiasi `claude://` → `bin/claude-profiles-guard`.
- Ikon profil dibuat dari ikon Claude di mesin pengguna, supaya repo tidak membawa aset merek → `lib/make-icons.py`.

## Pertanyaan terbuka

- TBD: Apakah versi Claude Desktop berikutnya tetap memakai `getenv("CHROME_DESKTOP")` untuk app_id?
- TBD: Apakah Anthropic akan mendukung app_id per profil secara resmi?

## Sumber

- [S1] Log `logs/main.log` profil, baris `second-instance:` — dicek 2026-11-06
- [S2] Hasil `gdbus call ... WindowControl.ListWindows` sebelum dan sesudah tiap uji — dicek 2026-11-06
- [S3] `/usr/lib/claude-desktop/resources/app.asar` (`desktopName`, second-instance, `setAsDefaultProtocolClient`, `app.relaunch`) — dicek 2026-11-06
- [S4] Uji launch dengan `--ozone-platform=x11` dan dengan `LD_PRELOAD` — dicek 2026-11-06
- [S5] Upstream extension: https://github.com/avifenesh/codex-desktop-linux, path `computer-use-linux/gnome-shell-extension`, lisensi MIT — dicek 2026-11-06

## Riwayat

- 2026-11-07: versi publik dibuat dari riset private 2026-11-06.
