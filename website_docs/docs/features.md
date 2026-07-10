---
sidebar_position: 4
title: Penjelasan Fitur Unggulan
---

# Penjelasan Fitur Unggulan

Pelajari bagaimana sistem Mikrotik Monitor menangani otomatisasi dan visualisasi jaringan tingkat lanjut.

## 🔄 Auto Update System

Sistem auto update memungkinkan aplikasi mendeteksi dan mengunduh pembaruan APK dari server secara otomatis. Teknisi lapangan tidak perlu mengunduh ulang APK secara manual setiap ada perbaikan bug.

**Komponen:**
- Backend: `api/check_update.php`
- Frontend: `UpdateService`, `UpdateDialog`

**Cara Release Update Baru:**
1. Update version code di `pubspec.yaml` (misal dari 1.0.8 ke 1.0.9).
2. Update `api/check_update.php` dengan versi baru dan release notes.
3. Build APK baru (`flutter build apk --release`).
4. Upload APK ke server pada path yang sudah ditentukan (misal `/files/app-release.apk`). Aplikasi klien akan otomatis mendeteksi pembaruan pada saat dibuka.

---

## 🖼️ Router Image Feature

Menampilkan gambar asli hardware router dari Mikrotik berdasarkan model router yang terdeteksi saat login.

- Menggunakan URL gambar resolusi tinggi resmi dari CDN Mikrotik.
- Mendukung 264+ model router (Seri CCR, RB, hEX, hAP, dll).
- Otomatis mendeteksi string `board-name` dari perangkat.
- Memiliki mekanisme *fallback* jika gambar tidak ditemukan atau internet lambat.

---

## 💾 Auto Backup Feature

Fitur backup otomatis untuk melindungi database tagihan dan data master dari kehilangan.

- **Automatic Backup**: Backup SQL dibuat secara otomatis tepat sebelum sinkronisasi data besar-besaran dilakukan.
- **Scheduled Backups**: Harian (02:00) dan Mingguan (Minggu 03:00).
- **Manual Backup**: Dapat dipicu administrator dari menu Settings > Database.
- **Lokasi Penyimpanan**: Disimpan rapi dan dapat diunduh (contoh format: `pppoe-full-backup-[router-id]-....sql`).

---

## 💰 API Billing & Manajemen Pembayaran

Sistem billing dirancang khusus untuk operasional ISP dengan tingkat keandalan yang tinggi.

- **Handling Error yang Baik**: Timeout handling (15s), type-casting aman, dan pesan error ramah pengguna (user-friendly).
- **Keamanan Data**: Data pembayaran (tabel `payments`) terkait erat dengan `router_id` sehingga multi-router terisolasi dengan rapi.
- **Prune Protection**: Perlindungan data, di mana sinkronisasi profil tidak akan menghapus data tagihan yang sudah tersimpan.

---

## 🗺️ Customer Map (Glassmorphism)

Peta interaktif untuk memantau sebaran pelanggan.

**Fitur Unggulan:**
- **Boxed Map UI**: Tampilan peta dalam kotak elegan dengan efek bayangan.
- **Glassmorphism Controls**: Tombol kontrol dan search bar dengan efek kaca buram (blur).
- **Navigasi (Ambil Rute)**: Buka Google Maps langsung ke lokasi pelanggan (ODP/Rumah) dari aplikasi.
- **Smart Search**: Cari pelanggan berdasarkan Nama atau Username PPPoE.
- **Filter Paket**: Filter marker pelanggan di peta berdasarkan paket bandwidth/layanan yang digunakan.
