import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'config_service.dart';
import 'mikrotik_service.dart';
import 'mikrotik_native_service.dart';
import 'log_service.dart';

class ApiService {
  static String _baseUrlCache = 'https://cmmnetwork.online/api';
  static String get baseUrl => _baseUrlCache;
  static Future<void> refreshBaseUrlFromStorage() async {
    _baseUrlCache = await ConfigService.getBaseUrl();
  }

  static Future<String> _getBaseUrl() async {
    final url = await ConfigService.getBaseUrl();
    _baseUrlCache = url;
    return url;
  }

  // Cache for storing fetched data
  static Map<String, dynamic> _cache = {};
  static Map<String, DateTime> _cacheTimestamps = {};

  // Cache untuk sync status per router (mencegah sync berulang)
  static String? _lastSyncedRouterId;
  static DateTime? _lastSyncTime;

  // Unified JSON decoder with HTML detection and better errors
  static dynamic _decodeJsonOrThrow(http.Response response) {
    final contentType = response.headers['content-type'] ?? '';
    final body = response.body;
    final isHtml = contentType.contains('text/html') ||
        RegExp(r'<!DOCTYPE|<html', caseSensitive: false).hasMatch(body);
    if (isHtml) {
      throw Exception(
          'Server mengembalikan HTML, bukan JSON. Periksa konfigurasi API.');
    }
    try {
      return json.decode(body);
    } on FormatException {
      return {};
    }
  }

  static Exception _friendlyException(Object e) {
    final msg = e.toString();
    if (msg.contains('Invalid argument(s): No host specified in URI') ||
        msg.contains('FormatException: Invalid empty scheme')) {
      return Exception(
          'Base URL tidak valid. Buka Setting > API Configuration dan isi alamat lengkap, contoh: https://domain.com/api');
    }
    if (msg.contains('SocketException')) {
      return Exception(
          'Tidak dapat terhubung ke server. Periksa koneksi internet atau Base URL.');
    }
    if (msg.contains('TimeoutException')) {
      return Exception('Koneksi ke server timeout. Silakan coba lagi.');
    }
    return Exception('Error: ${msg.replaceFirst('Exception: ', '')}');
  }

  /// Get all users from API with router_id filter
  /// @param routerId The router serial number to filter users
  static Future<Map<String, dynamic>> getAllUsers(
      {required String routerId}) async {
    try {
      final baseUrl = await _getBaseUrl();
      final uri =
          Uri.parse('$baseUrl/get_all_users.php').replace(queryParameters: {
        'router_id': routerId,
      });
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load users');
      }
    } catch (e) {
      throw _friendlyException(e);
    }
  }

  // Save single user
  static Future<Map<String, dynamic>> saveUser({
    required String routerId,
    required String username,
    required String password,
    required String profile,
    String? wa,
    String? maps,
    String? alamat,
    String? redaman,
    String? tanggalTagihan,
    String? foto,
    String? tanggalDibuat,
    String? adminUsername,
  }) async {
    try {
      final baseUrl = await _getBaseUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/save_user.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'router_id': routerId,
          'username': username,
          'password': password,
          'profile': profile,
          'wa': wa,
          'maps': maps,
          'alamat': alamat,
          'redaman': redaman,
          'tanggal_tagihan': tanggalTagihan,
          'foto': foto,
          'tanggal_dibuat': tanggalDibuat,
        }),
      );
      if (response.statusCode == 200) {
        final decoded = _decodeJsonOrThrow(response) as Map<String, dynamic>;
        // invalidate related caches after successful mutation
        final cacheKey = 'all_users_with_payments_$routerId';
        _cache.remove(cacheKey);
        _cacheTimestamps.remove(cacheKey);

        // Log Activity
        LogService.logActivity(
          username: adminUsername ?? 'System/Admin',
          action: LogService.ACTION_ADD_USER,
          routerId: routerId,
          details: 'added ppp secret: $username',
        );

        return decoded;
      } else {
        throw Exception('Failed to save user');
      }
    } catch (e) {
      throw _friendlyException(e);
    }
  }

  // Update user data tambahan
  static Future<Map<String, dynamic>> updateUserData({
    required String routerId,
    required String username,
    String? wa,
    String? maps,
    String? alamat,
    String? redaman,
    String? tanggalTagihan,
    String? foto,
    int? odpId,
    String? adminUsername,
  }) async {
    try {
      final baseUrl = await _getBaseUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/update_data_tambahan.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'router_id': routerId,
          'username': username,
          'wa': wa ?? '',
          'maps': maps ?? '',
          'alamat': alamat ?? '',
          'redaman': redaman ?? '',
          'tanggal_tagihan': tanggalTagihan ?? '',
          if (foto != null) 'foto': foto,
          'odp_id': odpId,
        }),
      );

      if (response.statusCode == 200) {
        final result = _decodeJsonOrThrow(response) as Map<String, dynamic>;
        if (result['success'] == true) {
          // invalidate related caches after successful mutation
          final cacheKey = 'all_users_with_payments_$routerId';
          _cache.remove(cacheKey);
          _cacheTimestamps.remove(cacheKey);

          // Log Activity
          LogService.logActivity(
            username: adminUsername ?? 'System/Admin',
            action: LogService.ACTION_EDIT_USER,
            routerId: routerId,
            details: 'changed ppp secret: $username',
          );

          return result;
        } else {
          if (result['error'] == 'DEBUG_MODE') {
            throw Exception(json.encode(result['debug_data']));
          }
          throw Exception(
              result['message'] ?? 'Gagal mengupdate data dari server');
        }
      } else {
        // Coba decode body untuk mendapatkan pesan error dari PHP
        String errorMessage = 'Gagal mengupdate data: ${response.statusCode}';
        try {
          final errorBody = json.decode(response.body);
          if (errorBody['error'] != null) {
            errorMessage = 'Error dari server: ${errorBody['error']}';
          }
        } catch (_) {
          // Gagal decode, gunakan response body mentah jika ada
          if (response.body.isNotEmpty) {
            errorMessage = response.body;
          }
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      throw _friendlyException(e);
    }
  }

  // Export multiple users
  static Future<Map<String, dynamic>> exportUsers(
      List<Map<String, dynamic>> users) async {
    try {
      final baseUrl = await _getBaseUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/export_ppp.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(users),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to export users');
      }
    } catch (e) {
      throw _friendlyException(e);
    }
  }

  // Sync PPP users from Mikrotik to backend DB for a given router
  static Future<Map<String, dynamic>> syncPPPUsers({
    required String routerId,
    required List<Map<String, dynamic>> pppUsers,
    bool prune = false,
    bool enableLogging = false,
  }) async {
    try {
      // Add a safety check to prevent accidental data loss
      if (prune && pppUsers.isEmpty) {
        throw Exception(
            'PERINGATAN KEAMANAN: Operasi prune dibatalkan karena tidak ada data yang diterima. Ini bisa menyebabkan kehilangan data.');
      }

      // Add confirmation for prune operations with large data deletion
      if (prune && pppUsers.length < 10) {
        // Only show warning if we're deleting a significant amount of data
        // This would need to be handled in the UI layer
      }

      final baseUrl = await _getBaseUrl();
      final payload = {
        'router_id': routerId,
        'ppp_users': pppUsers,
        if (prune) 'prune': true,
      };
      // Debug request
      if (enableLogging) {
        // ignore: avoid_print
        print(
            '[SYNC] Sending batch: users=${pppUsers.length} to $baseUrl/sync_ppp_to_db.php');
      }
      final response = await http.post(
        Uri.parse('$baseUrl/sync_ppp_to_db.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(payload),
      );
      // Debug response - lebih detail
      if (enableLogging) {
        final bodyPreview = response.body.length > 500
            ? response.body.substring(0, 500) + '...<truncated>'
            : response.body;
        // ignore: avoid_print
        print('[SYNC] Response status=${response.statusCode}');
        // ignore: avoid_print
        print(
            '[SYNC] Content-Type: ${response.headers['content-type'] ?? 'unknown'}');
        // ignore: avoid_print
        print(
            '[SYNC] Body preview: ${bodyPreview.replaceAll('\n', ' ').replaceAll('\r', ' ')}');
      }

      if (response.statusCode != 200) {
        final bodyPreview = response.body.length > 500
            ? response.body.substring(0, 500) + '...<truncated>'
            : response.body;
        throw Exception(
            'Sync PPP gagal: HTTP ${response.statusCode}\nBody: $bodyPreview');
      }
      final decoded = _decodeJsonOrThrow(response) as Map<String, dynamic>;
      if (decoded['success'] == true) return decoded;
      throw Exception(decoded['error'] ?? 'Sync PPP gagal');
    } catch (e) {
      throw _friendlyException(e);
    }
  }

  // Backfill router_id for legacy rows (DEFAULT-ROUTER/empty) to current routerId
  // Silent fail - tidak throw exception untuk menghindari error di login
  static Future<Map<String, dynamic>> backfillRouterId({
    required String routerId,
    String oldValue = 'DEFAULT-ROUTER',
    bool includeEmpty = true,
  }) async {
    try {
      final baseUrl = await _getBaseUrl();
      final response = await http
          .post(
            Uri.parse('$baseUrl/backfill_router_id.php'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'router_id': routerId,
              'old_value': oldValue,
              'include_empty': includeEmpty,
            }),
          )
          .timeout(const Duration(
              seconds: 5)); // Timeout cepat untuk fire-and-forget

      // Cek status code dulu
      if (response.statusCode != 200) {
        return {'success': false, 'error': 'HTTP ${response.statusCode}'};
      }

      try {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        if (decoded['success'] == true) {
          return decoded;
        }
        return decoded;
      } on FormatException {
        // Jika response tidak valid JSON, abaikan
        return {'success': false, 'error': 'Invalid response'};
      }
    } catch (e) {
      // Silent fail - jangan throw exception
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Delete user with router_id filter
  /// @param routerId The router serial number
  /// @param username The username to delete
  static Future<bool> deleteUser(
      {required String routerId,
      required String username,
      String? adminUsername}) async {
    final baseUrl = await _getBaseUrl();
    final response = await http.post(
      Uri.parse('$baseUrl/delete_user.php'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'router_id': routerId, 'username': username}),
    );
    if (response.statusCode == 200) {
      final data = _decodeJsonOrThrow(response) as Map<String, dynamic>;
      if (data['success'] == true) {
        // invalidate related caches after successful mutation
        final cacheKey = 'all_users_with_payments_$routerId';
        _cache.remove(cacheKey);
        _cacheTimestamps.remove(cacheKey);

        // Log Activity
        LogService.logActivity(
          username: adminUsername ?? 'System/Admin',
          action: LogService.ACTION_DELETE_USER,
          routerId: routerId,
          details: 'removed ppp secret: $username',
        );

        return true;
      }
      throw Exception(data['error'] ?? 'Gagal menghapus user');
    } else {
      throw Exception('Gagal menghapus user: ${response.statusCode}');
    }
  }

  // Delete all data for a specific router (Client-side loop)
  static Future<void> deleteRouterData(String routerId) async {
    try {
      // 1. Get all users
      final usersMap = await getAllUsers(routerId: routerId);
      if (usersMap['status'] == 'success') {
        final List<dynamic> users = usersMap['data'];
        for (var user in users) {
          final username = user['username'];
          if (username != null) {
            try {
              await deleteUser(routerId: routerId, username: username);
            } catch (e) {
              print('Failed to delete user $username: $e');
            }
          }
        }
      }
    } catch (e) {
      throw _friendlyException(e);
    }
  }

  // New method to fetch all users with payments
  static Future<List<Map<String, dynamic>>> fetchAllUsersWithPayments(
      {required String routerId}) async {
    try {
      // Check cache first - IMPORTANT: Include routerId in cache key for multi-router support
      final cacheKey = 'all_users_with_payments_$routerId';
      if (_cache.containsKey(cacheKey) &&
          _cacheTimestamps.containsKey(cacheKey) &&
          DateTime.now().difference(_cacheTimestamps[cacheKey]!).inMinutes <
              5) {
        return List<Map<String, dynamic>>.from(_cache[cacheKey]);
      }

      final baseUrl = await _getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/get_all_users_with_payments.php')
            .replace(queryParameters: {
          'router_id': routerId,
        }),
        headers: {'Accept': 'application/json'},
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Koneksi timeout. Silakan coba lagi.'),
      );

      if (response.statusCode == 200) {
        final data = _decodeJsonOrThrow(response) as Map<String, dynamic>;
        if (data['status'] == 'success') {
          // Proper type conversion to avoid casting errors
          final List<dynamic> rawData = data['data'] as List<dynamic>;
          final List<Map<String, dynamic>> convertedData = rawData
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();

          // Cache the result with router-specific key
          _cache[cacheKey] = convertedData;
          _cacheTimestamps[cacheKey] = DateTime.now();

          return convertedData;
        } else {
          throw Exception(data['message'] ?? 'Gagal memuat data tagihan');
        }
      } else {
        throw Exception(
            'Server error (${response.statusCode}). Silakan coba lagi.');
      }
    } catch (e) {
      throw _friendlyException(e);
    }
  }

  // New method to fetch payment summary
  static Future<List<Map<String, dynamic>>> fetchPaymentSummary(
      {required String routerId}) async {
    try {
      final baseUrl = await _getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/payment_summary_operations.php')
            .replace(queryParameters: {
          'action': 'summary',
          'router_id': routerId,
        }),
        headers: {'Accept': 'application/json'},
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Koneksi timeout. Silakan coba lagi.'),
      );

      // Check for redirect responses
      if (response.statusCode == 302 || response.statusCode == 301) {
        throw Exception(
            'API memerlukan autentikasi. Silakan hubungi administrator.');
      }

      if (response.statusCode == 200) {
        final data = _decodeJsonOrThrow(response) as Map<String, dynamic>;
        if (data['success'] == true) {
          final List<dynamic> rawList = data['data'] as List<dynamic>;
          // Normalize types to avoid runtime type errors on UI
          return rawList.map((item) {
            final itemMap = Map<String, dynamic>.from(item as Map);
            final month = int.tryParse(itemMap['month'].toString()) ??
                (itemMap['month'] is int ? itemMap['month'] as int : 0);
            final year = int.tryParse(itemMap['year'].toString()) ??
                (itemMap['year'] is int ? itemMap['year'] as int : 0);
            final totalNum = double.tryParse(itemMap['total'].toString());
            final total = totalNum ??
                (itemMap['total'] is num
                    ? (itemMap['total'] as num).toDouble()
                    : 0.0);
            final count = int.tryParse(itemMap['count'].toString()) ??
                (itemMap['count'] is int ? itemMap['count'] as int : 0);
            return {
              'month': month,
              'year': year,
              'total': total,
              'count': count,
            };
          }).toList();
        } else {
          throw Exception(data['error'] ?? 'Gagal memuat ringkasan pembayaran');
        }
      } else {
        throw Exception(
            'Server error (${response.statusCode}). Silakan coba lagi.');
      }
    } catch (e) {
      throw _friendlyException(e);
    }
  }

  // New method to fetch all payments for a specific month and year
  static Future<List<Map<String, dynamic>>> fetchAllPaymentsForMonthYear(
      int month, int year,
      {required String routerId}) async {
    try {
      final baseUrl = await _getBaseUrl();
      final uri = Uri.parse('$baseUrl/payment_summary_operations.php').replace(
        queryParameters: {
          'action': 'detail',
          'month': month.toString(),
          'year': year.toString(),
          'router_id': routerId,
        },
      );
      final response = await http.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Koneksi timeout. Silakan coba lagi.'),
      );

      // Check for redirect responses
      if (response.statusCode == 302 || response.statusCode == 301) {
        throw Exception(
            'API memerlukan autentikasi. Silakan hubungi administrator.');
      }

      if (response.statusCode == 200) {
        final data = _decodeJsonOrThrow(response) as Map<String, dynamic>;
        if (data['success'] == true) {
          final List<dynamic> rawData = data['data'] as List<dynamic>;
          final raw = rawData
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();

          // Normalize for detail screen
          return raw.map((p) {
            final amountNum = double.tryParse(p['amount'].toString());
            return {
              ...p,
              'amount': amountNum ??
                  (p['amount'] is num ? (p['amount'] as num).toDouble() : 0.0),
              'username': (p['username'] ?? p['user_id'] ?? '-').toString(),
              'method': (p['method'] ?? '-').toString(),
              'payment_date': (p['payment_date'] ?? '-').toString(),
              'note': (p['note'] ?? '').toString(),
            };
          }).toList();
        } else {
          throw Exception(data['error'] ?? 'Gagal memuat detail pembayaran');
        }
      } else {
        throw Exception(
            'Server error (${response.statusCode}). Silakan coba lagi.');
      }
    } catch (e) {
      throw _friendlyException(e);
    }
  }

  // New method to clear cache
  static void clearCache() {
    _cache.clear();
    _cacheTimestamps.clear();
  }

  // Helper function untuk sinkronisasi PPP users dari Mikrotik ke database
  // Dipanggil sebelum load data di halaman-halaman yang membutuhkan data dari database
  static Future<void> syncUsersFromMikrotik({
    required String routerId,
    required String ip,
    required String port,
    required String username,
    required String password,
    bool enableLogging = false,
    bool useNativeApi = false,
    MikrotikService? existingService,
    List<Map<String, dynamic>>? preLoadedSecrets,
  }) async {
    // Cek cache: jangan sync jika sudah sync router_id ini dalam 30 detik terakhir
    final now = DateTime.now();
    if (_lastSyncedRouterId == routerId &&
        _lastSyncTime != null &&
        now.difference(_lastSyncTime!).inSeconds < 30) {
      if (enableLogging) {
        // ignore: avoid_print
        print('[SYNC_HELPER] Skip sync - sudah sync baru saja (< 30 detik)');
      }
      return;
    }

    MikrotikService? localService;
    // Use existing service if provided, otherwise create a local one
    // Only create service if we don't have preLoadedSecrets
    final service = existingService ??
        (preLoadedSecrets == null
            ? (localService = _createService(
                ip: ip,
                port: port,
                username: username,
                password: password,
                enableLogging: enableLogging,
                useNativeApi: useNativeApi,
              ))
            : null);

    try {
      final secrets = preLoadedSecrets ?? await service!.getPPPSecret();
      // Proses data di Isolate terpisah agar tidak memblokir UI
      final normalized = await compute(_normalizeSecrets, secrets);

      if (normalized.isEmpty) return;

      // Update cache timestamp sebelum sync
      _lastSyncedRouterId = routerId;
      _lastSyncTime = now;

      // Kirim per batch agar payload tidak terlalu besar
      const int batchSize = 100;
      for (int i = 0; i < normalized.length; i += batchSize) {
        final batch = normalized.sublist(
            i,
            i + batchSize > normalized.length
                ? normalized.length
                : i + batchSize);
        try {
          await syncPPPUsers(
            routerId: routerId,
            pppUsers: List<Map<String, dynamic>>.from(batch),
            // PENTING: JANGAN AKTIFKAN PRUNE untuk sinkronisasi rutin karena akan menghapus data tambahan
            prune: false,
            enableLogging: enableLogging,
          );
        } catch (e) {
          // ignore: avoid_print
          print('[SYNC_HELPER] Batch ${(i ~/ batchSize) + 1} gagal: $e');
          // Lanjutkan batch berikutnya meskipun batch ini gagal
        }

        // Beri jeda sedikit agar UI tetap responsif
        await Future.delayed(const Duration(milliseconds: 50));
      }
    } catch (e) {
      // ignore: avoid_print
      print('[SYNC_HELPER] Sync gagal: $e');
      // Silent fail - tidak throw exception agar tidak mengganggu load data
    } finally {
      // Dispose local service if we created it and it's a native service
      if (localService != null && localService is MikrotikNativeService) {
        localService.dispose();
      }
    }
  }

  static MikrotikService _createService({
    required String ip,
    required String port,
    required String username,
    required String password,
    required bool enableLogging,
    required bool useNativeApi,
  }) {
    if (useNativeApi || port == '8728' || port == '8729') {
      return MikrotikNativeService(
        ip: ip,
        port: port,
        username: username,
        password: password,
        enableLogging: enableLogging,
      );
    } else {
      return MikrotikService(
        ip: ip,
        port: port,
        username: username,
        password: password,
        enableLogging: enableLogging,
      );
    }
  }

  // =====================================================
  // Profile Pricing Operations
  // =====================================================

  /// Get all profile pricing for a router
  static Future<List<Map<String, dynamic>>> getProfilePricing({
    required String routerId,
    bool includeInactive = false,
  }) async {
    try {
      final baseUrl = await _getBaseUrl();
      final uri = Uri.parse('$baseUrl/profile_pricing_operations.php')
          .replace(queryParameters: {
        'router_id': routerId,
        if (includeInactive) 'include_inactive': 'true',
      });
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final decoded = _decodeJsonOrThrow(response) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['data'] != null) {
          return List<Map<String, dynamic>>.from(decoded['data']);
        }
        return [];
      } else {
        throw Exception('Failed to load profile pricing');
      }
    } catch (e) {
      throw _friendlyException(e);
    }
  }

  /// Get single profile pricing by profile name
  static Future<Map<String, dynamic>?> getProfilePricingByName({
    required String routerId,
    required String profileName,
  }) async {
    try {
      final baseUrl = await _getBaseUrl();
      final uri = Uri.parse('$baseUrl/profile_pricing_operations.php')
          .replace(queryParameters: {
        'router_id': routerId,
        'profile_name': profileName,
      });
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final decoded = _decodeJsonOrThrow(response) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['data'] != null) {
          return Map<String, dynamic>.from(decoded['data']);
        }
        return null;
      } else {
        throw Exception('Failed to load profile pricing');
      }
    } catch (e) {
      throw _friendlyException(e);
    }
  }

  /// Add new profile pricing
  static Future<Map<String, dynamic>> addProfilePricing({
    required String routerId,
    required String profileName,
    required double price,
    String? description,
    bool isActive = true,
    String? adminUsername,
  }) async {
    try {
      final baseUrl = await _getBaseUrl();
      final url =
          '$baseUrl/profile_pricing_operations.php?router_id=$routerId&operation=add';

      if (kDebugMode) {
        print('[ApiService] addProfilePricing URL: $url');
        print(
            '[ApiService] Request body: profile_name=$profileName, price=$price, description=$description');
      }

      final requestBody = {
        'profile_name': profileName,
        'price': price,
        'description': description,
        'is_active': isActive ? 1 : 0,
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (kDebugMode) {
        print('[ApiService] Response status: ${response.statusCode}');
        print('[ApiService] Response body: ${response.body}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Log Activity
        LogService.logActivity(
          username: adminUsername ?? 'System/Admin',
          action: LogService.ACTION_ADD_PROFILE,
          routerId: routerId,
          details: 'added profile pricing: $profileName ($price)',
        );
        return _decodeJsonOrThrow(response) as Map<String, dynamic>;
      } else {
        final decoded = _decodeJsonOrThrow(response) as Map<String, dynamic>;
        final errorMsg = decoded['error'] ??
            'Failed to add profile pricing (Status: ${response.statusCode})';
        throw Exception(errorMsg);
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ApiService] addProfilePricing error: $e');
      }
      throw _friendlyException(e);
    }
  }

  /// Update existing profile pricing
  static Future<Map<String, dynamic>> updateProfilePricing({
    required String routerId,
    int? id,
    String? profileName,
    double? price,
    String? description,
    bool? isActive,
    String? adminUsername,
  }) async {
    try {
      if (id == null && profileName == null) {
        throw Exception('Either id or profileName is required');
      }

      final baseUrl = await _getBaseUrl();
      final body = <String, dynamic>{};
      if (id != null) body['id'] = id;
      if (profileName != null) body['profile_name'] = profileName;
      if (price != null) body['price'] = price;
      if (description != null) body['description'] = description;
      if (isActive != null) body['is_active'] = isActive ? 1 : 0;

      final response = await http.post(
        Uri.parse(
            '$baseUrl/profile_pricing_operations.php?router_id=$routerId&operation=update'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );
      if (response.statusCode == 200) {
        // Log Activity
        LogService.logActivity(
          username: adminUsername ?? 'System/Admin',
          action: LogService.ACTION_EDIT_PROFILE,
          routerId: routerId,
          details: 'changed profile pricing id: $id',
        );
        return _decodeJsonOrThrow(response) as Map<String, dynamic>;
      } else {
        final decoded = _decodeJsonOrThrow(response) as Map<String, dynamic>;
        throw Exception(decoded['error'] ?? 'Failed to update profile pricing');
      }
    } catch (e) {
      throw _friendlyException(e);
    }
  }

  /// Delete profile pricing
  static Future<Map<String, dynamic>> deleteProfilePricing({
    required String routerId,
    int? id,
    String? profileName,
    String? adminUsername,
  }) async {
    try {
      if (id == null && profileName == null) {
        throw Exception('Either id or profileName is required');
      }

      final baseUrl = await _getBaseUrl();
      final body = <String, dynamic>{};
      if (id != null) body['id'] = id;
      if (profileName != null) body['profile_name'] = profileName;

      final response = await http.post(
        Uri.parse(
            '$baseUrl/profile_pricing_operations.php?router_id=$routerId&operation=delete'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );
      if (response.statusCode == 200) {
        // Log Activity
        LogService.logActivity(
          username: adminUsername ?? 'System/Admin',
          action: LogService.ACTION_DELETE_PROFILE,
          routerId: routerId,
          details: 'removed profile pricing: $profileName',
        );
        return _decodeJsonOrThrow(response) as Map<String, dynamic>;
      } else {
        final decoded = _decodeJsonOrThrow(response) as Map<String, dynamic>;
        throw Exception(decoded['error'] ?? 'Failed to delete profile pricing');
      }
    } catch (e) {
      throw _friendlyException(e);
    }
  }

  // Fungsi statis untuk dijalankan di isolate
  static List<Map<String, String>> _normalizeSecrets(
      List<Map<String, dynamic>> secrets) {
    return secrets
        .map((s) => {
              'name': s['name']?.toString() ?? '',
              'password': s['password']?.toString() ?? '',
              'profile': s['profile']?.toString() ?? '',
            })
        .where((u) => (u['name'] as String).isNotEmpty)
        .toList();
  }
  // =====================================================
  // User Group Check (New Integration)
  // =====================================================

  /// Check user group via PHP API (check_user_group.php)
  static Future<String> checkUserGroup({
    required String ip,
    required String port,
    required String username,
    required String password,
  }) async {
    try {
      final baseUrl = await _getBaseUrl();
      final url = '$baseUrl/check_user_group.php';

      if (kDebugMode) {
        print('[ApiService] Checking user group at $url');
      }

      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'ip': ip,
              'port': port,
              'username': username,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = _decodeJsonOrThrow(response) as Map<String, dynamic>;
        if (data['status'] == true) {
          final List<dynamic> users = data['data'];
          if (users.isNotEmpty) {
            final user = users.first;
            return user['group']?.toString() ?? 'No Group';
          } else {
            return 'User not found';
          }
        } else {
          throw Exception(data['error'] ?? 'Unknown error from API');
        }
      } else {
        throw Exception('HTTP Error ${response.statusCode}');
      }
    } catch (e) {
      throw _friendlyException(e);
    }
  }

  // =====================================================
  // Payment Operations
  // =====================================================

  /// Add new payment
  static Future<Map<String, dynamic>> addPayment({
    required String routerId,
    required String userId,
    required double amount,
    required String paymentDate,
    required String method,
    String? note,
    String createdBy = 'Admin',
    String? adminUsername,
    String? customerName,
  }) async {
    try {
      final baseUrl = await _getBaseUrl();
      final url = '$baseUrl/payment_operations.php?operation=add';

      final body = {
        'router_id': routerId,
        'user_id': userId,
        'amount': amount,
        'payment_date': paymentDate,
        'method': method,
        'note': note ?? '',
        'created_by': createdBy,
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final decoded = _decodeJsonOrThrow(response) as Map<String, dynamic>;
        if (decoded['success'] == true) {
          // Log Activity
          LogService.logActivity(
            username: adminUsername ?? createdBy,
            action: LogService.ACTION_ADD_PAYMENT,
            routerId: routerId,
            details:
                'added payment: $amount ($method) for user: ${customerName ?? userId}',
          );
          return decoded;
        } else {
          throw Exception(decoded['error'] ?? 'Gagal menambahkan pembayaran');
        }
      } else {
        throw Exception('Server error (${response.statusCode})');
      }
    } catch (e) {
      throw _friendlyException(e);
    }
  }

  /// Update payment
  static Future<Map<String, dynamic>> updatePayment({
    required String routerId,
    required int id,
    required String userId,
    required double amount,
    required String paymentDate,
    required String method,
    String? note,
    String? adminUsername,
    String? customerName,
  }) async {
    try {
      final baseUrl = await _getBaseUrl();
      final url = '$baseUrl/payment_operations.php?operation=update';

      final body = {
        'router_id': routerId,
        'id': id,
        'user_id': userId,
        'amount': amount,
        'payment_date': paymentDate,
        'method': method,
        'note': note ?? '',
        'created_by': 'Admin', // Keep for backward compatibility if needed
      };

      final response = await http.put(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final decoded = _decodeJsonOrThrow(response) as Map<String, dynamic>;
        if (decoded['success'] == true) {
          // Log Activity
          LogService.logActivity(
            username: adminUsername ?? 'System/Admin',
            action: LogService.ACTION_EDIT_PAYMENT,
            routerId: routerId,
            details:
                'updated payment id: $id for user: ${customerName ?? userId}',
          );

          // Invalidate cache
          final cacheKey = 'all_users_with_payments_$routerId';
          _cache.remove(cacheKey);
          _cacheTimestamps.remove(cacheKey);
        }
        return decoded;
      } else {
        throw Exception('HTTP Error ${response.statusCode}');
      }
    } catch (e) {
      throw _friendlyException(e);
    }
  }

  /// Delete payment
  static Future<Map<String, dynamic>> deletePayment({
    required String routerId,
    required int id,
    String? adminUsername,
    String? customerName,
  }) async {
    try {
      final baseUrl = await _getBaseUrl();
      final url = '$baseUrl/payment_operations.php?operation=delete';

      final body = {
        'router_id': routerId,
        'id': id,
      };

      final response = await http.delete(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final decoded = _decodeJsonOrThrow(response) as Map<String, dynamic>;
        if (decoded['success'] == true) {
          // Log Activity
          LogService.logActivity(
            username: adminUsername ?? 'System/Admin',
            action: LogService.ACTION_DELETE_PAYMENT,
            routerId: routerId,
            details:
                'deleted payment id: $id ${customerName != null ? 'for user: $customerName' : ''}',
          );

          // Invalidate cache
          final cacheKey = 'all_users_with_payments_$routerId';
          _cache.remove(cacheKey);
          _cacheTimestamps.remove(cacheKey);
        }
        return decoded;
      } else {
        throw Exception('HTTP Error ${response.statusCode}');
      }
    } catch (e) {
      throw _friendlyException(e);
    }
  }

  /// Add ODP
  static Future<Map<String, dynamic>> addODP({
    required String routerId,
    required String name,
    required String location,
    required String mapsLink,
    required String type,
    String? splitterType,
    int? ratioUsed,
    int? ratioTotal,
    String? adminUsername,
  }) async {
    try {
      final baseUrl = await _getBaseUrl();
      final url =
          '$baseUrl/odp_operations.php?router_id=$routerId&operation=add';

      final body = {
        'name': name,
        'location': location,
        'maps_link': mapsLink,
        'type': type,
        'splitter_type': splitterType,
        'ratio_used': ratioUsed,
        'ratio_total': ratioTotal,
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final decoded = _decodeJsonOrThrow(response) as Map<String, dynamic>;
        if (decoded['success'] == true) {
          // Log Activity
          LogService.logActivity(
            username: adminUsername ?? 'System/Admin',
            action: LogService.ACTION_ADD_ODP,
            routerId: routerId,
            details: 'added odp: $name',
          );
        }
        return decoded;
      } else {
        throw Exception('HTTP Error ${response.statusCode}');
      }
    } catch (e) {
      throw _friendlyException(e);
    }
  }

  /// Update ODP
  static Future<Map<String, dynamic>> updateODP({
    required String routerId,
    required int id,
    required String name,
    required String location,
    required String mapsLink,
    required String type,
    String? splitterType,
    int? ratioUsed,
    int? ratioTotal,
    String? adminUsername,
  }) async {
    try {
      final baseUrl = await _getBaseUrl();
      final url =
          '$baseUrl/odp_operations.php?router_id=$routerId&operation=update';

      final body = {
        'id': id,
        'name': name,
        'location': location,
        'maps_link': mapsLink,
        'type': type,
        'splitter_type': splitterType,
        'ratio_used': ratioUsed,
        'ratio_total': ratioTotal,
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final decoded = _decodeJsonOrThrow(response) as Map<String, dynamic>;
        if (decoded['success'] == true) {
          // Log Activity
          LogService.logActivity(
            username: adminUsername ?? 'System/Admin',
            action: LogService.ACTION_EDIT_ODP,
            routerId: routerId,
            details: 'updated odp: $name',
          );
        }
        return decoded;
      } else {
        throw Exception('HTTP Error ${response.statusCode}');
      }
    } catch (e) {
      throw _friendlyException(e);
    }
  }

  /// Delete ODP
  static Future<Map<String, dynamic>> deleteODP({
    required String routerId,
    required int id,
    String? adminUsername,
  }) async {
    try {
      final baseUrl = await _getBaseUrl();
      final url =
          '$baseUrl/odp_operations.php?router_id=$routerId&operation=delete';

      final body = {
        'id': id,
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final decoded = _decodeJsonOrThrow(response) as Map<String, dynamic>;
        if (decoded['success'] == true) {
          // Log Activity
          LogService.logActivity(
            username: adminUsername ?? 'System/Admin',
            action: LogService.ACTION_DELETE_ODP,
            routerId: routerId,
            details: 'deleted odp id: $id',
          );
        }
        return decoded;
      } else {
        throw Exception('HTTP Error ${response.statusCode}');
      }
    } catch (e) {
      throw _friendlyException(e);
    }
  }
}
