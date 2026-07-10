---
sidebar_position: 1
title: Pengenalan & Latar Belakang
---

# Pengenalan & Latar Belakang Sistem

Aplikasi **Mikrotik PPPoE Monitor** bukanlah sekadar aplikasi monitoring biasa. Sistem ini dirancang dari bawah ke atas (*from scratch*) sebagai solusi komprehensif bagi para pelaku usaha *Internet Service Provider* (ISP) lokal dan RT/RW Net yang selama ini kesulitan mengelola infrastruktur jaringan dan pelacakan keuangan pelanggan mereka.

## 🎯 Latar Belakang Masalah

Sebelum adanya aplikasi ini, teknisi dan pengelola jaringan sering menghadapi masalah operasional harian:
1. **Ketergantungan pada PC/Laptop:** Menggunakan *Winbox* atau *WebFig* di layar *smartphone* sangat menyulitkan. UI Mikrotik bawaan tidak dirancang untuk layar sentuh kecil.
2. **Data Berserakan:** Router Mikrotik hanya menyimpan data *username*, *password*, dan alamat IP. Mikrotik **tidak** memiliki database untuk menyimpan nomor WhatsApp pelanggan, foto rumah, atau histori pembayaran tagihan.
3. **Lambat Merespons Gangguan:** Ketika pelanggan komplain, teknisi sering kesulitan mencari tiang ODP (*Optical Distribution Point*) mana yang terhubung ke pelanggan tersebut karena kurangnya sistem pemetaan.

## 💡 Solusi yang Ditawarkan (Fitur Super Lengkap)

Aplikasi ini menjembatani celah antara teknis jaringan dan administrasi bisnis dengan fitur-fitur berikut:

### 1. Ekosistem Jaringan (Network Ecosystem)
- **Pemantauan Real-Time:** Memantau beban CPU, RAM, suhu, dan memori penyimpanan router Mikrotik secara presisi.
- **Manajemen Sesi PPPoE:** Teknisi dapat "menendang" (*kick*), menghapus, atau menonaktifkan akun pelanggan yang menunggak hanya dengan satu kali usapan jari (*swipe*).
- **Traffic Graph Canggih:** Visualisasi arus masuk/keluar (*upload/download*) data pelanggan secara *real-time* dengan grafik garis yang mulus (*smooth line chart*).

### 2. Modul Keuangan & Penagihan (Billing Module)
- **Otomatisasi Tagihan:** Sistem mampu membaca profil harga paket (*rate-limit*) di Mikrotik dan otomatis mencetak tagihan ke pelanggan setiap bulan.
- **Sistem Pembayaran "Titipan":** Jika pelanggan membayar lebih bayar atau memberi uang muka (DP), kelebihan dana akan dicatat sebagai "Titipan" dan otomatis memotong tagihan bulan berikutnya tanpa campur tangan admin.
- **Export Data Skala Besar:** Seluruh riwayat transaksi dapat diekspor menjadi dokumen `.PDF` siap cetak (untuk nota fisik) atau `.CSV / Excel` untuk pelaporan keuangan ke pemilik ISP.

### 3. Pemetaan Geografis Interaktif
- **Integrasi OpenStreetMap (OSM):** Visualisasi letak rumah pelanggan dengan indikator warna pintar (Hijau = Online, Merah = Offline).
- **Pemetaan ODP:** Mencatat detail setiap tiang Fiber Optic, kapasitas port (2/4/8/16 port), warna *tube*, dan *core* fiber yang digunakan.

## 🏢 Target Pengguna
Sistem ini ditargetkan khusus untuk:
- **Pemilik ISP / RT-RW Net**: Untuk memantau pendapatan dan kestabilan *server*.
- **Teknisi Lapangan**: Untuk instalasi pelanggan baru, pelacakan letak kabel putus, dan *troubleshooting* jaringan *wireless* maupun *Fiber Optic*.
- **Admin Penagihan (Debt Collector)**: Untuk menagih iuran bulanan langsung ke rumah pelanggan tanpa perlu membawa buku catatan fisik.
