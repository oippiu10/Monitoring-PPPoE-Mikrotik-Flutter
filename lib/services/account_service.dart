import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config_service.dart';

/// Satu router seperti yang didaftarkan di web (tabel `mikrotik_routers`).
///
/// [softwareId] adalah satu-satunya sumber `router_id` yang sah. Aplikasi tidak
/// boleh lagi menebaknya sendiri dari perangkat — kebiasaan itu yang dulu
/// melahirkan ID cadangan seperti `RB-identity@ip:port` dan membuat data antar
/// router tertukar.
class AccountRouter {
  final int id;
  final String name;
  final String host;
  final int port;
  final String username;
  final String password;
  final String softwareId;
  final double? lat;
  final double? lng;
  final bool isActive;
  final int totalCustomers;
  final int onRouter;

  const AccountRouter({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.softwareId,
    required this.isActive,
    required this.totalCustomers,
    required this.onRouter,
    this.lat,
    this.lng,
  });

  String get address => '$host:$port';

  factory AccountRouter.fromJson(Map<String, dynamic> j) {
    return AccountRouter(
      id: int.tryParse('${j['id']}') ?? 0,
      name: (j['name'] ?? '').toString(),
      host: (j['host'] ?? '').toString(),
      port: int.tryParse('${j['port']}') ?? 8728,
      username: (j['username'] ?? '').toString(),
      password: (j['password'] ?? '').toString(),
      softwareId: (j['software_id'] ?? '').toString(),
      lat: j['lat'] == null ? null : double.tryParse('${j['lat']}'),
      lng: j['lng'] == null ? null : double.tryParse('${j['lng']}'),
      isActive: j['is_active'] == true || j['is_active'] == 1,
      totalCustomers: int.tryParse('${j['total_customers']}') ?? 0,
      onRouter: int.tryParse('${j['on_router']}') ?? 0,
    );
  }
}

/// Hasil percobaan login akun.
enum AccountLoginStatus {
  /// Berhasil, token tersimpan.
  ok,

  /// Server ini belum punya endpoint login akun (404). Pemanggil harus
  /// memakai alur lama: kredensial router + cek lisensi.
  notSupported,

  /// Kredensial salah, akun nonaktif, atau input kurang.
  rejected,

  /// Jaringan bermasalah / server error.
  error,
}

class AccountLoginResult {
  final AccountLoginStatus status;
  final String message;
  final Map<String, dynamic>? user;

  const AccountLoginResult(this.status, this.message, [this.user]);

  bool get isOk => status == AccountLoginStatus.ok;
}

/// Login berbasis akun web + daftar router dari server.
///
/// Menggantikan alur lama yang meminta IP/port/user/password router lalu
/// mengecek lisensi ke server terpisah. Alur lama TIDAK dihapus: kalau server
/// yang dituju belum punya endpoint ini, [login] mengembalikan
/// [AccountLoginStatus.notSupported] dan pemanggil kembali ke jalur lama.
class AccountService {
  static const _storage = FlutterSecureStorage();
  static const _kToken = 'account_token';
  static const _kUsername = 'account_username';
  static const _kFullName = 'account_full_name';
  static const _kRole = 'account_role';

  /// Cache "server ini mendukung login akun atau tidak", disimpan per base URL
  /// supaya pengecekan 404 hanya terjadi sekali seumur pemasangan.
  static String _capKey(String baseUrl) => 'account_login_supported::$baseUrl';

  static const Duration _timeout = Duration(seconds: 20);

  static Future<String> _base() => ConfigService.getBaseUrl();

  // ---------------------------------------------------------------- token

  static Future<String?> getToken() => _storage.read(key: _kToken);

  static Future<bool> hasToken() async {
    final t = await getToken();
    return t != null && t.isNotEmpty;
  }

  static Future<Map<String, String?>> getAccount() async {
    return {
      'username': await _storage.read(key: _kUsername),
      'full_name': await _storage.read(key: _kFullName),
      'role': await _storage.read(key: _kRole),
    };
  }

  static Future<void> _clearToken() async {
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kUsername);
    await _storage.delete(key: _kFullName);
    await _storage.delete(key: _kRole);
  }

  // ----------------------------------------------------------- kemampuan

  /// null = belum pernah dicoba di base URL ini.
  static Future<bool?> cachedSupport() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_capKey(await _base()))
        ? prefs.getBool(_capKey(await _base()))
        : null;
  }

  static Future<void> _setSupport(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_capKey(await _base()), value);
  }

  // -------------------------------------------------------------- login

  /// Login memakai akun web. Tidak ada permintaan pengecekan terpisah —
  /// respons dari login itu sendiri yang menentukan server mendukung atau
  /// tidak, jadi tidak ada ongkos jaringan tambahan.
  static Future<AccountLoginResult> login(
      String username, String password) async {
    final base = await _base();
    final uri = Uri.parse('$base/auth/mobile_login.php');

    try {
      final resp = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'username': username, 'password': password}),
          )
          .timeout(_timeout);

      if (resp.statusCode == 404) {
        await _setSupport(false);
        return const AccountLoginResult(
          AccountLoginStatus.notSupported,
          'Server ini belum mendukung login akun.',
        );
      }

      final body = resp.body;
      final looksHtml =
          RegExp(r'<!DOCTYPE|<html', caseSensitive: false).hasMatch(body);
      if (looksHtml) {
        // Balasan HTML biasanya berarti URL salah atau endpoint tidak ada
        await _setSupport(false);
        return const AccountLoginResult(
          AccountLoginStatus.notSupported,
          'Server membalas HTML, bukan JSON. Periksa alamat API.',
        );
      }

      final data = json.decode(body) as Map<String, dynamic>;

      if (resp.statusCode == 200 && data['success'] == true) {
        await _setSupport(true);
        final d = (data['data'] ?? {}) as Map<String, dynamic>;
        final user = (d['user'] ?? {}) as Map<String, dynamic>;

        await _storage.write(key: _kToken, value: '${d['token']}');
        await _storage.write(key: _kUsername, value: '${user['username']}');
        await _storage.write(key: _kFullName, value: '${user['full_name']}');
        await _storage.write(key: _kRole, value: '${user['role']}');

        return AccountLoginResult(AccountLoginStatus.ok, 'Login berhasil', user);
      }

      // 401 / 403 / 422 → endpoint ADA, hanya kredensialnya yang ditolak
      await _setSupport(true);
      return AccountLoginResult(
        AccountLoginStatus.rejected,
        (data['message'] ?? 'Login ditolak').toString(),
      );
    } catch (e) {
      debugPrint('[AccountService] login gagal: $e');
      return AccountLoginResult(
        AccountLoginStatus.error,
        'Tidak dapat terhubung ke server. Periksa koneksi atau alamat API.',
      );
    }
  }

  static Future<void> logout() async {
    final token = await getToken();
    if (token != null && token.isNotEmpty) {
      try {
        final base = await _base();
        await http.post(
          Uri.parse('$base/auth/mobile_logout.php'),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 8));
      } catch (e) {
        // Token tetap dibuang di sisi HP walaupun server tidak terjangkau
        debugPrint('[AccountService] logout server gagal: $e');
      }
    }
    await _clearToken();
  }

  // ------------------------------------------------------------- router

  /// Ambil daftar router milik akun yang sedang login.
  ///
  /// Melempar [AccountSessionExpired] bila token sudah tidak berlaku, supaya
  /// pemanggil bisa mengarahkan kembali ke layar login.
  static Future<List<AccountRouter>> fetchRouters() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw AccountSessionExpired('Belum login.');
    }

    final base = await _base();
    final resp = await http.get(
      Uri.parse('$base/mobile_routers.php'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(_timeout);

    if (resp.statusCode == 401 || resp.statusCode == 403) {
      await _clearToken();
      throw AccountSessionExpired('Sesi berakhir. Silakan login ulang.');
    }
    if (resp.statusCode != 200) {
      throw Exception('Gagal memuat daftar router (HTTP ${resp.statusCode})');
    }

    final data = json.decode(resp.body) as Map<String, dynamic>;
    if (data['success'] != true) {
      throw Exception((data['message'] ?? 'Gagal memuat daftar router').toString());
    }

    return ((data['data'] ?? []) as List)
        .map((e) => AccountRouter.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

class AccountSessionExpired implements Exception {
  final String message;
  AccountSessionExpired(this.message);
  @override
  String toString() => message;
}
