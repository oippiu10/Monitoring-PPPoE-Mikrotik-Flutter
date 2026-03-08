import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ConfigService {
  static const String _baseUrlKey = 'api_base_url';
  static const String _defaultBaseUrl = 'https://cmmnetwork.online/api';

  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_baseUrlKey) ?? _defaultBaseUrl;
  }

  /// Get API URL (alias for getBaseUrl for backward compatibility)
  static Future<String> getApiUrl() async {
    return getBaseUrl();
  }

  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, normalizeBaseUrl(url));
  }

  static Future<void> resetBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_baseUrlKey);
  }

  static String normalizeBaseUrl(String url) {
    String value = url.trim();
    if (value.isEmpty) return _defaultBaseUrl;
    // add scheme if missing
    if (!value.contains('://')) {
      value = 'https://$value';
    }
    // remove trailing slash
    if (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  static Future<Map<String, dynamic>> testConnectionDetailed(
      {String? baseUrlOverride,
      Duration timeout = const Duration(seconds: 8)}) async {
    final base = normalizeBaseUrl(baseUrlOverride ?? await getBaseUrl());
    // Add router_id parameter for testing
    final uri = Uri.parse('$base/get_all_users.php?router_id=test');
    final stopwatch = Stopwatch()..start();

    try {
      final resp = await http
          .get(uri, headers: {'Accept': 'application/json'}).timeout(timeout);
      stopwatch.stop();

      final responseTime = stopwatch.elapsedMilliseconds;
      final contentType = resp.headers['content-type'] ?? '';
      final isJson = contentType.contains('application/json');

      Map<String, dynamic> result = {
        'success': resp.statusCode == 200 && isJson,
        'statusCode': resp.statusCode,
        'responseTime': responseTime,
        'contentType': contentType,
        'isJson': isJson,
        'url': uri.toString(),
      };

      if (resp.statusCode == 200) {
        if (isJson) {
          try {
            final data = json.decode(resp.body);
            result['data'] = data;
            result['dataPreview'] = _getDataPreview(data);
            result['userCount'] = data is Map && data.containsKey('users')
                ? (data['users'] as List).length
                : 0;
          } catch (e) {
            result['success'] = false;
            result['parseError'] = e.toString();
          }
        } else {
          result['bodyPreview'] = resp.body.length > 200
              ? '${resp.body.substring(0, 200)}...'
              : resp.body;
        }
      } else {
        result['bodyPreview'] = resp.body.length > 200
            ? '${resp.body.substring(0, 200)}...'
            : resp.body;
      }

      return result;
    } catch (e) {
      stopwatch.stop();
      return {
        'success': false,
        'error': e.toString(),
        'responseTime': stopwatch.elapsedMilliseconds,
        'url': uri.toString(),
      };
    }
  }

  static String _getDataPreview(dynamic data) {
    if (data is Map) {
      if (data.containsKey('users') && data['users'] is List) {
        final users = data['users'] as List;
        return '${users.length} users found';
      } else if (data.containsKey('success')) {
        return 'API Response: ${data['success']}';
      }
    }
    return 'Data received';
  }
}
