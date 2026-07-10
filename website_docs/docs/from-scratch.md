---
sidebar_position: 13
title: Pembuatan Dari Nol (From Scratch)
---

# Proses Pembuatan Sistem Dari Awal (From Scratch)

Bagi Anda yang penasaran bagaimana sistem kompleks ini dibangun dari nol (*scratch*), berikut adalah panduan langkah demi langkah proses pengembangannya (*Development Lifecycle*).

## Tahap 1: Persiapan Ekosistem (Database & PHP)

Semuanya dimulai dari memetakan kebutuhan arsitektur data. Router Mikrotik tidak bisa menyimpan data geografis, sehingga MySQL adalah pilihan mutlak.

1. **Pembuatan Skema SQL:**
   - Dibuat tabel `users` untuk menyimpan ekstensi profil pelanggan (No WA, ID ODP).
   - Dibuat tabel `payments` dengan relasi *Foreign Key* ke *users* dan *router_id*.
2. **Pembuatan Middleware (PHP):**
   - Agar Flutter bisa "berbicara" dengan MySQL, dibuatlah kerangka REST API menggunakan PHP.
   - Kami tidak membuat sistem dari nol untuk koneksi Mikrotik. Kami menggunakan *open-source library* **RouterOS API Class (PHP)** buatan Denis Basta untuk berkomunikasi via Port TCP 8728.
   - PHP bertugas men-sintesis perintah (misalnya: `\ip\address\print`) lalu mengubah hasilnya dari format *array* Mikrotik menjadi `JSON` murni yang siap dibaca oleh Dart/Flutter.

## Tahap 2: Merancang UI Flutter & Sistem State (Provider)

Setelah fondasi server kokoh, barulah pembangunan aplikasi *mobile* dimulai.

1. **Inisialisasi Flutter & Tema (Theming):**
   - Dibuat variabel warna sentral (`AppColors`) yang mendukung transisi mulus antara *Dark Mode* dan *Light Mode*.
   - Digunakan komponen visual *Glassmorphism* (kotak transparan dengan efek blur latar belakang `BackdropFilter`) agar UI tidak kaku.
2. **Setup Provider:**
   - Karena data PPPoE sering berubah, digunakan *State Management Provider*.
   - Saat pengguna menekan *refresh*, `Provider` akan melakukan HTTP GET Request ke server PHP. Begitu JSON kembali, `notifyListeners()` dipanggil agar UI tergambar ulang seketika.

## Tahap 3: Modul Kritis (Grafik Trafik & Peta)

1. **Grafik Trafik (Traffic Monitor):**
   - Menggunakan paket `fl_chart`. 
   - Aplikasi menyalakan *Timer* yang menembak API setiap 3 detik.
   - Setiap respon berisi `rx-byte` (Download) dan `tx-byte` (Upload). Sistem akan menghitung selisih *byte* per detik lalu mengubahnya ke satuan *Mbps (Megabit per second)*.
   - Angka Mbps ini didorong ke dalam koordinat X/Y grafik.
2. **Peta Interaktif (OpenStreetMap):**
   - Karena Google Maps memerlukan kunci API (*API Key*) berbayar, kami memutuskan menggunakan `flutter_map` dengan server *tile* OpenStreetMap yang 100% gratis.
   - Untuk mencegah HP menjadi *lag* saat merender 5.000 titik lokasi, digunakan algoritma *Clustering* (`flutter_map_marker_cluster`) yang akan menyatukan titik berdekatan menjadi satu gelembung angka, dan pecah kembali ketika peta di-*zoom in*.

## Tahap 4: Proses Finalisasi & Rilis (Production Build)

1. **Pengujian Edge-Cases:**
   - Menghidupkan *Airplane Mode* di HP saat aplikasi meminta data, untuk memastikan *Try-Catch Error Handling* memunculkan *Pop-Up* elegan, bukan aplikasi macet (*Force Close*).
2. **Kompilasi (Obfuscation):**
   - Kode Dart harus disandikan (*obfuscate*) agar tidak bisa di- *decompile* oleh pesaing ISP.
   - `flutter build apk --release --obfuscate --split-debug-info=./debug_info`
3. **Auto Update System:**
   - Dibuat logika agar saat aplikasi *Startup*, sistem menembak `/api/check_update.php`. Jika versi di server lebih tinggi dari `pubspec.yaml` lokal, muncul paksaan untuk mengunduh APK terbaru (Sistem OTA Mandiri).
