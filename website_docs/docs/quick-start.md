---
sidebar_position: 2
title: Mulai Cepat (Quick Start)
---

# Mulai Cepat (Quick Start)

Panduan cepat untuk mulai menggunakan aplikasi dalam 15 menit!

## 📌 Prerequisites

Sebelum memulai, pastikan Anda telah menyiapkan:
- Perangkat Mikrotik Router (RouterOS 7.9+)
- Web Server (Apache/Nginx) dengan PHP & MySQL
- Android Device untuk testing (atau Emulator)

---

## 🚀 Setup dalam 5 Langkah

### 1. Setup Database (3 menit)

Login ke MySQL server Anda dan jalankan import schema database:

```bash
mysql -u root -p < database_schema.sql
```

Buat user khusus untuk database (hindari menggunakan root):

```sql
CREATE USER 'pppoe_user'@'localhost' IDENTIFIED BY 'password123';
GRANT ALL PRIVILEGES ON pppoe_monitor.* TO 'pppoe_user'@'localhost';
FLUSH PRIVILEGES;
```

### 2. Configure Backend (2 menit)

Masuk ke folder `api` di project web server Anda dan buat file `.env`:

```bash
cd api
# Buat file .env dengan isi:
DB_HOST=localhost
DB_NAME=pppoe_monitor
DB_USER=pppoe_user
DB_PASS=password123
```

:::warning Keamanan
Pastikan untuk mengatur file permissions: `chmod 600 .env` agar tidak bisa dibaca publik.
:::

### 3. Configure Mikrotik (3 menit)

Login ke Mikrotik Anda (via Winbox/Terminal) dan aktifkan REST API:

```bash
/ip service set www port=80 disabled=no
/user add name=api_user password=api123456 group=full
```

### 4. Build Flutter App (5 menit)

Buka source code Flutter di VSCode/Android Studio.
Update API URL di `lib/services/api_service.dart` agar mengarah ke domain server backend Anda.

Lalu jalankan clean dan build:

```bash
flutter clean
flutter pub get
flutter build apk --release
```

### 5. First Login (2 menit)

Buka aplikasi di Android, masukkan credentials Mikrotik Anda:
- IP Mikrotik
- Port (contoh: 80)
- Username: `api_user`
- Password: `api123456`

Lalu klik **Login**. Aplikasi siap digunakan!
