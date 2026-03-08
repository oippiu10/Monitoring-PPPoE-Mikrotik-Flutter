import 'dart:async';

import 'mikrotik_service.dart';
import 'mikrotik_api_client.dart';

class MikrotikNativeService implements MikrotikService {
  String? ip;
  String? port;
  String? username;
  String? password;
  bool enableLogging;

  MikrotikApiClient? _client;

  @override
  String get baseUrl => 'api://$ip:$port';

  MikrotikNativeService({
    this.ip,
    this.port,
    this.username,
    this.password,
    this.enableLogging = false,
  });

  Completer<void>? _connectionCompleter;

  /// Memastikan koneksi aktif sebelum mengirim command
  Future<void> _ensureConnected() async {
    // Jika sudah connected, return
    if (_client != null && _client!.isLoggedIn) return;

    // Jika sedang connecting, tunggu sampai selesai
    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      await _connectionCompleter!.future;
      // Cek lagi setelah menunggu
      if (_client != null && _client!.isLoggedIn) return;
    }

    // Mulai koneksi baru
    _connectionCompleter = Completer<void>();

    try {
      // Pastikan client lama ditutup jika ada
      _client?.close();

      _client = MikrotikApiClient();
      if (ip == null || port == null || username == null || password == null) {
        throw Exception('Kredensial tidak lengkap');
      }

      print('[NATIVE-SVC] Connecting to $ip:$port...');
      await _client!
          .connect(ip!, int.parse(port!), enableLogging: enableLogging);
      await _client!.login(username!, password!);
      print('[NATIVE-SVC] Connected & Logged in!');

      _connectionCompleter!.complete();
    } catch (e) {
      print('[NATIVE-SVC] Connection failed: $e');
      // Prevent unhandled exception in the completer if no one is listening
      _connectionCompleter!.future.catchError((_) {});
      _connectionCompleter!.completeError(e);
      _client = null; // Reset client on failure
      rethrow;
    } finally {
      // Bersihkan completer jika sudah selesai (opsional, tapi bagus untuk GC)
      // _connectionCompleter = null; // Jangan null-kan agar request berikutnya bisa cek isCompleted?
      // Tapi logic di atas cek isCompleted, jadi aman.
      // Reset completer hanya jika kita mau allow retry nanti.
      // Untuk sekarang biarkan saja.
    }
  }

  /// Menutup koneksi (opsional, bisa dipanggil saat logout)
  void dispose() {
    _client?.close();
    _client = null;
  }

  // --- Implementasi Method yang sama dengan MikrotikService ---

  // Helper to check for API errors (!trap)
  void _checkForError(List<Map<String, String>> response) {
    final trap = response.firstWhere(
      (r) => r.containsKey('!trap'),
      orElse: () => {},
    );
    if (trap.isNotEmpty) {
      throw Exception(trap['message'] ?? 'Terjadi kesalahan pada Native API');
    }
  }

  Future<Map<String, dynamic>> getIdentity() async {
    await _ensureConnected();
    final response = await _client!.talk(['/system/identity/print']);
    _checkForError(response);

    final data = response.firstWhere(
      (item) => !item.containsKey('!done') && !item.containsKey('!trap'),
      orElse: () => {},
    );

    if (data.isEmpty) return {};
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> getResource() async {
    await _ensureConnected();
    final response = await _client!.talk(['/system/resource/print']);
    _checkForError(response);

    final data = response.firstWhere(
      (item) => !item.containsKey('!done') && !item.containsKey('!trap'),
      orElse: () => {},
    );
    return Map<String, dynamic>.from(data);
  }

  Future<List<Map<String, dynamic>>> getPPPActive() async {
    await _ensureConnected();
    final response = await _client!.talk(['/ppp/active/print']);
    _checkForError(response);

    return response
        .where(
            (item) => !item.containsKey('!done') && !item.containsKey('!trap'))
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getPPPSecret() async {
    await _ensureConnected();
    final response = await _client!.talk(['/ppp/secret/print']);
    _checkForError(response);

    return response
        .where(
            (item) => !item.containsKey('!done') && !item.containsKey('!trap'))
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getInterface() async {
    await _ensureConnected();
    final response = await _client!.talk(['/interface/print']);
    _checkForError(response);

    return response
        .where(
            (item) => !item.containsKey('!done') && !item.containsKey('!trap'))
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getLog() async {
    await _ensureConnected();
    final response = await _client!.talk(['/log/print']);
    _checkForError(response);

    return response
        .where(
            (item) => !item.containsKey('!done') && !item.containsKey('!trap'))
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getPPPProfile() async {
    await _ensureConnected();
    final response = await _client!.talk(['/ppp/profile/print']);
    _checkForError(response);

    return response
        .where(
            (item) => !item.containsKey('!done') && !item.containsKey('!trap'))
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  /// Add new PPP Profile to Mikrotik using Native API
  @override
  Future<Map<String, dynamic>> addPPPProfile(Map<String, String> data) async {
    await _ensureConnected();

    List<String> cmd = ['/ppp/profile/add'];
    data.forEach((key, value) {
      cmd.add('=$key=$value');
    });

    final response = await _client!.talk(cmd);
    _checkForError(response);

    return {
      'success': true,
      'message': 'Profile berhasil ditambahkan',
    };
  }

  /// Update existing PPP Profile in Mikrotik using Native API
  @override
  Future<Map<String, dynamic>> updatePPPProfile(
      String profileId, Map<String, String> data) async {
    await _ensureConnected();

    List<String> cmd = ['/ppp/profile/set', '=.id=$profileId'];
    data.forEach((key, value) {
      cmd.add('=$key=$value');
    });

    final response = await _client!.talk(cmd);
    _checkForError(response);

    return {
      'success': true,
      'message': 'Profile berhasil diperbarui',
    };
  }

  /// Delete PPP Profile from Mikrotik using Native API
  @override
  Future<Map<String, dynamic>> deletePPPProfile(String profileId) async {
    await _ensureConnected();

    final response =
        await _client!.talk(['/ppp/profile/remove', '=.id=$profileId']);
    _checkForError(response);

    return {
      'success': true,
      'message': 'Profile berhasil dihapus',
    };
  }

  Future<void> addPPPSecret(Map<String, String> data) async {
    await _ensureConnected();

    List<String> cmd = ['/ppp/secret/add'];
    data.forEach((key, value) {
      cmd.add('=$key=$value');
    });

    // Default service pppoe if not set
    if (!data.containsKey('service')) {
      cmd.add('=service=pppoe');
    }

    final response = await _client!.talk(cmd);
    _checkForError(response);
  }

  @override
  Future<Map<String, dynamic>> updatePPPSecret(
      String name, Map<String, String> data) async {
    await _ensureConnected();

    // Cari ID dulu berdasarkan nama
    final find = await _client!.talk(['/ppp/secret/print', '?name=$name']);
    _checkForError(find);

    final user = find.firstWhere(
      (item) => !item.containsKey('!done') && !item.containsKey('!trap'),
      orElse: () => {},
    );

    if (user.isEmpty || !user.containsKey('.id')) {
      throw Exception('User tidak ditemukan');
    }

    List<String> cmd = ['/ppp/secret/set', '=.id=${user['.id']}'];
    data.forEach((key, value) {
      cmd.add('=$key=$value');
    });

    final response = await _client!.talk(cmd);
    _checkForError(response);

    // Success - now try to disconnect if user is active
    Map<String, dynamic> disconnectResult = {};

    try {
      // Disconnect using OLD username (before change)
      disconnectResult = await disconnectUserIfActive(name);
    } catch (e) {
      // Ignore disconnect errors - update was successful
      if (enableLogging) {
        // ignore: avoid_print
        print('[UPDATE-NATIVE] Disconnect failed but update succeeded: $e');
      }
    }

    final wasDisconnected = disconnectResult['disconnected'] ?? false;

    return {
      'success': true,
      'disconnected': wasDisconnected,
      'disconnectDetails': disconnectResult,
      'message': wasDisconnected
          ? 'User berhasil diperbarui dan koneksi aktif telah diputus'
          : 'User berhasil diperbarui',
    };
  }

  Future<void> deletePPPSecret(String id) async {
    await _ensureConnected();
    final response = await _client!.talk(['/ppp/secret/remove', '=.id=$id']);
    _checkForError(response);
  }

  Future<void> disconnectSession(String sessionId) async {
    await _ensureConnected();
    final response =
        await _client!.talk(['/ppp/active/remove', '=.id=$sessionId']);
    _checkForError(response);
  }

  /// Disconnect user if currently active
  /// Returns Map with disconnect status and details
  /// Silent fail - tidak throw exception jika gagal
  @override
  Future<Map<String, dynamic>> disconnectUserIfActive(String username) async {
    try {
      if (enableLogging) {
        // ignore: avoid_print
        print('[DISCONNECT-NATIVE] ========================================');
        // ignore: avoid_print
        print('[DISCONNECT-NATIVE] Checking if user "$username" is active...');
      }

      // Get active connections
      final activeConnections = await getPPPActive();

      if (enableLogging) {
        // ignore: avoid_print
        print(
            '[DISCONNECT-NATIVE] Found ${activeConnections.length} active connections');
      }

      // Find user in active connections (case-insensitive)
      final userConnection = activeConnections.firstWhere(
        (conn) =>
            conn['name']?.toString().toLowerCase() == username.toLowerCase(),
        orElse: () => {},
      );

      // If user is active, disconnect
      if (userConnection.isNotEmpty && userConnection['.id'] != null) {
        final sessionId = userConnection['.id'].toString();
        final address = userConnection['address']?.toString() ?? 'N/A';
        final uptime = userConnection['uptime']?.toString() ?? 'N/A';

        if (enableLogging) {
          // ignore: avoid_print
          print('[DISCONNECT-NATIVE] ✓ User found in active connections');
          // ignore: avoid_print
          print('[DISCONNECT-NATIVE]   - Session ID: $sessionId');
          // ignore: avoid_print
          print('[DISCONNECT-NATIVE]   - Address: $address');
          // ignore: avoid_print
          print('[DISCONNECT-NATIVE]   - Uptime: $uptime');
          // ignore: avoid_print
          print('[DISCONNECT-NATIVE] Disconnecting session...');
        }

        await disconnectSession(sessionId);

        if (enableLogging) {
          // ignore: avoid_print
          print(
              '[DISCONNECT-NATIVE] ✓✓✓ User "$username" disconnected successfully!');
          // ignore: avoid_print
          print('[DISCONNECT-NATIVE] ========================================');
        }

        return {
          'disconnected': true,
          'sessionId': sessionId,
          'address': address,
          'uptime': uptime,
        };
      }

      if (enableLogging) {
        // ignore: avoid_print
        print('[DISCONNECT-NATIVE] ✗ User "$username" is NOT active');
        // ignore: avoid_print
        print('[DISCONNECT-NATIVE] ========================================');
      }

      return {
        'disconnected': false,
        'reason': 'User not found in active connections',
      };
    } catch (e) {
      // Silent fail - jangan throw exception
      // Karena disconnect adalah optional, update secret tetap berhasil
      if (enableLogging) {
        // ignore: avoid_print
        print('[DISCONNECT-NATIVE] ✗✗✗ FAILED to disconnect user "$username"');
        // ignore: avoid_print
        print('[DISCONNECT-NATIVE] Error: $e');
        // ignore: avoid_print
        print('[DISCONNECT-NATIVE] ========================================');
      }

      return {
        'disconnected': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> getTraffic(String interfaceId) async {
    await _ensureConnected();
    // Monitor traffic (sekali ambil snapshot)
    // API command: /interface/monitor-traffic interface=ID once
    final response = await _client!.talk(
        ['/interface/monitor-traffic', '=interface=$interfaceId', '=once']);
    _checkForError(response);

    final data = response.firstWhere(
      (item) => !item.containsKey('!done') && !item.containsKey('!trap'),
      orElse: () => {},
    );

    if (data.isEmpty) {
      throw Exception('Gagal mengambil data traffic');
    }

    // Konversi string ke format yang diharapkan UI
    // UI mengharapkan: tx-rate, rx-rate (dalam Mbps atau bps tergantung UI)
    // API mengembalikan 'rx-bits-per-second' dan 'tx-bits-per-second'

    double rxBps = double.tryParse(data['rx-bits-per-second'] ?? '0') ?? 0;
    double txBps = double.tryParse(data['tx-bits-per-second'] ?? '0') ?? 0;

    // MikrotikService lama mengembalikan Mbps (byte * 8 / 1jt), tapi API monitor-traffic sudah bits-per-second
    // Jadi tinggal bagi 1.000.000 untuk jadi Mbps

    return {
      'rx-rate': rxBps / 1000000.0,
      'tx-rate': txBps / 1000000.0,
      'tx-packet-rate': int.tryParse(data['tx-packets-per-second'] ?? '0') ?? 0,
      'rx-packet-rate': int.tryParse(data['rx-packets-per-second'] ?? '0') ?? 0,
      // Data total bytes mungkin tidak ada di monitor-traffic, harus ambil dari /interface/print stats
      // Untuk simplifikasi, kita return 0 atau ambil dari getInterface jika perlu
      'total-tx-byte': '0',
      'total-rx-byte': '0',
      'total-tx-packet': '0',
      'total-rx-packet': '0',
    };
  }

  Future<Map<String, dynamic>> getLicense() async {
    await _ensureConnected();
    final response = await _client!.talk(['/system/license/print']);
    _checkForError(response);

    final data = response.firstWhere(
      (item) => !item.containsKey('!done') && !item.containsKey('!trap'),
      orElse: () => {},
    );
    return Map<String, dynamic>.from(data);
  }

  // System User methods
  Future<List<Map<String, dynamic>>> getSystemUsers() async {
    await _ensureConnected();
    final response = await _client!.talk(['/user/print']);
    _checkForError(response);

    return response
        .where(
            (item) => !item.containsKey('!done') && !item.containsKey('!trap'))
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getSystemUserGroups() async {
    await _ensureConnected();
    final response = await _client!.talk(['/user/group/print']);
    _checkForError(response);

    return response
        .where(
            (item) => !item.containsKey('!done') && !item.containsKey('!trap'))
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  // Fallback method
  Future<String> getRouterSerialOrId() async {
    print('[ROUTER-ID-NATIVE] ========================================');
    print('[ROUTER-ID-NATIVE] Starting router ID detection (Native API)...');
    print('[ROUTER-ID-NATIVE] IP: $ip, Port: $port');

    // Pastikan koneksi siap
    try {
      await _ensureConnected();
      print('[ROUTER-ID-NATIVE] ✓ Connection established');
    } catch (e) {
      print('[ROUTER-ID-NATIVE] ✗ Connection failed: $e');
    }

    // 1. Cek /system/license (Prioritas Utama)
    try {
      print(
          '[ROUTER-ID-NATIVE] Attempting to get license from /system/license...');
      final lic = await _client!.talk(['/system/license/print']);
      print('[ROUTER-ID-NATIVE] License response: $lic');

      final data = lic.firstWhere(
          (i) => !i.containsKey('!done') && !i.containsKey('!trap'),
          orElse: () => {});

      print('[ROUTER-ID-NATIVE] Parsed license data: $data');

      final serial = data['serial-number'];
      print('[ROUTER-ID-NATIVE] serial-number: ${serial ?? "null"}');
      if (serial != null && serial.toString().isNotEmpty) {
        print('[ROUTER-ID-NATIVE] ✓✓✓ SUCCESS! Using serial-number: $serial');
        print('[ROUTER-ID-NATIVE] ========================================');
        return serial.toString();
      }

      final softwareId = data['software-id'];
      print('[ROUTER-ID-NATIVE] software-id: ${softwareId ?? "null"}');
      if (softwareId != null && softwareId.toString().isNotEmpty) {
        print('[ROUTER-ID-NATIVE] ✓✓✓ SUCCESS! Using software-id: $softwareId');
        print('[ROUTER-ID-NATIVE] ========================================');
        return softwareId.toString();
      }

      print(
          '[ROUTER-ID-NATIVE] ✗ No serial-number or software-id found in license');
      print('[ROUTER-ID-NATIVE] Available keys: ${data.keys.toList()}');
    } catch (e) {
      print('[ROUTER-ID-NATIVE] ✗✗✗ FAILED to get license!');
      print('[ROUTER-ID-NATIVE] Error type: ${e.runtimeType}');
      print('[ROUTER-ID-NATIVE] Error message: $e');
    }

    // 2. Cek /system/resource (Fallback jika license gagal)
    try {
      print('[ROUTER-ID-NATIVE] Attempting to get resource info...');
      final res = await getResource();
      print('[ROUTER-ID-NATIVE] Resource response: $res');

      // Beberapa router menyimpan serial di resource
      // Atau kita bisa pakai board-name sebagai bagian dari ID jika serial tidak ada
      if (res['board-name'] != null) {
        print('[ROUTER-ID-NATIVE] Found board-name: ${res['board-name']}');
        // Jika ada serial di resource, pakai itu
        // Note: key serial di resource mungkin berbeda tergantung versi, tapi biasanya tidak ada.
        // Namun kita bisa return board-name sebagai identitas yang lebih baik daripada "RouterOS"

        // Tapi untuk konsistensi dengan logic lama, kita coba cari serial lagi atau return board-name
        // Jika board-name ada, kita bisa pakai itu untuk ID yang lebih deskriptif
        // return 'RB-${res['board-name']}@$ip:$port';
      }
    } catch (e) {
      print('[ROUTER-ID-NATIVE] ✗ Error fetching resource: $e');
    }

    // 3. Fallback: Identity + IP
    try {
      print('[ROUTER-ID-NATIVE] ⚠ Falling back to identity + IP:port...');
      final id = await getIdentity();
      final name = id['name']?.toString() ?? 'UNKNOWN';
      print('[ROUTER-ID-NATIVE] Identity name: $name');

      // Jika nama masih default "RouterOS", coba ambil board-name dari resource lagi untuk mempercantik
      if (name == 'RouterOS') {
        try {
          final res = await getResource();
          final boardName = res['board-name']?.toString();
          if (boardName != null && boardName.isNotEmpty) {
            final fallbackId = 'RB-$boardName@$ip:$port';
            print(
                '[ROUTER-ID-NATIVE] ⚠⚠⚠ WARNING! Using fallback ID (with board-name): $fallbackId');
            print(
                '[ROUTER-ID-NATIVE] This will cause duplicate entries if IP/port changes!');
            print(
                '[ROUTER-ID-NATIVE] ========================================');
            return fallbackId;
          }
        } catch (e) {
          print('[ROUTER-ID-NATIVE] Could not get board-name: $e');
        }
      }

      final fallbackId = 'RB-$name@$ip:$port';
      print('[ROUTER-ID-NATIVE] ⚠⚠⚠ WARNING! Using fallback ID: $fallbackId');
      print(
          '[ROUTER-ID-NATIVE] This will cause duplicate entries if IP/port changes!');
      print('[ROUTER-ID-NATIVE] ========================================');
      return fallbackId;
    } catch (e) {
      print('[ROUTER-ID-NATIVE] ✗✗✗ CRITICAL! Even identity fetch failed!');
      print('[ROUTER-ID-NATIVE] Error: $e');
      final lastResort = '$ip:$port';
      print('[ROUTER-ID-NATIVE] Using last resort ID: $lastResort');
      print('[ROUTER-ID-NATIVE] ========================================');
      return lastResort;
    }
  }

  @override
  Future<String> getUserGroupFromPPPSecret(String username) async {
    try {
      final secrets = await getPPPSecret();
      final userSecret = secrets.firstWhere(
        (secret) =>
            secret['name'] != null && secret['name'].toString() == username,
        orElse: () => {},
      );

      if (userSecret.isNotEmpty) {
        return userSecret['profile']?.toString() ?? 'No profile assigned';
      } else {
        return 'User not found';
      }
    } catch (e) {
      throw Exception('Error fetching user group from PPP secret: $e');
    }
  }
}
