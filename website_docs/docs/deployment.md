---
sidebar_position: 3
title: Deployment & Konfigurasi Mikrotik
---

# Panduan Deployment & Konfigurasi

Untuk skala *production* (penggunaan nyata), perhatikan langkah-langkah deployment berikut ini agar sistem berjalan aman dan optimal.

## 🖥️ Persiapan Server

**Server Backend:**
- PHP 7.4 atau lebih tinggi
- MySQL 5.7 atau MariaDB 10.3+
- Apache/Nginx Web Server
- SSL Certificate (Sangat direkomendasikan untuk production)

**Mikrotik Router:**
- RouterOS v7.9 atau lebih tinggi (wajib untuk dukungan REST API native)
- Port 80 / 443 terbuka untuk akses REST API

---

## ⚙️ Setup Database & Backend API

1. Create Database `pppoe_monitor` di panel MySQL / phpMyAdmin.
2. Import file `database_schema.sql` (bisa melalui CLI atau import tool).
3. Upload seluruh isi folder `api/` ke public html server (misal `/var/www/html/api/`).
4. Setup file `.env` di dalam folder api.
5. Set permissions folder API agar aman:
   ```bash
   chmod 755 *.php
   chown -R www-data:www-data .
   ```

---

## 🌐 Konfigurasi Mikrotik

Aplikasi ini tidak menggunakan SSH/Telnet, melainkan menggunakan **Mikrotik REST API** sebagai jalur komunikasi yang lebih cepat dan terstruktur.

:::danger Penting!
- Versi minimum RouterOS adalah **7.9**. Jika di bawah itu, update firmware Mikrotik Anda terlebih dahulu.
- User Mikrotik harus memiliki hak akses `api` dan `rest-api`.
:::

**Langkah Aktivasi:**

1. Masuk ke Mikrotik (Winbox/Terminal).
2. Pergi ke **IP > Services** > Enable `www` (Port 80) atau `www-ssl` (Port 443).
3. Pergi ke **System > Users** > Buat user dengan group `full` atau custom group yang mengizinkan policy: `api, rest-api, read, write`.

---

## 📱 Build & Deploy Flutter App

1. Buka file `lib/services/api_service.dart`.
2. Ubah base URL mengarah ke server API Anda (contoh: `https://api.cmmnetwork.online/`).
3. Build Release APK: 
   ```bash
   flutter build apk --release
   ```
4. Gunakan file APK yang dihasilkan (`build/app/outputs/flutter-apk/app-release.apk`) untuk dibagikan ke teknisi Anda.
