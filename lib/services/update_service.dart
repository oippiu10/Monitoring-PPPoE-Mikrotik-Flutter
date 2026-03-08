import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'config_service.dart';

/// Update information from server
class UpdateInfo {
  final bool updateAvailable;
  final bool updateRequired;
  final String latestVersion;
  final int latestBuild;
  final String apkUrl;
  final int apkSizeBytes;
  final String minimumRequiredVersion;
  final List<Map<String, dynamic>> releaseNotes;
  final String timestamp;

  UpdateInfo({
    required this.updateAvailable,
    required this.updateRequired,
    required this.latestVersion,
    required this.latestBuild,
    required this.apkUrl,
    required this.apkSizeBytes,
    required this.minimumRequiredVersion,
    required this.releaseNotes,
    required this.timestamp,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      updateAvailable: json['update_available'] ?? false,
      updateRequired: json['update_required'] ?? false,
      latestVersion: json['latest_version'] ?? '',
      latestBuild: json['latest_build'] ?? 0,
      apkUrl: json['apk_url'] ?? '',
      apkSizeBytes: json['apk_size'] ?? 0,
      minimumRequiredVersion: json['minimum_required_version'] ?? '',
      releaseNotes:
          List<Map<String, dynamic>>.from(json['release_notes'] ?? []),
      timestamp: json['timestamp'] ?? '',
    );
  }

  String get formattedSize {
    if (apkSizeBytes == 0) return 'Unknown';
    final mb = apkSizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class UpdateService {
  /// Check if update is available from server
  static Future<UpdateInfo> checkForUpdate() async {
    try {
      final baseUrl = await ConfigService.getBaseUrl();
      final packageInfo = await PackageInfo.fromPlatform();

      final currentVersion = packageInfo.version;
      final currentBuild = int.parse(packageInfo.buildNumber);

      final url =
          Uri.parse('$baseUrl/check_update.php').replace(queryParameters: {
        'current_version': currentVersion,
        'current_build': currentBuild.toString(),
      });

      print('[UPDATE] Checking update from: $url');

      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      print(
          '[UPDATE] Response: ${response.statusCode}, Content-Type: ${response.headers['content-type']}');
      print(
          '[UPDATE] Body preview: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');

      // Check for HTML response (indicates redirect or error page)
      final contentType = response.headers['content-type'] ?? '';
      if (contentType.contains('text/html') ||
          response.body.contains('<!DOCTYPE') ||
          response.body.contains('<html')) {
        throw Exception(
            'Server returned HTML instead of JSON. Check if check_update.php is uploaded correctly.');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return UpdateInfo.fromJson(data);
        } else {
          throw Exception(data['error'] ?? 'Failed to check for updates');
        }
      } else if (response.statusCode == 301 || response.statusCode == 302) {
        // Handle redirect
        throw Exception(
            'HTTP ${response.statusCode}: Redirect detected. Make sure using HTTPS or check server configuration.');
      } else {
        throw Exception(
            'HTTP ${response.statusCode}: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}');
      }
    } catch (e) {
      throw Exception('Error checking for updates: $e');
    }
  }

  /// Get current app version
  static Future<String> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  /// Get current build number
  static Future<int> getCurrentBuild() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return int.parse(packageInfo.buildNumber);
  }

  /// Download APK from URL (for manual download)
  static String getDownloadUrl() {
    // This will be set from UpdateInfo.apkUrl after checking update
    return '';
  }

  /// Register device to backend
  static Future<bool> registerDevice({
    required String deviceId,
    required String deviceModel,
    required String appVersion,
    required int buildNumber,
  }) async {
    try {
      final baseUrl = await ConfigService.getBaseUrl();
      final url = Uri.parse('$baseUrl/device_token_operations.php')
          .replace(queryParameters: {'action': 'register'});

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'device_id': deviceId,
              'device_model': deviceModel,
              'app_version': appVersion,
              'build_number': buildNumber,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('[UPDATE] Failed to register device: $e');
      return false;
    }
  }

  /// Update last check timestamp on backend
  static Future<bool> updateLastCheck(String deviceId) async {
    try {
      final baseUrl = await ConfigService.getBaseUrl();
      final url = Uri.parse('$baseUrl/device_token_operations.php')
          .replace(queryParameters: {'action': 'update_last_check'});

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'device_id': deviceId}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('[UPDATE] Failed to update last check: $e');
      return false;
    }
  }

  /// Toggle notification setting on backend
  static Future<bool> toggleNotification(String deviceId, bool enabled) async {
    try {
      final baseUrl = await ConfigService.getBaseUrl();
      final url = Uri.parse('$baseUrl/device_token_operations.php')
          .replace(queryParameters: {'action': 'toggle_notification'});

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'device_id': deviceId,
              'enabled': enabled,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('[UPDATE] Failed to toggle notification: $e');
      return false;
    }
  }

  /// Format size from bytes to human readable
  static String formatBytes(int bytes) {
    if (bytes == 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    final i = (bytes / k).floor();
    return '${(bytes / k / i).toStringAsFixed(1)} ${sizes[i]}';
  }

  /// Download APK file and return path
  static Future<String> downloadApk(
      String apkUrl, Function(int, int) onProgress) async {
    try {
      // Get downloads directory
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        // Try to access public Downloads folder first
        // This requires storage permission on some Android versions
        if (await _checkStoragePermission()) {
          downloadsDir = await getExternalStorageDirectory();
          if (downloadsDir != null) {
            // Navigate to public Download folder
            downloadsDir = Directory('${downloadsDir.parent.path}/Download');
          }
        }

        // Fallback to app directory if Download folder not accessible
        if (downloadsDir == null || !await downloadsDir.exists()) {
          downloadsDir = await getExternalStorageDirectory();
          if (downloadsDir != null) {
            // Use app's internal directory as fallback
          } else {
            throw Exception('Could not access external storage');
          }
        }
      } else {
        downloadsDir = await getDownloadsDirectory();
      }

      if (downloadsDir == null) {
        throw Exception('Could not find downloads directory');
      }

      final filePath = '${downloadsDir.path}/app-release.apk';
      final file = File(filePath);

      // Delete old APK if exists
      if (await file.exists()) {
        await file.delete();
      }

      // Create directory if not exists
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      // Download file
      final request = http.Request('GET', Uri.parse(apkUrl));
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        throw Exception('Failed to download: HTTP ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? 0;
      final sink = file.openWrite();
      int downloadedBytes = 0;

      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          downloadedBytes += chunk.length;
          onProgress(downloadedBytes, totalBytes);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      return filePath;
    } catch (e) {
      throw Exception('Download error: $e');
    }
  }

  /// Check and request storage permission if needed
  static Future<bool> _checkStoragePermission() async {
    try {
      final status = await Permission.storage.status;
      if (status.isDenied) {
        final result = await Permission.storage.request();
        return result.isGranted;
      }
      return status.isGranted;
    } catch (e) {
      // Permission check failed, assume not granted
      return false;
    }
  }

  /// Install APK file (opens system installer)
  static Future<bool> installApk(String filePath) async {
    try {
      if (!Platform.isAndroid) {
        return false;
      }

      // Check if file exists
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('APK file not found');
      }

      // Check for install packages permission on Android 8+
      if (await Permission.requestInstallPackages.status.isDenied) {
        final status = await Permission.requestInstallPackages.request();
        if (status.isDenied) {
          // If denied, we can't install directly.
          // Usually we should guide user to settings, but OpenFile might handle the intent.
          // Let's try to proceed, or return false to let UI handle it.
          // Ideally, we should show a dialog explaining why we need this permission.
          // For now, let's just try to open it, as some devices might prompt within the intent.
        }
      }

      // Open APK file using OpenFile
      // This will trigger the system installer
      final result = await OpenFile.open(filePath);

      return result.type == ResultType.done ||
          result.type == ResultType.noAppToOpen;
    } catch (e) {
      throw Exception('Install error: $e');
    }
  }

  /// Check notification queue from server
  static Future<Map<String, dynamic>> checkNotificationQueue(
      String deviceId) async {
    try {
      final apiUrl = await ConfigService.getApiUrl();
      final url =
          '$apiUrl/notification_queue.php?action=check&device_id=$deviceId';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('[UPDATE_SERVICE] Error checking notification queue: $e');
      return {
        'success': false,
        'has_notification': false,
        'notification': null
      };
    }
  }

  /// Mark notification as read
  static Future<bool> markNotificationRead(
      String deviceId, int notificationId) async {
    try {
      final apiUrl = await ConfigService.getApiUrl();
      final url = '$apiUrl/notification_queue.php?action=mark_read';

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'device_id': deviceId,
          'notification_id': notificationId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      } else {
        return false;
      }
    } catch (e) {
      print('[UPDATE_SERVICE] Error marking notification as read: $e');
      return false;
    }
  }
}
