---
sidebar_position: 6
title: Galeri Tampilan
---

# Galeri & Penjelasan Antarmuka

Berikut adalah rincian tampilan antarmuka (UI) dari **Mikrotik PPPoE Monitor**. Setiap layar dirancang menggunakan konsep desain modern (*Glassmorphism*) agar nyaman digunakan oleh teknisi lapangan.

---

## 1. Halaman Autentikasi (Login)

<div style={{ textAlign: 'center', marginBottom: '20px' }}>
  <img src={require('@site/static/img/screenshots/01_Login_Screen.jpg').default} width="300" alt="Halaman Login" style={{ borderRadius: '15px', boxShadow: '0 8px 16px rgba(0,0,0,0.3)' }} />
</div>

**Penjelasan:**
Halaman login ini adalah gerbang utama aplikasi. Pengguna harus memasukkan IP Router, Username, dan Password API Mikrotik. Kelebihannya, aplikasi ini menyimpan riwayat login sebelumnya (fitur *Saved Connections*) secara terenkripsi, sehingga teknisi tidak perlu mengetik ulang IP dan password setiap kali membuka aplikasi.

---

## 2. Dashboard Utama

<div style={{ textAlign: 'center', marginBottom: '20px' }}>
  <img src={require('@site/static/img/screenshots/04_Dashboard_Home.jpg').default} width="300" alt="Dashboard" style={{ borderRadius: '15px', boxShadow: '0 8px 16px rgba(0,0,0,0.3)' }} />
</div>

**Penjelasan:**
Dashboard menyajikan ringkasan cerdas jaringan secara *real-time*. Di bagian atas, sistem menampilkan **Foto Router Asli** (otomatis mendeteksi seri hardware Mikrotik yang digunakan). Terdapat indikator persentase pengguna aktif (Hijau) versus pengguna *offline* (Merah), serta kartu menu akses cepat (*Quick Actions*) ke fitur Billing, Maps, dan Manajemen ODP.

---

## 3. Pemantauan Sumber Daya Sistem

<div style={{ textAlign: 'center', marginBottom: '20px' }}>
  <img src={require('@site/static/img/screenshots/11_System_Resource.jpg').default} width="300" alt="System Resource" style={{ borderRadius: '15px', boxShadow: '0 8px 16px rgba(0,0,0,0.3)' }} />
</div>

**Penjelasan:**
Halaman *System Resource* memonitor kesehatan *hardware* Mikrotik. Menampilkan metrik *CPU Load* dalam bentuk grafik cincin (*gauge*), sisa RAM yang tersedia, persentase penyimpanan (*Disk Space*), suhu perangkat (jika didukung *hardware*), dan waktu hidup router (*Uptime*). Sangat vital untuk mendeteksi *bottleneck* pada server.

---

## 4. Daftar Pelanggan Aktif (PPP Active)

<div style={{ textAlign: 'center', marginBottom: '20px' }}>
  <img src={require('@site/static/img/screenshots/06_PPP_Active_List.jpg').default} width="300" alt="User Aktif" style={{ borderRadius: '15px', boxShadow: '0 8px 16px rgba(0,0,0,0.3)' }} />
</div>

**Penjelasan:**
Menampilkan daftar seluruh pelanggan (PPPoE Secret) yang terdaftar. Fitur ini dilengkapi dengan sistem pencarian instan berdasarkan Nama atau IP Address. Teknisi dapat langsung menekan ikon sakelar (*toggle*) di sebelah kanan nama pelanggan untuk memutus sementara (suspend) koneksi internet mereka tanpa harus membuka laptop.

---

## 5. Grafik Trafik Real-time (Traffic Monitor)

<div style={{ display: 'flex', gap: '20px', justifyContent: 'center', flexWrap: 'wrap', marginBottom: '20px' }}>
  <img src={require('@site/static/img/screenshots/15_Monitor_Trafik.jpg').default} width="250" alt="Monitor Traffic 1" style={{ borderRadius: '15px', boxShadow: '0 8px 16px rgba(0,0,0,0.3)' }} />
  <img src={require('@site/static/img/screenshots/16_Monitor_Trafik_2.jpg').default} width="250" alt="Monitor Traffic 2" style={{ borderRadius: '15px', boxShadow: '0 8px 16px rgba(0,0,0,0.3)' }} />
</div>

**Penjelasan:**
Fitur ini mengambil data dari Mikrotik secara berkelanjutan (*polling*) setiap beberapa detik untuk menggambar grafik *bandwidth* (Upload/Download) pada antarmuka *ethernet* utama. Garis grafik ini sangat mulus dan interaktif, memudahkan pengelola untuk memantau apakah *link ISP* sedang penuh (*full traffic*) atau normal.

---

## 6. Sistem Manajemen Penagihan (Billing)

<div style={{ textAlign: 'center', marginBottom: '20px' }}>
  <img src={require('@site/static/img/screenshots/19_Tagihan_Billing_List.jpg').default} width="300" alt="Sistem Billing" style={{ borderRadius: '15px', boxShadow: '0 8px 16px rgba(0,0,0,0.3)' }} />
</div>

**Penjelasan:**
Modul keuangan ISP. Halaman ini merekap status pembayaran seluruh pelanggan pada bulan berjalan. Label **"LUNAS"** (hijau) dan **"BELUM BAYAR"** (merah) memudahkan penagih (*debt collector*). Di sini juga terdapat opsi untuk mencatat tagihan "Titipan" (pembayaran dimuka) yang secara otomatis tersinkronisasi ke server pusat.

---

## 7. Pemetaan Pelanggan (Customer Map)

<div style={{ textAlign: 'center', marginBottom: '20px' }}>
  <img src={require('@site/static/img/screenshots/18_Customer_Map.jpg').default} width="300" alt="Customer Map" style={{ borderRadius: '15px', boxShadow: '0 8px 16px rgba(0,0,0,0.3)' }} />
</div>

**Penjelasan:**
Halaman paling canggih yang memetakan seluruh rumah pelanggan dan titik tiang (ODP) dalam sebuah *Map* interaktif (*OpenStreetMap*). Teknisi dapat melihat titik *blank-spot* jaringan atau menavigasi ke rumah pelanggan yang mengeluhkan gangguan jaringan secara akurat.

---

## 8. Log Aktivitas (Audit Trail)

<div style={{ textAlign: 'center', marginBottom: '20px' }}>
  <img src={require('@site/static/img/screenshots/25_Log_Mikrotik.jpg').default} width="300" alt="Log Mikrotik" style={{ borderRadius: '15px', boxShadow: '0 8px 16px rgba(0,0,0,0.3)' }} />
</div>

**Penjelasan:**
Membaca catatan internal Mikrotik (System Logs) langsung dari *smartphone*. Jika ada perangkat pelanggan yang putus-nyambung terus menerus (Auth Failed / Disconnected), teknisi dapat segera mendeteksinya melalui log *error* berwarna merah pada layar ini tanpa harus *login* via Winbox.
