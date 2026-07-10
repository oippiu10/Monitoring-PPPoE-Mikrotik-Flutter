---
sidebar_position: 10
title: Konfigurasi Lanjut (.env)
---

# Konfigurasi Lingkungan (.env)

Agar sistem dapat berjalan dinamis di berbagai server dan perangkat, semua *hardcoded value* telah dipindahkan ke file *Environment Variables*.

## Konfigurasi Backend (API PHP)

Di server Anda, buat file bernama `.env` di dalam folder `/api/` dengan struktur berikut:

```ini
# ==== DATABASE CREDENTIALS ====
DB_HOST=localhost
DB_NAME=pppoe_monitor
DB_USER=pppoe_user
DB_PASS=SandiSangatRahasia!123

# ==== ROUTER CONFIGURATION ====
ROUTER_TIMEOUT=15         # Waktu maksimal tunggu respons (detik)
CACHE_LIFETIME=30         # Umur cache mikrotik (detik)

# ==== SECURITY ====
API_TOKEN=rahasia_token_123   # Gunakan jika Anda mengaktifkan proteksi API Header
DISABLE_PRUNE=true            # Set 'false' hanya saat butuh hapus massal dari server
```

## Konfigurasi Mobile (Flutter)

Aplikasi Flutter tidak membungkus variabel sensitif di dalam kode untuk mencegah *reverse-engineering*. Pengaturan domain API disimpan di:

```dart
// lib/services/api_service.dart
class ApiService {
  static const String BASE_URL = 'https://cmmnetwork.online/api/';
  
  // Ubah URL di atas saat Anda melakukan build untuk environment baru
}
```

:::warning Enkripsi Kredensial
Jangan pernah menyimpan password Mikrotik Anda secara manual ke dalam kode Flutter. Sistem kami menggunakan `flutter_secure_storage` untuk merantai dan mengenkripsi kredensial login di ruang aman perangkat Android (*Keystore*).
:::
