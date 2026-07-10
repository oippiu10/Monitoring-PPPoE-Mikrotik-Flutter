import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class GenieACSConfigService {
  static const String _urlKey = 'genieacs_url';
  static const String _usernameKey = 'genieacs_username';
  static const String _passwordKey = 'genieacs_password';
  static const String _dataCacheKey = 'genieacs_data_cache';
  static const String _lastFetchKey = 'genieacs_last_fetch';
  static const String _isConnectedKey = 'genieacs_is_connected';

  /// Get GenieACS URL
  static Future<String?> getGenieACSUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_urlKey);
  }

  /// Save GenieACS URL
  static Future<void> setGenieACSUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, url.trim());
  }

  /// Get GenieACS username
  static Future<String?> getGenieACSUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  /// Save GenieACS username
  static Future<void> setGenieACSUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, username.trim());
  }

  /// Get GenieACS password
  static Future<String?> getGenieACSPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_passwordKey);
  }

  /// Save GenieACS password
  static Future<void> setGenieACSPassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_passwordKey, password);
  }

  /// Check if GenieACS is configured
  static Future<bool> isConfigured() async {
    final url = await getGenieACSUrl();
    final username = await getGenieACSUsername();
    final password = await getGenieACSPassword();
    return url != null &&
        url.isNotEmpty &&
        username != null &&
        username.isNotEmpty &&
        password != null &&
        password.isNotEmpty;
  }

  /// Cache GenieACS device data
  static Future<void> cacheDeviceData(
      List<Map<String, dynamic>> devices) async {
    final prefs = await SharedPreferences.getInstance();
    final dataJson = json.encode(devices);
    await prefs.setString(_dataCacheKey, dataJson);
    await prefs.setInt(_lastFetchKey, DateTime.now().millisecondsSinceEpoch);
    await prefs.setBool(_isConnectedKey, true);
  }

  /// Get cached GenieACS device data
  static Future<List<Map<String, dynamic>>> getCachedDeviceData() async {
    final prefs = await SharedPreferences.getInstance();
    final dataJson = prefs.getString(_dataCacheKey);
    if (dataJson == null) return [];

    try {
      final data = json.decode(dataJson);
      if (data is List) {
        return data.map((item) => Map<String, dynamic>.from(item)).toList();
      }
    } catch (e) {
      print('[GenieACSConfig] Error parsing cached data: $e');
    }
    return [];
  }

  /// Check if cached data exists and is recent (< 5 minutes)
  static Future<bool> hasRecentCache({int maxAgeMinutes = 5}) async {
    final prefs = await SharedPreferences.getInstance();
    final lastFetch = prefs.getInt(_lastFetchKey);
    if (lastFetch == null) return false;

    final age = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(lastFetch));
    return age.inMinutes < maxAgeMinutes;
  }

  /// Get last fetch time
  static Future<DateTime?> getLastFetchTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastFetchKey);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  /// Set connection status
  static Future<void> setConnectionStatus(bool isConnected) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isConnectedKey, isConnected);
  }

  /// Get connection status
  static Future<bool> getConnectionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isConnectedKey) ?? false;
  }

  /// Clear all GenieACS data
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_urlKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_passwordKey);
    await prefs.remove(_dataCacheKey);
    await prefs.remove(_lastFetchKey);
    await prefs.remove(_isConnectedKey);
  }

  /// Normalize GenieACS URL
  static String normalizeUrl(String url) {
    String value = url.trim();
    if (value.isEmpty) return '';

    // Add http:// if no scheme
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'http://$value';
    }

    // Remove trailing slash
    if (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }

    return value;
  }
}
