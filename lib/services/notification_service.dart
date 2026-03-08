import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'update_service.dart';

/// Simple Notification Service for Update Notifications
/// NO background check, NO Workmanager - just manual notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // Notification channel details
  static const String _channelId = 'update_notifications';
  static const String _channelName = 'Update Notifications';
  static const String _channelDescription = 'Notifications for app updates';

  // Preferences keys
  static const String _keyNotificationEnabled = 'notification_enabled';
  static const String _keyDeviceId = 'device_id';

  bool _isInitialized = false;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize local notifications
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create notification channel for Android
      if (Platform.isAndroid) {
        await _createNotificationChannel();
      }

      _isInitialized = true;
      print('[NOTIFICATION] Service initialized (simple mode)');
    } catch (e) {
      print('[NOTIFICATION] Failed to initialize: $e');
    }
  }

  /// Create Android notification channel
  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Request notification permission
  Future<bool> requestPermission() async {
    try {
      if (Platform.isAndroid) {
        final androidImpl =
            _notifications.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        if (androidImpl != null) {
          // For Android 13+ (API 33+)
          final granted = await androidImpl.requestNotificationsPermission();
          print('[NOTIFICATION] Permission granted: $granted');
          return granted ?? false;
        }
        return true; // Older Android versions don't need runtime permission
      } else if (Platform.isIOS) {
        final iosImpl = _notifications.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

        if (iosImpl != null) {
          final granted = await iosImpl.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
          print('[NOTIFICATION] iOS Permission granted: $granted');
          return granted ?? false;
        }
      }
    } catch (e) {
      print('[NOTIFICATION] Error requesting permission: $e');
    }
    return false;
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    print('[NOTIFICATION] Tapped: ${response.payload}');
  }

  /// Show update notification
  Future<void> showUpdateNotification({
    required String version,
    required String buildNumber,
    String? message,
  }) async {
    try {
      // Check if notifications are enabled
      final enabled = await isNotificationEnabled();
      if (!enabled) {
        print('[NOTIFICATION] Notifications disabled, skipping');
        return;
      }

      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'Update Available',
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(''),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        0, // Notification ID
        'Update Tersedia 🚀',
        message ?? 'Mikrotik Monitor v$version tersedia untuk diunduh',
        details,
        payload: 'update_available',
      );

      print('[NOTIFICATION] Update notification shown: v$version');
    } catch (e) {
      print('[NOTIFICATION] Error showing notification: $e');
    }
  }

  /// Get or generate device ID
  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_keyDeviceId);

    if (deviceId == null || deviceId.isEmpty) {
      // Generate new device ID
      deviceId = await _generateDeviceId();
      await prefs.setString(_keyDeviceId, deviceId);
      print('[NOTIFICATION] Generated new device ID: $deviceId');
    }

    return deviceId;
  }

  /// Generate unique device ID
  Future<String> _generateDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    String deviceId = '';

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = 'android_${androidInfo.id}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = 'ios_${iosInfo.identifierForVendor ?? "unknown"}';
      }
    } catch (e) {
      // Fallback: generate random ID
      deviceId =
          'device_${DateTime.now().millisecondsSinceEpoch}_${Platform.operatingSystem}';
    }

    return deviceId;
  }

  /// Get device model
  Future<String> getDeviceModel() async {
    final deviceInfo = DeviceInfoPlugin();

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return '${androidInfo.manufacturer} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.model ?? 'Unknown iOS Device';
      }
    } catch (e) {
      return 'Unknown Device';
    }

    return 'Unknown Device';
  }

  /// Register device to backend (simple version)
  Future<bool> registerDevice() async {
    try {
      final deviceId = await getDeviceId();
      final deviceModel = await getDeviceModel();
      final currentVersion = await UpdateService.getCurrentVersion();
      final currentBuild = await UpdateService.getCurrentBuild();

      final success = await UpdateService.registerDevice(
        deviceId: deviceId,
        deviceModel: deviceModel,
        appVersion: currentVersion,
        buildNumber: currentBuild,
      );

      if (success) {
        print('[NOTIFICATION] Device registered: $deviceId');
      }

      return success;
    } catch (e) {
      print('[NOTIFICATION] Failed to register device: $e');
      return false;
    }
  }

  /// Check if notification is enabled
  Future<bool> isNotificationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotificationEnabled) ?? true; // Default: enabled
  }

  /// Toggle notification setting
  Future<void> setNotificationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotificationEnabled, enabled);

    // Update backend
    try {
      final deviceId = await getDeviceId();
      await UpdateService.toggleNotification(deviceId, enabled);
      print('[NOTIFICATION] Notification setting updated: $enabled');
    } catch (e) {
      print('[NOTIFICATION] Failed to update notification setting: $e');
    }
  }

  /// Check for updates and show notification if available
  /// This is called MANUALLY from Settings screen
  Future<void> checkAndNotify() async {
    try {
      print('[NOTIFICATION] Checking for updates...');

      final updateInfo = await UpdateService.checkForUpdate();

      // Update last check on backend
      final deviceId = await getDeviceId();
      await UpdateService.updateLastCheck(deviceId);

      if (updateInfo.updateAvailable) {
        print('[NOTIFICATION] Update available: ${updateInfo.latestVersion}');
        await showUpdateNotification(
          version: updateInfo.latestVersion,
          buildNumber: updateInfo.latestBuild.toString(),
          message:
              'Versi ${updateInfo.latestVersion} tersedia. Tap untuk update.',
        );
      } else {
        print('[NOTIFICATION] No update available');
      }
    } catch (e) {
      print('[NOTIFICATION] Error checking for updates: $e');
    }
  }

  /// Check notification queue from server
  /// This is called when app starts or periodically
  Future<void> checkNotificationQueue() async {
    try {
      print('[NOTIFICATION] Checking notification queue...');

      final deviceId = await getDeviceId();
      final response = await UpdateService.checkNotificationQueue(deviceId);

      if (response['has_notification'] == true &&
          response['notification'] != null) {
        final notification = response['notification'];
        print(
            '[NOTIFICATION] New notification found: ${notification['title']}');

        // Show local notification
        await showUpdateNotification(
          version: notification['version'] ?? 'Latest',
          buildNumber: notification['build_number']?.toString() ?? '0',
          message: notification['message'] ?? 'Update tersedia',
        );

        // Mark as read
        await UpdateService.markNotificationRead(deviceId, notification['id']);
        print('[NOTIFICATION] Notification marked as read');
      } else {
        print('[NOTIFICATION] No new notifications');
      }
    } catch (e) {
      print('[NOTIFICATION] Error checking notification queue: $e');
    }
  }
}
