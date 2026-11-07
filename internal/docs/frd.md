---
type: frd
status: current        # draft | current | stale
updated: 2026-11-07
---

# FRD: zorin-claude-desktop-fix

## Konvensi

- Tulis tiap requirement dengan pola EARS. Lihat referensi EARS di skill `rama-aditya-workflows`.
- Satu baris berisi satu perilaku yang bisa diverifikasi.
- ID `FR-001` dan `NFR-001` tetap selamanya. Jangan pakai ulang ID yang sudah dihapus.
- Requirement yang tidak berlaku lagi memakai status `deprecated`. Jangan hapus barisnya.
- Kolom "Sumber" berisi ID spec yang menambah atau mengubah requirement itu.

## Launcher dan window

| ID | Pola | Requirement | Status | Sumber |
|----|------|-------------|--------|--------|
| FR-001 | Event-driven | When `claude-profile <N>` starts with no other argument, the launcher shall run `claude-profile-raise <N>`. | implemented | 20261107-public-release |
| FR-002 | Event-driven | When the profile window is hidden, at 0x0, or off screen, `claude-profile-raise` shall resize, centre, and activate the window through the window-control extension. | implemented | 20261107-public-release |
| FR-003 | Ubiquitous | The launcher shall store profile N of 2 or more in `$XDG_CONFIG_HOME/Claude-N`. | implemented | 20261107-public-release |
| FR-004 | Event-driven | When profile N of 2 or more starts, the launcher shall load `claude-app-id.so` with `CLAUDE_APP_ID=claude-desktop-N`. | implemented | 20261107-public-release |

## Link dan guard

| ID | Pola | Requirement | Status | Sumber |
|----|------|-------------|--------|--------|
| FR-005 | Event-driven | When a `claude://` link arrives, the router shall open it in the profile that started a sign-in in the last 600 seconds, else ask the user. | implemented | 20261107-public-release |
| FR-006 | Event-driven | When a launcher or a `claude://` handler changes, the guard shall restore the expected state and log each change. | implemented | 20261107-public-release |

## Install

| ID | Pola | Requirement | Status | Sumber |
|----|------|-------------|--------|--------|
| FR-007 | Event-driven | When the user runs `install.sh`, the installer shall record every installed file in the manifest. | implemented | 20261107-public-release |
| FR-008 | Event-driven | When the user runs `uninstall.sh`, the uninstaller shall remove only the files in the manifest. | implemented | 20261107-public-release |

## Kebutuhan non-fungsional

| ID | Pola | Requirement | Status | Sumber |
|----|------|-------------|--------|--------|
| NFR-001 | Ubiquitous | The repository shall contain no credential, token, or absolute home path. | implemented | 20261107-public-release |
| NFR-002 | Ubiquitous | The app-id library shall change `getenv("CHROME_DESKTOP")` only in the Claude Desktop executable. | implemented | 20261107-public-release |

## Pertanyaan terbuka

- Tidak ada.
