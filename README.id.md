# zorin-claude-desktop-fix

[English](README.md) | Bahasa Indonesia

Perbaikan untuk aplikasi resmi Claude Desktop di GNOME dengan Wayland (Zorin OS dan lainnya).
Di desktop ini, klik ikon dock sering tidak memunculkan window.
Profil tambahan juga masuk ke ikon profil 1.
Proyek ini memperbaiki kedua masalah itu dan memungkinkan sampai sembilan profil, masing-masing dengan ikon sendiri.

Tidak berafiliasi dengan Anthropic. Claude adalah merek dagang Anthropic.

## Yang diperbaiki

| Gejala | Perbaikan |
|--------|-----------|
| Klik ikon dock, window tidak muncul. | Sebuah helper meminta GNOME Shell menampilkan dan mengaktifkan window. |
| Window yang kembali dari tray tidak terlihat (ukuran 0x0). | Helper mengatur ukuran dan posisi, lalu mengaktifkan window. |
| Semua profil memakai satu ikon dock. | Library preload kecil memberi tiap profil id window dan ikon sendiri. |
| Link login (`claude://`) membuka profil yang salah. | Router membuka link di profil yang memulai login. Guard menjaga setelan ini. |

Baca [docs/how-it-works.md](docs/how-it-works.md) untuk penyebabnya (dalam bahasa Inggris).

## Kebutuhan

- Zorin OS 18, atau distribusi lain dengan GNOME 45 sampai 51 di Wayland.
- Paket resmi `claude-desktop` (lihat "Pasang Claude Desktop").
- Paket: `git gcc python3 zenity libnotify-bin libglib2.0-bin xdg-utils desktop-file-utils`

```bash
sudo apt install git gcc python3 zenity libnotify-bin libglib2.0-bin xdg-utils desktop-file-utils
```

## Pasang Claude Desktop

Lewati bagian ini jika `claude-desktop` sudah terpasang.

```bash
sudo curl -fsSL https://downloads.claude.ai/keys/claude-code.asc \
  -o /usr/share/keyrings/claude-desktop-archive-keyring.asc
echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/claude-desktop-archive-keyring.asc] https://downloads.claude.ai/claude-desktop/apt/stable stable main" \
  | sudo tee /etc/apt/sources.list.d/claude-desktop.list
sudo apt update && sudo apt install claude-desktop
```

Cek fingerprint kunci. Nilainya harus `31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE`.

```bash
gpg --show-keys /usr/share/keyrings/claude-desktop-archive-keyring.asc
```

## Pasang

```bash
git clone https://github.com/RamaAditya49/zorin-claude-desktop-fix
cd zorin-claude-desktop-fix
./install.sh
```

Lalu logout dan login sekali. GNOME di Wayland baru memuat extension baru saat login.
Buka Claude dari ikon dock. Sekarang window muncul di setiap klik.

Installer aman dijalankan berulang kali.
Pakai `./install.sh --no-activate` untuk menyalin berkas saja. Opsi ini tidak menyentuh systemd, GNOME, atau handler `claude://`.

## Banyak profil

Tiap profil punya login dan folder data sendiri.
Profil 1 adalah Claude biasa (`~/.config/Claude`). Profil N memakai `~/.config/Claude-N`.

```bash
./install.sh --profiles 3
```

Perintah ini menyiapkan profil 1 sampai 3. Tiap profil 2 ke atas mendapat launcher di menu aplikasi, dengan ikon berwarna sendiri.
Pin launcher itu ke dock.

Nama profil ada di `~/.config/claude-profiles/profiles.conf`:

```
1 Claude
2 Kerja
3 Pribadi
```

Ubah namanya, lalu jalankan `./install.sh` lagi.
Nomor harus 1 sampai 9. Nama boleh sampai 60 karakter.

## Autostart

Jalankan `./install.sh --profiles 3 --autostart` untuk menjalankan profil 2 ke atas saat login.
Ini berguna bila profil punya tugas terjadwal.
Profil 1 memakai setelan autostart dari aplikasi itu sendiri.
Jalankan installer lagi tanpa `--autostart` untuk menghapus berkas autostart.

## Hapus

```bash
./uninstall.sh
```

Uninstaller hanya menghapus berkas dalam catatannya (`~/.local/share/claude-profiles/manifest`).
Uninstaller menyimpan folder data profil dan `profiles.conf`.
Kalau sebelum install kamu sudah punya `com.anthropic.Claude.desktop` sendiri di `~/.local/share/applications`, installer menyimpan salinannya dan uninstaller mengembalikannya.

## Cara cek

Lihat daftar window dan id-nya:

```bash
gdbus call --session --dest dev.avifenesh.ComputerUseLinux.WindowControl \
  --object-path /dev/avifenesh/ComputerUseLinux/WindowControl \
  --method dev.avifenesh.ComputerUseLinux.WindowControl.ListWindows
```

`wm_class` profil N harus `claude-desktop-N`.

| Log | Isi |
|-----|-----|
| `~/.cache/claude-profiles/raise.log` | Kejadian window |
| `~/.cache/claude-profiles/router.log` | Skema dan host link, serta profil yang dipilih |
| `~/.cache/claude-profiles/guard.log` | Perubahan yang dibuat guard |

## Masalah dan solusi

| Gejala | Cek | Solusi |
|--------|-----|--------|
| Klik ikon dock, window tidak muncul. | `gnome-extensions info computer-use-linux@avifenesh.dev` harus menulis `State: ACTIVE`. Baca `~/.cache/claude-profiles/raise.log`. | Jalankan `./install.sh` lagi. Logout lalu login. |
| Muncul pesan bahwa window macet. | Window tetap berukuran 0x0 setelah lima percobaan. | Klik kanan ikon Claude di system tray. Pilih Quit. Buka lagi dari dock. |
| Window profil 2 ke atas masuk ke ikon profil 1. | `wm_class` di `ListWindows`. | Buka profil dari launcher-nya sendiri, bukan dengan perintah `claude-desktop`. Jalankan `./install.sh` lagi. |
| Link login membuka profil yang salah. | `xdg-mime query default x-scheme-handler/claude` harus menulis `com.anthropic.Claude.desktop`. | Jalankan `~/.local/bin/claude-profiles-guard`. |
| Hasil edit launcher profil hilang. | Guard memulihkan launcher dari template. | Edit template di `~/.local/share/claude-profiles/desktop/`, lalu jalankan `./install.sh` lagi. |
| Ikon profil tidak berwarna. | Lihat `~/.local/share/icons/hicolor/`. | Jalankan `gtk-update-icon-cache -f -t ~/.local/share/icons/hicolor`. Logout lalu login. |
| Extension mati setelah upgrade GNOME. | `gnome-shell --version`. Extension mendukung GNOME 45 sampai 51. | Ambil versi baru dari proyek upstream (lihat `vendor/computer-use-linux@avifenesh.dev/UPSTREAM.md`). |

Profil 1 tetap memakai ikon Claude biasa. Ini benar.

## Setelah Claude Desktop update

1. Jalankan perintah `ListWindows` di atas.
2. Cek bahwa `wm_class` profil N adalah `claude-desktop-N`.
3. Jika path program Claude berubah, jalankan `./install.sh` lagi. Installer membangun library untuk path baru.
4. Jangan ubah berkas `app.asar` milik Claude. Update menimpanya.

## Catatan keamanan

- Library `LD_PRELOAD` aktif hanya di dalam program Claude. Di program lain library ini tidak berbuat apa-apa.
- Library mengubah satu pencarian environment (`CHROME_DESKTOP`). Library tidak memakai jaringan dan tidak mengumpulkan data.
- Log hanya menyimpan skema dan host link, misalnya `claude://claude.ai`. Log tidak pernah menyimpan path, query, atau token.
- Extension kontrol window membuka API D-Bus untuk setiap proses di sesi Anda. API itu menampilkan judul window dan dapat memindah serta mengaktifkan window.
  Periksa kode di `vendor/` sebelum Anda memasang.
- Installer menulis hanya di dalam folder home Anda. Uninstaller menolak path di luar folder itu.

## Kredit

Extension kontrol window `computer-use-linux@avifenesh.dev` berasal dari
[avifenesh/codex-desktop-linux](https://github.com/avifenesh/codex-desktop-linux) (lisensi MIT).
Repo ini memuat salinan tanpa perubahan. Lihat `vendor/computer-use-linux@avifenesh.dev/UPSTREAM.md`.

## Lisensi

MIT. Lihat [LICENSE](LICENSE).
