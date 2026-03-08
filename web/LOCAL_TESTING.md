# 🚀 PANDUAN TEST WEB PANEL DI LOKAL

## 📋 Pilihan Cara Test

### ✅ CARA 1: Buka File HTML Langsung (Untuk Lihat Design Saja)

**Sudah saya buka untuk Anda!** Tapi kalau mau buka lagi:

#### Windows:

```powershell
# Buka di Chrome
start chrome "file:///d:/Kuliah/Semester 6/Pemrograman Mobile II/CMM/mikrotik_monitor/web/login.html"

# Atau double-click file:
d:\Kuliah\Semester 6\Pemrograman Mobile II\CMM\mikrotik_monitor\web\login.html
```

**Yang Bisa Dicoba:**

- ✅ Lihat design & UI
- ✅ Test responsive (resize browser)
- ✅ Hover effects & animations
- ✅ Toggle password visibility
- ✅ Theme toggle (moon icon)
- ❌ Login (perlu PHP server)

---

### 🌐 CARA 2: Pakai PHP Built-in Server (RECOMMENDED)

**Untuk test SEMUA fitur** termasuk login & API.

#### Step 1: Buka Terminal/PowerShell

```powershell
cd "d:\Kuliah\Semester 6\Pemrograman Mobile II\CMM\mikrotik_monitor"
```

#### Step 2: Jalankan PHP Server

```powershell
php -S localhost:8000
```

#### Step 3: Buka Browser

```
http://localhost:8000/web/login.html
```

**Yang Bisa Dicoba:**

- ✅ Semua fitur UI
- ✅ Login dengan credentials
- ✅ Dashboard dengan data
- ✅ API calls
- ✅ Session management

**Demo Credentials:**

- Username: `admin`
- Password: `admin123`

---

### 🔧 CARA 3: Pakai XAMPP/WAMP

Jika sudah install XAMPP/WAMP:

#### Step 1: Copy Project

```powershell
# Copy folder ke htdocs
xcopy "d:\Kuliah\Semester 6\Pemrograman Mobile II\CMM\mikrotik_monitor" "C:\xampp\htdocs\mikrotik_monitor" /E /I
```

#### Step 2: Start Apache & MySQL

- Buka XAMPP Control Panel
- Start Apache
- Start MySQL

#### Step 3: Buka Browser

```
http://localhost/mikrotik_monitor/web/login.html
```

---

### 🐳 CARA 4: Pakai Docker (Advanced)

Jika familiar dengan Docker:

#### Create docker-compose.yml:

```yaml
version: "3"
services:
  web:
    image: php:8.0-apache
    ports:
      - "8000:80"
    volumes:
      - ./:/var/www/html
  db:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: pppoe_monitor
    ports:
      - "3306:3306"
```

#### Run:

```bash
docker-compose up
```

---

## 🎯 QUICK START (Paling Mudah)

### Untuk Test Design Saja:

```powershell
# Sudah dibuka! Atau buka lagi:
start chrome "d:\Kuliah\Semester 6\Pemrograman Mobile II\CMM\mikrotik_monitor\web\login.html"
```

### Untuk Test Semua Fitur:

```powershell
# 1. Buka terminal
cd "d:\Kuliah\Semester 6\Pemrograman Mobile II\CMM\mikrotik_monitor"

# 2. Jalankan PHP server
php -S localhost:8000

# 3. Buka browser
start chrome "http://localhost:8000/web/login.html"
```

---

## 🧪 Checklist Testing

### Login Page:

- [ ] Design tampil dengan benar
- [ ] Logo Mikrotik muncul
- [ ] Form fields berfungsi
- [ ] Password toggle works
- [ ] Demo mode button works
- [ ] Responsive di mobile
- [ ] Animations smooth

### Dashboard:

- [ ] Sidebar navigation tampil
- [ ] Stats cards muncul
- [ ] Charts render correctly
- [ ] Recent activities tampil
- [ ] Quick actions buttons works
- [ ] Theme toggle berfungsi
- [ ] Responsive layout

### API (Perlu PHP Server):

- [ ] Login berhasil
- [ ] Session tersimpan
- [ ] Dashboard stats load
- [ ] Logout berfungsi

---

## 🐛 Troubleshooting

### Logo tidak muncul?

**Problem:** Path logo salah
**Solution:**

```html
<!-- Pastikan path benar di login.html -->
<img src="../assets/Mikrotik-logo.png" alt="Logo" />
```

### CSS tidak load?

**Problem:** Path CSS salah
**Solution:**

```html
<!-- Check path di HTML -->
<link rel="stylesheet" href="assets/css/style.css" />
```

### API error CORS?

**Problem:** Buka file HTML langsung (file://)
**Solution:** Gunakan PHP server (http://localhost)

### Charts tidak muncul?

**Problem:** Chart.js CDN tidak load
**Solution:** Check internet connection atau download Chart.js lokal

---

## 💡 Tips

1. **Use Browser DevTools:**
   - F12 untuk buka DevTools
   - Console tab untuk lihat errors
   - Network tab untuk monitor API calls
   - Responsive mode untuk test mobile

2. **Test di Multiple Browsers:**
   - Chrome (recommended)
   - Firefox
   - Edge
   - Safari (jika ada Mac)

3. **Test Responsive:**
   - Desktop (1920x1080)
   - Tablet (768x1024)
   - Mobile (375x667)

---

## 📞 Need Help?

Jika ada error:

1. Check browser console (F12)
2. Check PHP error log
3. Verify file paths
4. Check permissions

---

**Status:** ✅ Login page sudah dibuka di browser Anda!

**Next:** Test design, lalu jalankan PHP server untuk test login functionality.
