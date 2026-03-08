# Update Release v1.0.9+10

## Tanggal Release

8 Februari 2026

## Fitur Baru

### ✨ CRUD PPPoE Profile

Fitur lengkap untuk mengelola PPPoE Profile langsung dari aplikasi:

- **➕ Tambah Profile Baru**
  - Form lengkap dengan semua field (name, local-address, remote-address, rate-limit, dll)
  - Validasi input untuk mencegah duplikasi
  - Support untuk session timeout, idle timeout, dan only-one setting

- **✏️ Edit Profile Existing**
  - Pre-filled form dengan data profile saat ini
  - Hanya mengirim field yang berubah ke server
  - Validasi untuk mencegah nama duplikat

- **🗑️ Hapus Profile**
  - Konfirmasi dialog sebelum delete
  - Validasi: Cegah hapus default profile
  - Validasi: Cegah hapus profile yang sedang digunakan
  - Auto-refresh data setelah delete

## Bug Fixes

- ✅ Fix ProviderNotFoundException saat delete profile
- ✅ Fix context issue dengan menggunakan parentContext
- ✅ Perbaikan endpoint API delete (menggunakan DELETE method)

## Files yang Perlu Di-Upload ke Hosting

### 1. API Files (Upload ke folder `/api/`)

- `api/version_config.php` - Updated version ke 1.0.9+10
- `api/check_update.php` - Updated release notes

### 2. APK File (Upload ke folder `/files/`)

- Build APK baru dengan command: `flutter build apk --release`
- Upload file dari: `build/app/outputs/flutter-apk/app-release.apk`
- Upload ke: `https://cmmnetwork.online/files/app-release.apk`

## Cara Upload

### Via FTP/cPanel File Manager:

1. Login ke cPanel hosting
2. Buka File Manager
3. Upload file-file berikut:
   - `api/version_config.php` → `/public_html/api/`
   - `api/check_update.php` → `/public_html/api/`
   - `app-release.apk` → `/public_html/files/`

### Via Git (jika menggunakan):

```bash
git add .
git commit -m "Release v1.0.9: CRUD PPPoE Profile"
git push origin main
```

## Testing Setelah Upload

1. **Test API Update:**

   ```
   https://cmmnetwork.online/api/check_update.php
   ```

   Pastikan response menunjukkan version `1.0.9+10`

2. **Test Download APK:**

   ```
   https://cmmnetwork.online/files/app-release.apk
   ```

   Pastikan file bisa didownload

3. **Test di Aplikasi:**
   - Buka aplikasi versi lama
   - Notifikasi update seharusnya muncul
   - Download dan install APK baru
   - Test fitur CRUD PPPoE Profile

## Checklist Upload

- [ ] Build APK release (`flutter build apk --release`)
- [ ] Upload `api/version_config.php`
- [ ] Upload `api/check_update.php`
- [ ] Upload `app-release.apk` ke `/files/`
- [ ] Test API check_update
- [ ] Test download APK
- [ ] Test update di aplikasi
- [ ] Verifikasi fitur CRUD Profile bekerja

## Notes

- Ukuran APK: ~XX MB (akan dihitung otomatis oleh API)
- Minimum Android version: Android 5.0 (API 21)
- Target Android version: Android 14 (API 34)
