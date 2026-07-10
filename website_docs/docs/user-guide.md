---
sidebar_position: 9
title: Panduan Penggunaan Harian
---

# Buku Panduan Pengguna (User Manual)

Halaman ini adalah dokumentasi komprehensif bagi **Teknisi Lapangan** dan **Admin ISP** untuk menguasai setiap fungsi dari aplikasi Mikrotik Monitor dalam operasional sehari-hari.

---

## 👥 Bab 1: Manajemen Ekosistem Pelanggan

Modul ini digunakan untuk menambah, memodifikasi, dan menghapus koneksi pelanggan pada mesin Mikrotik.

### 1.1 Menambahkan Pelanggan (Instalasi Baru)
Saat Anda memasang kabel FO di rumah pelanggan baru, ikuti langkah ini:
1. Buka tab **Dashboard**, klik tombol bundar biru (`+`) di sudut kanan bawah layar.
2. Di form *Tambah User PPPoE*, isi **Username** dan **Password** (ini akan dikonfigurasi ke dalam modem/ONU pelanggan).
3. Pilih **Profile** (Paket Bandwidth) yang pelanggan beli.
4. **Otomatisasi GPS**: Jika izin lokasi (*Location Permission*) diaktifkan, aplikasi akan mengunci koordinat bujur dan lintang (*Latitude/Longitude*) lokasi Anda saat ini. Ini sangat penting agar letak rumah pelanggan tersimpan secara akurat di dalam **Customer Map**.
5. Isi **Nomor WhatsApp**, lalu tekan **Simpan**. Sistem akan langsung menembakkan perintah *REST API* untuk membuat *Secret* di dalam Mikrotik.

### 1.2 Menangguhkan (Suspend) Pelanggan Menunggak
Jika ada pelanggan yang melewati batas waktu pembayaran:
1. Masuk ke halaman **PPP Active** atau daftar **Semua User**.
2. Cari nama pelanggan, lalu sentuh *Toggle Switch* (sakelar geser) di sudut kanannya.
3. Sakelar yang berwarna abu-abu menandakan status **Disable**. Pelanggan tersebut akan otomatis terputus (*kicked*) dari router dan tidak bisa mengakses internet sampai Anda menghidupkannya kembali.

---

## 💰 Bab 2: Administrasi Keuangan (Sistem Billing)

Aplikasi ini menggantikan buku catatan tagihan fisik yang rentan hilang atau sobek.

### 2.1 Mencatat Pembayaran Normal
1. Buka menu **Billing** di navigasi bawah.
2. Anda akan melihat kartu untuk setiap pelanggan. Pelanggan yang belum membayar akan berwarna *merah* dengan tag **BELUM LUNAS**.
3. Sentuh kartu pelanggan tersebut, lalu tekan tombol **Bayar Tagihan**.
4. Sistem otomatis mengambil nilai harga paket (misal Rp 150.000). Tekan **Konfirmasi**. Status akan berubah menjadi *hijau* (**LUNAS**).

### 2.2 Kasus Khusus: Pembayaran Uang Muka (Titipan)
Bagaimana jika tagihannya Rp 150.000, tapi pelanggan menyerahkan uang Rp 200.000 dan berkata *"kembaliannya simpan saja buat bulan depan"*?
1. Saat menekan tombol **Bayar Tagihan**, centang kotak **"Masuk ke Titipan"**.
2. Masukkan nominal uang yang diterima: `200000`.
3. Sistem dengan cerdas akan memotong Rp 150.000 untuk tagihan bulan ini, lalu menyimpan sisa **Rp 50.000** ke saldo *Titipan* pelanggan tersebut.
4. Di bulan berikutnya, saat Anda ingin menagih pelanggan ini, sistem akan memberi tahu: *"Pelanggan ini memiliki saldo Titipan Rp 50.000. Hanya perlu membayar Rp 100.000"*.

---

## 🗺️ Bab 3: Visualisasi Geospasial (Customer Map)

Fitur paling krusial untuk teknisi *troubleshooting*. Peta ini menggabungkan lokasi pelanggan (rumah) dan infrastruktur tiang (ODP/Splitter).

### 3.1 Menggunakan Sistem Filter Pintar
Di pojok kanan atas layar Map, terdapat ikon corong (Filter). Anda bisa menyeleksi titik yang muncul berdasarkan:
- **Status Koneksi**: Menyembunyikan yang hijau (online) untuk fokus mencari pelanggan merah (offline/putus).
- **Jenis Perangkat**: Memfilter agar hanya **Titik ODP** (warna kuning) yang muncul di layar. Sangat berguna saat teknisi sedang melakukan tarikan kabel (*patching*) baru dan mencari tiang ODP yang masih memiliki *port* kosong.

### 3.2 Fitur "Ambil Rute" (Navigasi GPS)
Jika ada laporan gangguan dari *Bapak Budi*, tapi teknisi baru tidak tahu letak rumahnya:
1. Cari *Budi* di bar pencarian peta.
2. Sentuh ikon rumah miliknya.
3. Akan muncul tombol **Petunjuk Arah**. Saat ditekan, sistem otomatis melempar titik koordinat tersebut ke aplikasi **Google Maps** bawaan HP Anda. Google Maps akan langsung memberikan instruksi suara (*Turn-by-turn navigation*) dari posisi teknisi berdiri hingga tepat ke teras rumah Bapak Budi.
