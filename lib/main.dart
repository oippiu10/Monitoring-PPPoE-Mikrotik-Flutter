import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/secrets_active_screen.dart';
import 'screens/tambah_screen.dart';
import 'screens/setting_screen.dart';
import 'screens/api_config_screen.dart';
import 'screens/system_resource_screen.dart';
import 'screens/log_screen.dart';
import 'screens/traffic_screen.dart';
import 'screens/ppp_profile_page.dart';
import 'screens/all_users_screen.dart';
import 'screens/export_ppp_screen.dart';
import 'screens/odp_screen.dart';
import 'screens/billing_screen.dart';
import 'screens/genieacs_screen.dart';
import 'screens/database_sync_screen.dart';
import 'screens/system_logs_screen.dart';
import 'screens/initial_config_screen.dart';
import 'screens/customer_map_screen.dart';
// import 'screens/changelog_screen.dart'; // Remove this import
import 'providers/mikrotik_provider.dart';
import 'providers/router_session_provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/scheduled_backup_service.dart';
import 'services/notification_service.dart';

// Reusable widget to eliminate code duplication
class MikrotikScreenWrapper extends StatelessWidget {
  final Widget child;

  const MikrotikScreenWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<RouterSessionProvider>(
      builder: (context, session, _) {
        // Prevent crash during logout: Check if session is active
        if (!session.isSessionActive) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return FutureBuilder<MikrotikProvider>(
          future: session.getMikrotikProvider(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text('Connection Error: ${snapshot.error}'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          // Trigger rebuild
                          (context as Element).markNeedsBuild();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Scaffold(
                body: Center(
                  child: Text('No data available'),
                ),
              );
            }
            // Use the shared provider instance
            return ChangeNotifierProvider.value(
              value: snapshot.data!,
              child: child,
            );
          },
        );
      },
    );
  }
}

// Add ThemeProvider
class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('darkMode') ?? false;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', _isDarkMode);
    notifyListeners();
  }
}

void main() async {
  // 1. Pastikan binding selesai
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Jalankan aplikasi UTAMA dulu (Agar tidak Force Close saat startup)
  runApp(const MyApp());

  // 3. Jalankan servis background DENGAN JEDA (Delayed)
  // Ini agar aplikasi sudah muncul di layar sebelum plugin berat/error dipanggil
  Future.delayed(const Duration(milliseconds: 1500), () async {
    print('[MAIN] Initializing background services after delay...');
    
    // Inisialisasi Tanggal
    try {
      await initializeDateFormatting('id_ID', null);
    } catch (e) {
      print('[MAIN] Error date formatting: $e');
    }

    // PROTEKSI KHUSUS: Jangan jalankan servis Android di iOS
    if (Platform.isAndroid) {
      try {
        ScheduledBackupService().initializeScheduledBackups();
      } catch (e) {
        print('[MAIN] Error scheduled backups: $e');
      }
    }

    // Cek Notifikasi (Hanya jika NotificationService sudah support iOS)
    try {
      _checkNotificationQueue();
    } catch (e) {
      print('[MAIN] Error notification queue: $e');
    }
  });
}
/// Check notification queue in background
void _checkNotificationQueue() async {
  try {
    print('[MAIN] Checking notification queue...');

    final notificationService = NotificationService();
    await notificationService.initialize();
    await notificationService.checkNotificationQueue();

    print('[MAIN] Notification queue check completed');
  } catch (e) {
    print('[MAIN] Error checking notification queue: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => RouterSessionProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Mikrotik Monitor',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.light,
              ),
              cardColor: Color(0xFFE3F2FD),
              scaffoldBackgroundColor: Color(0xFFE3F2FD),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent,
                iconTheme: IconThemeData(color: Colors.white),
                titleTextStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              textTheme: const TextTheme(
                bodyLarge: TextStyle(color: Colors.black87),
                bodyMedium: TextStyle(color: Colors.black87),
                titleLarge: TextStyle(color: Colors.black87),
                titleMedium: TextStyle(color: Colors.black87),
                titleSmall: TextStyle(color: Colors.black54),
              ),
              dividerTheme: const DividerThemeData(
                color: Colors.black12,
              ),
              listTileTheme: const ListTileThemeData(
                iconColor: Colors.blue,
                textColor: Colors.black87,
                subtitleTextStyle: TextStyle(color: Colors.black54),
              ),
              cardTheme: const CardThemeData(
                color: Color(0xFFE3F2FD),
              ),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.dark,
              ),
              cardColor: Color(0xFF1E1E1E),
              scaffoldBackgroundColor: Colors.black,
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent,
                iconTheme: IconThemeData(color: Colors.white),
                titleTextStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              textTheme: const TextTheme(
                bodyLarge: TextStyle(color: Colors.white),
                bodyMedium: TextStyle(color: Colors.white),
                titleLarge: TextStyle(color: Colors.white),
                titleMedium: TextStyle(color: Colors.white),
                titleSmall: TextStyle(color: Colors.white70),
              ),
              dividerTheme: const DividerThemeData(
                color: Colors.white12,
              ),
              listTileTheme: const ListTileThemeData(
                iconColor: Colors.blue,
                textColor: Colors.white,
                subtitleTextStyle: TextStyle(color: Colors.white70),
              ),
              dialogTheme: const DialogThemeData(
                backgroundColor: Color(0xFF1E1E1E),
                titleTextStyle: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
                contentTextStyle: TextStyle(color: Colors.white),
              ),
              snackBarTheme: const SnackBarThemeData(
                backgroundColor: Colors.blue,
                contentTextStyle: TextStyle(color: Colors.white),
              ),
              inputDecorationTheme: const InputDecorationTheme(
                labelStyle: TextStyle(color: Colors.white70),
                hintStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
              ),
              useMaterial3: true,
            ),
            themeMode:
                themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const LoginScreen(),
            routes: {
              '/dashboard': (context) => const MikrotikScreenWrapper(
                    child: DashboardScreen(),
                  ),
              '/secrets-active': (context) => const MikrotikScreenWrapper(
                    child: SecretsActiveScreen(),
                  ),
              '/tambah': (context) => const MikrotikScreenWrapper(
                    child: TambahScreen(),
                  ),
              '/setting': (context) => const SettingScreen(),
              '/api-config': (context) => const ApiConfigScreen(),
              '/system-resource': (context) => const MikrotikScreenWrapper(
                    child: SystemResourceScreen(),
                  ),
              '/traffic': (context) => const MikrotikScreenWrapper(
                    child: TrafficScreen(),
                  ),
              '/log': (context) => const MikrotikScreenWrapper(
                    child: LogScreen(),
                  ),
              '/ppp-profile': (context) => const MikrotikScreenWrapper(
                    child: PPPProfilePage(),
                  ),
              '/all-users': (context) => const MikrotikScreenWrapper(
                    child: AllUsersScreen(),
                  ),
              '/export-ppp': (context) => const MikrotikScreenWrapper(
                    child: ExportPPPScreen(),
                  ),
              '/odp': (context) => const ODPScreen(),
              '/billing': (context) =>
                  const BillingScreen(), // Ganti userId sesuai kebutuhan
              '/genieacs': (context) => const MikrotikScreenWrapper(
                    child: GenieACSScreen(),
                  ),
              '/database-sync': (context) => const MikrotikScreenWrapper(
                    child: DatabaseSyncScreen(),
                  ),
              '/system-logs': (context) => const MikrotikScreenWrapper(
                    child: SystemLogsScreen(),
                  ),
              '/initial-config': (context) => const InitialConfigScreen(),
              '/customer-map': (context) => const CustomerMapScreen(),
              // '/changelog': (context) => const MikrotikScreenWrapper(
              //       child: ChangelogScreen(),
              //     ), // Remove this route
              // '/backup-management': (context) => const MikrotikScreenWrapper(
              //       child: BackupManagementScreen(),
              //     ), // Remove this route
            },
            onGenerateRoute: (settings) {
              if (settings.name == '/secrets-active') {
                return MaterialPageRoute(
                  builder: (context) => const MikrotikScreenWrapper(
                    child: SecretsActiveScreen(),
                  ),
                  settings: settings,
                );
              }
              return null;
            },
          );
        },
      ),
    );
  }
}
