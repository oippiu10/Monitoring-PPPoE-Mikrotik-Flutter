import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class LicenseService {
  // Secret key untuk aplikasi Anda (Jika diganti, klien lama tetap hidup berkat shared_preferences!)
  static const String secretKey = "MKM_LICENSE_KEY_2026";

  // URL backend PHP tempat check_license.php berada (Utama & Backup)
  static const List<String> apiUrls = [
    "http://billing.marzuqnetwork.online/api2/check_license.php", // Primary (Marzuq)
    "http://cmmnetwork.online/api/check_license.php"              // Backup (CMM)
  ];

  Future<Map<String, dynamic>> checkLicense(String mikrotikId) async {
    print('\n================ [ LISENSI LOG ] ================');
    print('[LISENSI] 1. Memulai verifikasi untuk ID Mikrotik: $mikrotikId');
    final prefs = await SharedPreferences.getInstance();

    // Perbaikan: Simpan memori lisensi spesifik HANYA untuk router ini (ID Mikrotiknya)
    String? savedLicense = prefs.getString('saved_license_$mikrotikId');
    String licenseCodeToUse = "";

    // Trik "Memori Klien": Jika dulu dia sudah terdaftar, pakai kode itu terus
    if (savedLicense != null && savedLicense.isNotEmpty) {
      licenseCodeToUse = savedLicense;
      print(
          '[LISENSI] 2a. Menggunakan KODE LAMA yang tersimpan (Bypass generate baru): $licenseCodeToUse');
    } else {
      licenseCodeToUse = _generateLicenseCode(mikrotikId);
      print('[LISENSI] 2b. Membuat KODE BARU: $licenseCodeToUse');
    }

    for (String apiUrl in apiUrls) {
      print('[LISENSI] 3. Menghubungi API Server: $apiUrl');
      try {
        final response = await http
            .post(
              Uri.parse(apiUrl),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'license_code': licenseCodeToUse,
                'router_id': mikrotikId, // Kirim Router ID asli untuk monitoring
              }),
            )
            .timeout(const Duration(seconds: 8)); // Kurangi timeout agar lebih cepat pindah ke backup

        print(
            '[LISENSI] 4. API merespon dengan Status Code: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          print('[LISENSI] 5. Isi Balasan Server ($apiUrl): $data');
          bool isValid = data['status'] == true;

          if (isValid) {
            print('[LISENSI] 6a. STATUS: OK! (LISENSI AKTIF) 🎉');
            // Lolos! Simpan ke memori HP spesifik untuk router ini
            await prefs.setString('saved_license_$mikrotikId', licenseCodeToUse);
          } else if (data['message'] == 'expired' ||
              data['message'] == 'blocked') {
            print('[LISENSI] 6b. STATUS: DITOLAK! (${data['message']}) ❌');
            // Hapus dari memori HP HANYA lisensi mikrotik ini
            await prefs.remove('saved_license_$mikrotikId');
            licenseCodeToUse = _generateLicenseCode(mikrotikId);
          } else {
            print('[LISENSI] 6c. STATUS: DITOLAK! KODE BELUM TERDAFTAR ❌');
          }

          print('=================================================\n');
          return {
            'isValid': isValid,
            'message': data['message'] ?? 'unknown',
            'licenseCode': licenseCodeToUse
          };
        }
      } catch (e) {
        print('[LISENSI] ERROR KONEKSI/TIMEOUT pada $apiUrl: $e ⚠️');
      }
    }

    // Jika semua server gagal
    print('=================================================\n');
    return {
      'isValid': false,
      'message': 'connection_error',
      'licenseCode': licenseCodeToUse
    };
  }

  String _generateLicenseCode(String mikrotikId) {
    DateTime now = DateTime.now();
    // Format Bulan (2 digit) dan Tahun (2 digit). Contoh: "04" dan "26"
    String strBulan = now.month.toString().padLeft(2, '0');
    String strTahun = now.year.toString().substring(2);

    // Hash Mikrotik ID + Secret Key untuk mendapatkan ID statis yang panjang
    String rawData = mikrotikId + secretKey;
    var bytes = utf8.encode(rawData);
    var digest = sha256.convert(bytes);

    // Kita ambil 10 Karakter pertama dari hasil Hashing (Uppercase)
    String hashString = digest.toString().toUpperCase();

    // Trik: Ambil ukuran Byte pertama dan ubah jadi satuan Angka (0-9) murni
    int modulusAngka = digest.bytes[0] % 10;
    String penyamarWaktu = modulusAngka.toString();

    // Format 1: 04 + (AngkaPenyamar) + 26 => misal "04726" (Sebanyak 5 Karakter Angka murni)
    String blok1 = "$strBulan$penyamarWaktu$strTahun";

    // Format 2 & 3: Ambil 10 karakter sisanya, potong per 5 karakter
    String blok2 = hashString.substring(0, 5); // Karakter indeks 0 sampai 4
    String blok3 = hashString.substring(5, 10); // Karakter indeks 5 sampai 9

    // Hasil akhir (Rapih 5 Karakter)
    return "MKM-$blok1-$blok2-$blok3";
  }

  // Fungsi utilitas kalau mau reset manual via menu Settings
  Future<void> clearLicenseMemory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_license');
  }
}
