# 🚀 DEPLOYMENT GUIDE - WEB ADMIN PANEL

## 📋 Langkah-langkah Deploy ke Production

### 1. **Upload Files ke Server**

Upload folder `web/` ke server production:

```bash
# Via FTP/SFTP atau File Manager cPanel
Upload folder: web/
Destination: /public_html/web/

# Struktur di server:
/public_html/
├── web/
│   ├── api/
│   │   ├── config.php
│   │   ├── dashboard_stats.php
│   │   └── auth/
│   │       ├── login.php
│   │       ├── logout.php
│   │       └── check_session.php
│   ├── assets/
│   ├── login.html
│   └── dashboard.html
```

---

### 2. **Setup Database**

#### Option A: Via phpMyAdmin

1. Login ke phpMyAdmin
2. Pilih database `pppoe_monitor`
3. Klik tab "SQL"
4. Copy-paste isi file `web/setup_web_admin.sql`
5. Klik "Go" untuk execute

#### Option B: Via MySQL Command Line

```bash
mysql -u root -p pppoe_monitor < web/setup_web_admin.sql
```

#### Option C: Via cPanel

1. Login cPanel
2. Buka "phpMyAdmin"
3. Pilih database `pppoe_monitor`
4. Import file `setup_web_admin.sql`

---

### 3. **Konfigurasi Database**

Edit file `web/api/config.php` sesuai dengan kredensial database production:

```php
<?php
// Database configuration
$host = '127.0.0.1';  // atau 'localhost'
$db   = 'pppoe_monitor';
$user = 'your_db_user';      // ← Ganti dengan user database Anda
$pass = 'your_db_password';  // ← Ganti dengan password database Anda

$conn = new mysqli($host, $user, $pass, $db);
if ($conn->connect_error) {
    http_response_code(500);
    die(json_encode([
        'success' => false,
        'message' => 'Database connection failed'
    ]));
}
mysqli_set_charset($conn, 'utf8mb4');
?>
```

**PENTING:** Jangan lupa ganti `your_db_user` dan `your_db_password`!

---

### 4. **Set Permissions**

Pastikan file permissions sudah benar:

```bash
# Via SSH
chmod 755 web/api/*.php
chmod 755 web/api/auth/*.php
chmod 644 web/*.html

# Via cPanel File Manager
# Klik kanan file → Change Permissions
# PHP files: 755
# HTML files: 644
```

---

### 5. **Test Login**

1. Buka browser
2. Akses: `https://cmmnetwork.online/web/login.html`
3. Login dengan:
   - **Username:** `admin`
   - **Password:** `admin123`
4. Jika berhasil, akan redirect ke dashboard

---

## 🐛 Troubleshooting

### Error: "Terjadi kesalahan koneksi"

**Penyebab:**

- Database belum dibuat
- Kredensial database salah
- Table `admin_users` belum ada

**Solusi:**

1. Cek file `web/api/config.php`
2. Pastikan database credentials benar
3. Jalankan `setup_web_admin.sql`
4. Cek error log di cPanel

---

### Error: "Username tidak ditemukan"

**Penyebab:**

- Table `admin_users` kosong
- Default admin belum diinsert

**Solusi:**

```sql
-- Jalankan di phpMyAdmin:
INSERT INTO admin_users (username, password, email, full_name, role)
VALUES (
    'admin',
    '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi',
    'admin@cmmnetwork.online',
    'Administrator',
    'admin'
);
```

---

### Error: 500 Internal Server Error

**Penyebab:**

- PHP error
- File permissions salah
- Path config.php salah

**Solusi:**

1. Cek error log: `/public_html/error_log`
2. Set permissions: `chmod 755 *.php`
3. Cek path di `login.php`: `require_once __DIR__ . '/../config.php';`

---

### Dashboard Tidak Tampil Data

**Penyebab:**

- API `dashboard_stats.php` error
- Database query gagal
- Table `users` atau `payments` tidak ada

**Solusi:**

1. Buka: `https://cmmnetwork.online/web/api/dashboard_stats.php`
2. Lihat response JSON
3. Cek error message
4. Pastikan table `users` dan `payments` ada

---

## ✅ Checklist Deployment

- [ ] Upload folder `web/` ke server
- [ ] Edit `web/api/config.php` dengan kredensial database
- [ ] Jalankan `setup_web_admin.sql` di phpMyAdmin
- [ ] Set file permissions (755 untuk PHP, 644 untuk HTML)
- [ ] Test akses `https://cmmnetwork.online/web/login.html`
- [ ] Test login dengan admin/admin123
- [ ] Verify dashboard tampil data
- [ ] Test logout
- [ ] Test remember me

---

## 🔐 Security Checklist

- [ ] Ganti password default admin
- [ ] Gunakan HTTPS (sudah ada di cmmnetwork.online)
- [ ] Backup database sebelum deploy
- [ ] Set strong database password
- [ ] Disable directory listing
- [ ] Enable error logging (jangan tampilkan ke user)

---

## 📞 Support

Jika masih ada error:

1. Screenshot error message
2. Cek file `/public_html/error_log`
3. Test API endpoint langsung:
   - `https://cmmnetwork.online/web/api/auth/login.php`
   - `https://cmmnetwork.online/web/api/dashboard_stats.php`

---

## 🎯 Quick Fix Commands

### Reset Admin Password

```sql
UPDATE admin_users
SET password = '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi'
WHERE username = 'admin';
-- Password: admin123
```

### Check Tables

```sql
SHOW TABLES LIKE 'admin_%';
SELECT * FROM admin_users;
```

### Test Database Connection

```php
<?php
// test_db.php
$conn = new mysqli('127.0.0.1', 'user', 'pass', 'pppoe_monitor');
echo $conn->connect_error ? 'Failed' : 'Success';
?>
```

---

**Good luck! 🚀**
