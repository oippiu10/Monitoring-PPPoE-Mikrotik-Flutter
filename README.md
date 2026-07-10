# 📡 Mikrotik-PPPoE-Monitor

> [!IMPORTANT]
> **📚 DOKUMENTASI RESMI TERBARU**  
> Kami telah merilis website dokumentasi resmi yang jauh lebih rapi, terstruktur, dan super lengkap (termasuk Arsitektur Sistem, Tutorial Penggunaan, & API Reference).
> 👉 **[BACA DOKUMENTASI LENGKAP DI SINI](https://oippiu10.github.io/Monitoring-PPPoE-Mikrotik-Flutter/)** 👈

---

![Flutter](https://img.shields.io/badge/Flutter-3.0%2B-blue?style=for-the-badge&logo=flutter)
![Platform](https://img.shields.io/badge/Platform-Android-green?style=for-the-badge&logo=android)
![License](https://img.shields.io/badge/License-GPL--3.0-red?style=for-the-badge)
![Status](https://img.shields.io/badge/Status-Active-success?style=for-the-badge)
[![Download APK](https://img.shields.io/badge/Download-APK-blue?style=for-the-badge&logo=android)](https://cmmnetwork.online/api/download.php)

## 🌐 Website & Download

Dapatkan versi terbaru, tutorial, dan informasi lainnya di website resmi kami:

# [🔗 CMMNETWORK.ONLINE](https://cmmnetwork.online)

---

Aplikasi monitoring user PPPoE Mikrotik berbasis Flutter dan REST API. Memudahkan monitoring, manajemen, dan analisis user PPPoE secara real-time. Dibuat untuk tugas akhir/skripsi dan kebutuhan monitoring jaringan.

---

## Daftar Isi

1.  [Fitur Utama](#fitur-utama)
2.  [Teknologi yang Digunakan](#teknologi-yang-digunakan)
3.  [Struktur Project](#struktur-project)
4.  [Mulai Cepat (Quick Start)](#mulai-cepat-quick-start)
5.  [Panduan Deployment](#panduan-deployment)
6.  [Konfigurasi Mikrotik](#konfigurasi-mikrotik)
7.  [Fitur & Panduan Penggunaan](#fitur--panduan-penggunaan)
    - [Auto Update System](#auto-update-system)
    - [Router Image Feature](#router-image-feature)
    - [Auto Backup Feature](#auto-backup-feature)
    - [API Billing & Fixes](#api-billing--fixes)
    - [Penanganan Duplikasi Data](#penanganan-duplikasi-data)
    - [Perlindungan & Pemulihan Data](#perlindungan--pemulihan-data)
8.  [Keamanan (Security Notes)](#keamanan-security-notes)
9.  [Troubleshooting](#troubleshooting)
10. [Ringkasan Perbaikan](#ringkasan-perbaikan)
11. [Galeri Screenshot](#galeri-screenshot)
12. [Lisensi & Pengembang](#lisensi--pengembang)

---

## Fitur Utama

- **Monitoring User PPPoE**: Lihat daftar user aktif, status koneksi, profil, dan detail user secara real-time.
- **Manajemen User**: Tambah, edit, dan hapus user PPPoE langsung dari aplikasi.
- **Customer Map Interaktif**: Peta lokasi pelanggan dengan fitur navigasi, pencarian, dan filter paket.
- **Integrasi REST API**: Komunikasi dengan perangkat Mikrotik menggunakan REST API yang aman dan efisien.
- **Log & Statistik**: Tersedia log aktivitas dan statistik penggunaan untuk analisis jaringan.
- **UI Modern (Glassmorphism)**: Tampilan premium dengan efek kaca, mendukung dark mode, dan responsif.
- **Notifikasi & Error Handling**: Penanganan error yang informatif dan notifikasi status aksi.
- **Manajemen Pembayaran**: Fitur billing untuk mencatat dan melacak pembayaran user.
- **Manajemen ODP**: Integrasi dengan Optical Distribution Point untuk pelacakan lokasi user.
- **Export Data**: Ekspor data user dan pembayaran ke format Excel dan PDF.
- **Auto Update System**: System update otomatis tanpa perlu membagikan APK secara manual.

---

## Teknologi yang Digunakan

- **Flutter** (Dart)
- **Provider** (state management)
- **REST API** (komunikasi dengan Mikrotik)
- **Material Design**
- **HTTP Client** (untuk komunikasi dengan backend)
- **Image Picker** (untuk upload foto lokasi)
- **PDF Generator** (untuk export laporan)

---

## Struktur Project

Berikut adalah struktur direktori utama project ini:

```
mikrotik_monitor/
├── api/                    # Backend PHP scripts
│   ├── config.php          # Database configuration
│   ├── check_update.php    # Auto update logic
│   └── ...                 # Other API endpoints
├── assets/                 # Static assets
│   ├── router_images_online.json # Router image mapping
│   └── ...                 # Images & icons
├── lib/                    # Flutter source code
│   ├── models/             # Data models
│   ├── providers/          # State management
│   ├── screens/            # UI Screens
│   ├── services/           # API & Logic services
│   ├── widgets/            # Reusable widgets
│   └── main.dart           # Entry point
├── database_schema.sql     # Database structure
├── pubspec.yaml            # Dependencies
└── README.md               # Documentation
```

---

## Mulai Cepat (Quick Start)

Panduan cepat untuk mulai menggunakan aplikasi dalam 15 menit!

### Prerequisites

- Mikrotik Router (RouterOS 7.9+)
- Web Server dengan PHP & MySQL
- Android Device untuk testing

### Setup dalam 5 Langkah

#### 1. Setup Database (3 menit)

Login ke MySQL dan import schema:

```bash
mysql -u root -p < database_schema.sql
```

Buat user database:

```sql
CREATE USER 'pppoe_user'@'localhost' IDENTIFIED BY 'password123';
GRANT ALL PRIVILEGES ON pppoe_monitor.* TO 'pppoe_user'@'localhost';
FLUSH PRIVILEGES;
```

#### 2. Configure Backend (2 menit)

Masuk ke folder api dan buat file .env:

```bash
cd api
# Buat file .env dengan isi:
DB_HOST=localhost
DB_NAME=pppoe_monitor
DB_USER=pppoe_user
DB_PASS=password123
```

Set permissions: `chmod 600 .env`

#### 3. Configure Mikrotik (3 menit)

Login ke Mikrotik dan aktifkan REST API:

```bash
/ip service set www port=80 disabled=no
/user add name=api_user password=api123456 group=full
```

#### 4. Build Flutter App (5 menit)

Update API URL di `lib/services/api_service.dart` jika perlu.
Clean & build:

```bash
flutter clean
flutter pub get
flutter build apk --release
```

#### 5. First Login (2 menit)

Buka aplikasi, masukkan credentials (IP Mikrotik, Port 80, Username api_user, Password api123456), lalu klik Login.

---

## Panduan Deployment

### Persiapan Server

**Server Backend:**

- PHP 7.4 atau lebih tinggi
- MySQL 5.7 atau MariaDB 10.3+
- Apache/Nginx Web Server
- SSL Certificate (recommended untuk production)

**Mikrotik Router:**

- RouterOS v7.9 atau lebih tinggi (untuk REST API support)
- Port 80/443 terbuka untuk REST API

### Setup Database

1.  Create Database `pppoe_monitor`.
2.  Import `database_schema.sql`.
3.  Create dedicated user database (jangan pakai root).

### Konfigurasi Backend API

1.  Upload folder `api` ke server (misal `/var/www/html/api`).
2.  Setup `.env` file di dalam folder api.
3.  Set permissions `chmod 755 *.php` dan `chown -R www-data:www-data .`.

### Build & Deploy Flutter App

1.  Update `lib/services/api_service.dart` dengan URL production.
2.  Build Release APK: `flutter build apk --release`.
3.  Setup Signing (Keystore) untuk production build.

---

## Konfigurasi Mikrotik

Aplikasi ini menggunakan **Mikrotik REST API** sebagai jalur komunikasi.

**Penting:**

- Versi minimum RouterOS: **7.9**
- Port default: **80** (HTTP) atau **443** (HTTPS)
- User harus memiliki hak akses **api** dan **rest-api**.

**Langkah Aktivasi:**

1.  Masuk ke Mikrotik.
2.  IP > Services > Enable `www` atau `www-ssl`.
3.  System > Users > Buat user dengan group `full` atau custom group dengan policy `api, rest-api, read, write`.

---

## Fitur & Panduan Penggunaan

### Auto Update System

Sistem auto update memungkinkan aplikasi mendeteksi dan mengunduh pembaruan APK dari server secara otomatis.

**Komponen:**

- Backend: `api/check_update.php`
- Frontend: `UpdateService`, `UpdateDialog`

**Cara Release Update Baru:**

1.  Update version di `pubspec.yaml`.
2.  Update `api/check_update.php` dengan versi baru dan release notes.
3.  Build APK baru.
4.  Upload APK ke server (`/files/app-release.apk`).

### Router Image Feature

Menampilkan gambar router resmi dari Mikrotik berdasarkan model router yang terdeteksi.

- Menggunakan URL resmi dari CDN Mikrotik.
- Support 264+ model router (CCR, RB, hEX, dll).
- Otomatis mendeteksi berdasarkan `board-name`.
- Memiliki mekanisme fallback jika gambar tidak ditemukan.

**Debug Router Image:**
Jika gambar tidak muncul, cek `assets/router_images_online.json` dan pastikan koneksi internet tersedia. Cek console log untuk error message.

### Auto Backup Feature

Fitur backup otomatis untuk melindungi data.

- **Automatic Backup**: Backup SQL full dibuat otomatis sebelum sinkronisasi.
- **Scheduled Backups**: Harian (02:00) dan Mingguan (Minggu 03:00).
- **Manual Backup**: Bisa dipicu user dari menu Database Setting Database.
- **Lokasi**: Folder Download di device (`pppoe-full-backup-[router-id]-....sql`).

### API Billing & Fixes

Sistem billing telah diperbaiki untuk menangani error dengan lebih baik.

- **Endpoint**: `api/payment_summary_operations.php`
- **Fixes**: Type casting safe, timeout handling (15s), error messages yang user-friendly.
- **Database**: Tabel `payments` dengan `router_id`.

### Penanganan Duplikasi Data

Jika terjadi duplikasi user karena perubahan Router ID (misal update firmware atau ganti hardware).

**Cara Fix:**
Gunakan script `api/merge_router_ids.php` untuk menggabungkan data lama ke router ID baru.

**Request:**
POST ke `api/merge_router_ids.php`

```json
{
  "old_router_id": "RB-RouterOS@...",
  "new_router_id": "SERIAL_NUMBER",
  "merge_strategy": "newest"
}
```

### Perlindungan & Pemulihan Data

**Masalah Lama**: Sinkronisasi menghapus data tambahan (WA, Lokasi) dan billing.
**Solusi Baru**:

- Sinkronisasi rutin **MEMPERTAHANKAN** data tambahan.
- Fitur "Prune" (hapus data yang tidak ada di Mikrotik) diproteksi dan butuh konfirmasi.
- Backup otomatis tabel `users` dan `payments` sebelum operasi berbahaya.

**Recovery**:
Gunakan API `api/restore_backup.php` atau `api/recover_billing_data.php` untuk mengembalikan data dari backup server.

---

## Fitur Customer Map

Peta interaktif untuk memantau sebaran pelanggan.

**Fitur Unggulan:**

- **Boxed Map UI**: Tampilan peta dalam kotak elegan dengan efek bayangan.
- **Glassmorphism Controls**: Tombol kontrol dan search bar dengan efek kaca buram (blur).
- **Navigasi (Ambil Rute)**: Buka Google Maps langsung ke lokasi pelanggan dari aplikasi.
- **Smart Search**: Cari pelanggan berdasarkan Nama atau Username.
- **Filter Paket**: Filter marker di peta berdasarkan paket internet yang digunakan.
- **Full Screen Mode**: Mode layar penuh untuk tampilan peta yang lebih luas.

---

## Keamanan (Security Notes)

**Isu Kritis yang Telah Diperbaiki:**

- Database credentials tidak lagi hardcoded (menggunakan `.env`).
- File sensitif dihapus dari git history.

**Rekomendasi Keamanan (Wajib untuk Production):**

1.  **HTTPS**: Wajib gunakan HTTPS untuk API server.
2.  **API Auth**: Implementasikan API Key atau JWT untuk melindungi endpoint API.
3.  **SQL Injection**: Pastikan semua query menggunakan prepared statements.
4.  **Keystore**: Generate keystore baru untuk production signing.
5.  **Rate Limiting**: Implementasikan rate limiting di API untuk mencegah abuse.

---

## Troubleshooting

**Koneksi Timeout:**

- Cek koneksi internet.
- Pastikan IP Mikrotik benar dan bisa di-ping.
- Pastikan service `www` di Mikrotik aktif.

**Username/Password Salah:**

- Cek user di Mikrotik (`/user print`).
- Pastikan user punya hak akses API.

**Database Connection Failed:**

- Cek file `api/.env` di server.
- Pastikan user database memiliki privileges yang benar.

**API Return HTML:**

- Cek konfigurasi server web (Apache/Nginx).
- Cek `.htaccess`.
- Pastikan tidak ada error PHP yang ter-output sebagai HTML.

**Refresh Analyzer (VSCode):**
Jika ada error palsu di IDE, jalankan `Dart: Restart Analysis Server` atau `flutter clean`.

---

## Ringkasan Perbaikan

**Oktober 2024**

- Fixed Merge Conflict di `odp_operations.php`.
- Removed duplicate & temporary files.
- Added Environment Variable support.
- Created Database Schema.
- Fixed Cache Implementation Bug.
- Created Comprehensive Documentation.

**November 2025**

- Fixed Duplicate Data issue (Merge Router ID).
- Updated Router Image feature (JSON based).

**Januari 2026**

- **Customer Map Upgrade**: Navigasi, Search, Filter, & UI Redesign.
- **UI Overhaul**: Implementasi Glassmorphism pada komponen peta.
- **Performance**: Optimasi rendering marker dengan clustering.

---

## Galeri Screenshot

### Halaman Login

<p align="center">
  <img src="https://raw.githubusercontent.com/hasanmahfudh11211/Monitoring-PPPoE-Mikrotik-Flutter/main/screenshot/login.jpg" width="300" alt="Halaman Login"/>
  <img src="https://raw.githubusercontent.com/hasanmahfudh11211/Monitoring-PPPoE-Mikrotik-Flutter/main/screenshot/login2.jpg" width="300" alt="Koneksi Tersimpan"/>
</p>
<p align="center"><i>Tampilan untuk memasukkan kredensial Mikrotik dan daftar koneksi yang tersimpan.</i></p>

### Halaman Dashboard

<p align="center">
  <img src="https://raw.githubusercontent.com/hasanmahfudh11211/Monitoring-PPPoE-Mikrotik-Flutter/main/screenshot/dashboard.jpg" width="300" alt="Dashboard Light Mode"/>
  <img src="https://raw.githubusercontent.com/hasanmahfudh11211/Monitoring-PPPoE-Mikrotik-Flutter/main/screenshot/dashboard-dark.jpg" width="300" alt="Dashboard Dark Mode"/>
</p>
<p align="center"><i>Dashboard utama yang menampilkan ringkasan informasi, dengan dukungan tema terang dan gelap.</i></p>

### Halaman Tambah User

<p align="center">
  <img src="https://raw.githubusercontent.com/hasanmahfudh11211/Monitoring-PPPoE-Mikrotik-Flutter/main/screenshot/tambah-user.jpg" width="300" alt="Tambah User"/>
</p>
<p align="center"><i>Formulir untuk menambahkan user PPPoE baru ke perangkat Mikrotik.</i></p>

### Halaman System Resource

<p align="center">
  <img src="https://raw.githubusercontent.com/hasanmahfudh11211/Monitoring-PPPoE-Mikrotik-Flutter/main/screenshot/system-resource.jpg" width="300" alt="System Resource"/>
</p>
<p align="center"><i>Monitor penggunaan CPU, memori, dan uptime perangkat Mikrotik secara real-time.</i></p>

### Halaman Traffic

<p align="center">
  <img src="https://raw.githubusercontent.com/hasanmahfudh11211/Monitoring-PPPoE-Mikrotik-Flutter/main/screenshot/traffic-online.jpg" width="300" alt="Traffic Online"/>
  <img src="https://raw.githubusercontent.com/hasanmahfudh11211/Monitoring-PPPoE-Mikrotik-Flutter/main/screenshot/traffic-offline.jpg" width="300" alt="Traffic Offline"/>
</p>
<p align="center"><i>Grafik lalu lintas jaringan untuk user yang sedang online dan riwayat traffic user.</i></p>

### Halaman User PPP

<p align="center">
  <img src="https://raw.githubusercontent.com/hasanmahfudh11211/Monitoring-PPPoE-Mikrotik-Flutter/main/screenshot/user-ppp.jpg" width="300" alt="User PPP"/>
</p>
<p align="center"><i>Menampilkan daftar semua user PPPoE yang terdaftar di perangkat.</i></p>

### Halaman Log

<p align="center">
  <img src="https://raw.githubusercontent.com/hasanmahfudh11211/Monitoring-PPPoE-Mikrotik-Flutter/main/screenshot/log.jpg" width="300" alt="Log"/>
</p>
<p align="center"><i>Catatan log aktivitas yang terjadi pada sistem Mikrotik untuk keperluan audit.</i></p>

---

## Lisensi & Pengembang

**Lisensi**: GPL-3.0

**Pengembang**:

- Hasan Mahfudh / Husein Braithweittt
- Email: hasanmahfudh112@gmail.com
- Instagram: @hasan.mhfdz
