---
sidebar_position: 12
title: Riwayat Pembaruan (Changelog)
---

# Riwayat Pembaruan (*Changelog*)

Dokumentasi mengenai perubahan sistem, fitur baru, dan perbaikan *bug*.

## [v1.0.16] - Versi Skripsi Final (2026)

### ✨ Fitur Baru
- **Auto Update System**: Pembaruan sistem OTA tanpa *PlayStore*.
- **Peta Interaktif Glassmorphism**: Pembaruan total UI *Customer Map* dengan efek kaca.
- **Filter Tagihan "Titipan"**: Kemampuan untuk mencatat dan menyortir tagihan *titipan* atau uang muka.
- **Log Keuangan Audit**: Perekaman data perubahan tagihan/pembayaran demi keandalan.

### 🐛 Bug Fixes
- ✅ **Infinite Render Loop**: Mengatasi masalah browser *freeze* saat berpindah bulan pada panel pengeluaran.
- ✅ **Duplikasi Router ID**: Penyempurnaan sinkronisasi P2P antar-server dan pencegahan duplikat pelanggan saat pergantian *hardware* Mikrotik.

---

## [v1.0.9+10] - CRUD PPPoE Profile (Feb 2026)

### ✨ Fitur Baru
- **Tambah Profile Baru**: Form lengkap dengan validasi untuk mencegah duplikasi (support *session timeout, idle timeout*, dan *only-one*).
- **Edit & Hapus Profile**: Pencegahan penghapusan profile *default* atau profile yang sedang dipakai oleh pelanggan.

### 🐛 Bug Fixes
- ✅ Fix `ProviderNotFoundException` saat melakukan penghapusan profil.
- ✅ Perbaikan integrasi konteks menggunakan `parentContext` saat form *overlay* aktif.
- ✅ Standarisasi endpoint API *Delete* (sekarang memakai HTTP Method `DELETE`).
