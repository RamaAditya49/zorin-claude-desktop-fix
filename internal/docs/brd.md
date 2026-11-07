---
type: brd
status: current        # draft | current | stale
updated: 2026-11-07
---

# BRD: zorin-claude-desktop-fix

## Latar bisnis

Claude Desktop untuk Linux punya bug di GNOME Wayland. Klik ikon dock sering tidak memunculkan window.
Rama memperbaikinya untuk dirinya sendiri pada 2026-11-06, lalu memutuskan membagikannya sebagai open source pada 2026-11-07.

## Tujuan bisnis

| ID | Tujuan | Ukuran | Target | Tenggat |
|----|--------|--------|--------|---------|
| BG-01 | Bantu pengguna Zorin OS dan GNOME memakai Claude Desktop tanpa window hilang | Repo publik bisa dipasang dari README | Rilis pertama | 2026-11-07 |

## Stakeholder

| Peran | Kepentingan | PIC |
|-------|-------------|-----|
| Pemilik repo | Reputasi open source, perbaikan dipakai orang lain | Rama Aditya |
| Pengguna Claude Desktop di GNOME Wayland | Window muncul saat ikon dock diklik | Publik |

## Model bisnis

Proyek open source tanpa pendapatan langsung. Lisensi MIT.

## Aturan bisnis

| ID | Aturan | Sumber |
|----|--------|--------|
| BR-001 | Repo publik tidak boleh memuat kredensial atau path pribadi | Permintaan Rama, 2026-11-07 |
| BR-002 | Repo tidak membawa aset merek Anthropic | Keputusan rilis 2026-11-07 |
| BR-003 | Repo baru, terpisah dari setup private maintainer | Permintaan Rama, 2026-11-07 |

## KPI

| KPI | Target | Cara ukur | Alat |
|-----|--------|-----------|------|
| TBD | TBD | TBD | GitHub Insights |

## Asumsi dan batasan

- Pengguna memakai paket resmi `claude-desktop`.
- Pengguna memakai GNOME 45 sampai 51 di Wayland.

## Risiko bisnis

- Update Claude Desktop mengubah cara app id dibuat → profil kembali ke satu ikon, app tetap jalan. README menjelaskan cara cek.
- Anthropic memperbaiki bug ini secara resmi → repo tidak dibutuhkan lagi. Arsipkan repo.

## Pertanyaan terbuka

- TBD: KPI apa yang Rama mau pantau (star, issue, clone)?

## Sumber fakta

- Permintaan Rama, 2026-11-07: repo publik baru bernama zorin-claude-desktop-fix, tanpa kredensial dan tanpa path tetap.
