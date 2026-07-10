---
sidebar_position: 8
title: Dokumentasi Backend (API)
---

# Dokumentasi Backend (REST API)

Komunikasi antara aplikasi dan Mikrotik difasilitasi oleh skrip *Middleware* berbahasa PHP murni (*Native PHP*). Hal ini dilakukan untuk menghindari koneksi port Mikrotik yang terbuka bebas ke internet publik, sehingga *hacker* tidak bisa menembus router secara langsung.

## 📡 API Endpoint: Ambil Data Pelanggan Aktif
Mengambil seluruh pelanggan PPPoE yang sedang terhubung ke router.

- **URL Endpoint**: `mikrotik_live.php?action=get_active_users`
- **Method**: `GET`
- **Autentikasi**: Membutuhkan parameter kredensial Mikrotik di HTTP Header (`IP`, `User`, `Pass`).

### Contoh Respons Sukses (200 OK)
```json
{
  "status": "success",
  "data": [
    {
      ".id": "*1A2",
      "name": "Budi_RT01",
      "service": "pppoe",
      "caller-id": "AA:BB:CC:DD:EE:FF",
      "address": "192.168.10.5",
      "uptime": "2d 4h 15m",
      "session-time-left": "0s"
    },
    {
      ".id": "*1A3",
      "name": "Kantor_Desa",
      "service": "pppoe",
      "caller-id": "11:22:33:44:55:66",
      "address": "192.168.10.12",
      "uptime": "10h 2m",
      "session-time-left": "0s"
    }
  ]
}
```

## 💰 API Endpoint: Modul Billing (Tagihan)
Mencatat pembayaran bulanan dan memproses potongan saldo "Titipan".

- **URL Endpoint**: `payment_summary_operations.php?action=pay_bill`
- **Method**: `POST`
- **Body / Payload Request (JSON)**:
```json
{
  "router_id": "SERIAL-123456",
  "user_name": "Budi_RT01",
  "month": "02",
  "year": "2026",
  "amount_paid": 150000.0,
  "titipan_used": 0.0,
  "admin_name": "Teknisi_Agus"
}
```

### Logika "Titipan" (Advance Payment) di Backend
Saat permintaan POST di atas dikirim, skrip PHP akan mengeksekusi logika berikut (*Pseudo-code*):
1. Cek apakah ada pembayaran di bulan yang sama. Jika ada, batalkan (*Return Error: Already Paid*).
2. Jika ada nilai `titipan_used > 0`, sistem akan memeriksa tabel *users* dan memastikan saldo *Titipan* orang tersebut mencukupi.
3. Saldo *Titipan* dikurangi.
4. Data transaksi baru (sejumlah 150.000) disisipkan (*INSERT*) ke tabel `payments`.
5. Semua operasi di atas dibungkus dalam **Database Transaction (`START TRANSACTION`)**. Jika di tengah jalan listrik server mati, MySQL akan melakukan *Rollback* secara otomatis untuk mencegah inkonsistensi saldo.
