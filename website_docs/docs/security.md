---
sidebar_position: 5
title: Keamanan & Troubleshooting
---

# Keamanan & Troubleshooting

## 🛡️ Praktik Keamanan (Security Notes)

Aplikasi ini telah diperbaiki dari kerentanan lama. Untuk lingkungan produksi, patuhi standar berikut:

1. **Gunakan Environment Variables (`.env`)**: Kredensial database tidak boleh ditulis keras (hardcoded) di file PHP. Gunakan `.env`.
2. **Wajib HTTPS**: Selalu gunakan SSL/HTTPS untuk API server untuk mencegah intersepsi paket (*sniffing*).
3. **API Auth / Header Protection**: Pertimbangkan mengaktifkan Token JWT atau API Key sederhana di backend.
4. **Proteksi File SQL/Backup**: Pastikan file backup `.sql` tidak dapat diakses langsung oleh publik (misal dengan memblokir di `.htaccess` atau menyimpannya di luar folder `public_html`).
5. **Rate Limiting**: Lindungi endpoint API dari brute-force/abuse.

---

## 🔧 Troubleshooting Umum

### 1. Koneksi Timeout Saat Login
- Cek koneksi internet dari HP Anda.
- Pastikan IP Public / Domain Mikrotik Anda bisa di-ping.
- Pastikan service `www` (Port 80) / `www-ssl` di IP > Services Mikrotik sudah dalam status **aktif**.

### 2. Pesan Error "Username/Password Salah"
- Cek daftar user di Mikrotik (`/user print`).
- Pastikan user yang dipakai punya grup yang memiliki hak akses `api` dan `rest-api`. (Minimal read, write, api, rest-api).

### 3. Database Connection Failed di API
- Cek file `api/.env` di server Anda, pastikan host, nama database, user, dan password sudah benar.
- Pastikan user database (MySQL) memiliki *privileges* yang lengkap ke database `pppoe_monitor`.

### 4. API Return HTML / Muncul Kode Aneh
- Cek konfigurasi server web (Apache/Nginx).
- Jika menggunakan Apache, periksa file `.htaccess`.
- Pastikan PHP terinstall dan berfungsi dengan baik di server Anda. Jangan sampai kode PHP di-render sebagai teks biasa atau memunculkan halaman error HTML standar server.

### 5. Data User Terduplikasi / Hilang Saat Ganti Router
Jika Anda mengganti perangkat hardware Mikrotik (yang menyebabkan Router ID berubah), Anda harus me-*merge* data lama ke data baru.
Gunakan script `api/merge_router_ids.php` untuk menggabungkan data lama ke router ID baru:
```json
{
  "old_router_id": "RB-RouterOS@...",
  "new_router_id": "SERIAL_NUMBER",
  "merge_strategy": "newest"
}
```
