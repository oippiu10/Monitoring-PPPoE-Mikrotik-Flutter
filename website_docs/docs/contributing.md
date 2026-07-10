---
sidebar_position: 11
title: Panduan Developer (Kontribusi)
---

# Panduan Developer & Kontribusi

Sistem ini terbuka untuk pengembangan lebih lanjut. Jika Anda adalah *developer* yang melanjutkan tugas ini (misalnya untuk adik tingkat atau tim IT ISP), bacalah panduan ini.

## Standar Koding (Clean Code)

Aplikasi ini sangat ketat dalam penerapan *Clean Code* dan arsitektur yang solid:
- Selalu gunakan **Provider** untuk menangani pertukaran data (state). Jangan pernah melakukan panggilan API berat langsung dari *StatelessWidget*.
- Ekstrak *Widget* yang berulang ke folder `lib/widgets/`.
- Jangan menggunakan *Print()* di environment *Production*. Gunakan `developer.log`.

## Cara Kompilasi (Build) Rilis

Sebelum Anda membagikan APK ke teknisi, pastikan Anda melakukan kompilasi dengan mode *Release* dan menghilangkan semua ikon debug:

```bash
# 1. Bersihkan cache build lama
flutter clean

# 2. Ambil dependensi terbaru
flutter pub get

# 3. Kompilasi menjadi APK siap pakai
flutter build apk --release --obfuscate --split-debug-info=./debug_info
```
*Catatan: Obfuscate sangat penting untuk menyandikan kode agar sulit dibongkar hacker.*

## Git Workflow
Kami menggunakan metode *branching* sederhana:
1. `main` : Hanya untuk versi rilis stabil.
2. `feature/*` : Buat *branch* baru (misal: `feature/odp-map`) untuk mencoba fitur eksperimental.

Setelah di-merge, perbarui nomor versi di `pubspec.yaml` sebelum merilis pembaruan via Auto Update System!
