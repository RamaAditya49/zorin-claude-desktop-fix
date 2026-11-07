---
type: prd
status: current        # draft | current | stale
updated: 2026-11-07
---

# PRD: zorin-claude-desktop-fix

## Masalah

Di GNOME Wayland, klik ikon dock Claude Desktop sering tidak memunculkan window.
Window dari tray kadang muncul dengan ukuran 0x0, jadi tidak terlihat.
Pengguna dengan lebih dari satu profil melihat semua window di bawah satu ikon dock.

## Pengguna

| Persona | Kebutuhan utama | Konteks pakai |
|---------|-----------------|---------------|
| Pengguna Zorin OS dengan satu akun Claude | Window muncul saat ikon dock diklik | Desktop atau laptop, sesi Wayland |
| Pengguna dengan beberapa akun Claude | Tiap akun punya ikon dock dan login sendiri | Desktop kerja dengan akun kantor dan pribadi |

## Tujuan produk dan metrik sukses

| Tujuan | Metrik | Target |
|--------|--------|--------|
| Window selalu muncul dari klik dock | Kejadian "window tidak muncul" di log raise | 0 setelah install |
| Install sederhana | Jumlah perintah install | 1 perintah setelah clone |

## Fitur

| ID | Fitur | Prioritas | Status | FR terkait |
|----|-------|-----------|--------|------------|
| F-01 | Angkat window dari klik dock | must | live | FR-001, FR-002 |
| F-02 | Profil tambahan 2 sampai 9 dengan data dan login sendiri | should | live | FR-003 |
| F-03 | Ikon dock dan app id per profil | should | live | FR-004 |
| F-04 | Link `claude://` masuk ke profil yang tepat | should | live | FR-005 |
| F-05 | Guard menjaga setelan setelah update | should | live | FR-006 |
| F-06 | Install dan uninstall berbasis manifest | must | live | FR-007, FR-008 |
| F-07 | Autostart profil tambahan | could | live | FR-007 |

## Alur pengguna utama

1. Pengguna memasang Claude Desktop dari repo apt resmi.
2. Pengguna menjalankan `git clone` lalu `./install.sh`.
3. Pengguna logout dan login sekali.
4. Pengguna mengklik ikon dock Claude. Window muncul.

## Kebutuhan non-fungsional

| Area | Target yang bisa diukur |
|------|-------------------------|
| Performa | Window muncul kurang dari 3 detik setelah klik dock |
| Aksesibilitas | Tidak relevan. Tidak ada UI baru selain dialog zenity. |
| SEO | Tidak relevan. |
| Keamanan | Tanpa jaringan. Library hanya aktif di exe Claude. Log tanpa query string. |

## Di luar lingkup

- Perbaikan untuk KDE, X11 murni, atau Flatpak Claude.
- Susunan grid window.
- Paket `.deb`.

## Rilis

| Milestone | Isi | Target tanggal | Status |
|-----------|-----|----------------|--------|
| v0.1 publik | F-01 sampai F-07 | 2026-11-07 | building |

## Pertanyaan terbuka

- TBD: Apakah perlu rilis di extensions.gnome.org agar tidak bergantung pada extension pihak ketiga?

## Sumber fakta

- `internal/spec/20261107-public-release.md`
- README setup private maintainer, versi 2026-11-06
