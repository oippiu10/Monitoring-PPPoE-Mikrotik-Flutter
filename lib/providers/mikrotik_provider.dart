import 'package:flutter/foundation.dart';
import '../services/mikrotik_service.dart';

class MikrotikProvider with ChangeNotifier {
  final MikrotikService _service;
  bool _isLoading = false;
  String? _error;

  // Data
  String? _identity;
  Map<String, dynamic>? _resource;
  Map<String, dynamic>? _license;
  List<Map<String, dynamic>> _pppSessions = [];
  List<Map<String, dynamic>> _pppSecrets = [];
  List<Map<String, dynamic>> _pppProfiles = [];

  // Tambahkan cache timestamp
  DateTime? _pppSecretsLastFetch;
  DateTime? _pppSessionsLastFetch;

  MikrotikProvider(this._service);

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get identity => _identity;
  List<Map<String, dynamic>> get pppSessions => _pppSessions;
  List<Map<String, dynamic>> get pppSecrets => _pppSecrets;
  List<Map<String, dynamic>> get pppProfiles => _pppProfiles;
  Map<String, dynamic>? get resource => _resource;
  Map<String, dynamic>? get license => _license;

  MikrotikService get service => _service;

  // Menghitung total user offline (ppp/secret yang tidak ada di ppp/active)
  int get totalOfflineUsers {
    if (_pppSecrets.isEmpty) return 0;
    final activeNames =
        _pppSessions.map((session) => session['name'] as String).toSet();
    return _pppSecrets
        .where((secret) => !activeNames.contains(secret['name']))
        .length;
  }

  // Resource getters
  double get cpuLoad {
    final value = _resource?['cpu-load'];
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String get freeMemory => _resource?['free-memory']?.toString() ?? 'N/A';
  String get totalMemory => _resource?['total-memory']?.toString() ?? 'N/A';
  String get uptime => _resource?['uptime'] ?? 'N/A';

  Future<void> refreshData({bool forceRefresh = false}) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final now = DateTime.now();
      final cacheValid = _pppSecretsLastFetch != null &&
          now.difference(_pppSecretsLastFetch!) < Duration(minutes: 5);

      if (!forceRefresh &&
          cacheValid &&
          _pppSecrets.isNotEmpty &&
          _pppSessions.isNotEmpty) {
        // Pakai cache, tidak fetch ulang
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Fetch all data in parallel (license is optional, so handle separately)
      final results = await Future.wait([
        _service.getIdentity(),
        _service.getResource(),
        _service.getPPPActive(),
        _service.getPPPSecret(),
        _service.getPPPProfile(),
      ]);

      // Try to fetch license separately (non-blocking)
      Map<String, dynamic>? licenseData;
      try {
        licenseData = await _service.getLicense();
      } catch (e) {
        // License fetch failed, but continue with other data
        print('Warning: Failed to fetch license: $e');
      }

      // Cast results to correct types
      final identityData = results[0] as Map<String, dynamic>;
      final resourceData = results[1] as Map<String, dynamic>;
      final pppData = results[2] as List<Map<String, dynamic>>;
      final pppSecretData = results[3] as List<Map<String, dynamic>>;
      final pppProfileData = results[4] as List<Map<String, dynamic>>;

      _identity = identityData['name'] as String?;
      _resource = resourceData;
      _license = licenseData;
      _pppSessions = pppData;
      _pppSecrets = pppSecretData;
      _pppProfiles = pppProfileData;
      _pppSecretsLastFetch = now;
      _pppSessionsLastFetch = now;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      if (hasListeners) notifyListeners();
    }
  }

  Future<void> disconnectSession(String sessionId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _service.disconnectSession(sessionId);
      await refreshData(); // Refresh all data after disconnecting
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> fetchPPPSecrets({bool forceRefresh = false}) async {
    try {
      _isLoading = true;
      notifyListeners();
      final now = DateTime.now();
      final cacheValid = _pppSecretsLastFetch != null &&
          now.difference(_pppSecretsLastFetch!) < Duration(minutes: 5);
      if (!forceRefresh && cacheValid && _pppSecrets.isNotEmpty) {
        _isLoading = false;
        notifyListeners();
        return;
      }
      final secrets = await _service.getPPPSecret();
      _pppSecrets = secrets;
      _pppSecretsLastFetch = now;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch only PPP active and secret (for realtime polling of active/offline)
  Future<void> fetchPPPStatusOnly() async {
    try {
      final results = await Future.wait([
        _service.getPPPActive(),
        _service.getPPPSecret(),
      ]);
      _pppSessions = results[0] as List<Map<String, dynamic>>;
      _pppSecrets = results[1] as List<Map<String, dynamic>>;
      if (hasListeners) notifyListeners();
    } catch (e) {
      // Optional: handle error, but don't set _isLoading/_error global state
    }
  }

  /// Fetch only resource and identity data (for System Resource screen)
  /// This reduces API calls from 6+ to just 2 (identity + resource)
  Future<void> fetchResourceOnly() async {
    try {
      final results = await Future.wait([
        _service.getIdentity(),
        _service.getResource(),
      ]);

      final identityData = results[0] as Map<String, dynamic>;
      final resourceData = results[1] as Map<String, dynamic>;

      _identity = identityData['name'] as String?;
      _resource = resourceData;

      if (hasListeners) notifyListeners();
    } catch (e) {
      // Optional: handle error, but don't set _isLoading/_error global state
      print('Warning: Failed to fetch resource only: $e');
    }
  }
}
