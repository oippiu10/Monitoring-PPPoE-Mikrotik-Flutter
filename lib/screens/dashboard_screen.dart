import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/mikrotik_provider.dart';
import '../services/mikrotik_service.dart';
import '../services/api_service.dart';
import '../services/log_service.dart';
import '../services/log_sync_service.dart'; // Import Sync Service
import '../providers/router_session_provider.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import '../widgets/gradient_container.dart';
import 'all_users_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _timer;
  Timer? _pppStatusTimer;
  late MikrotikProvider _provider;
  late MikrotikService _service;
  late VoidCallback _providerListener;
  int _uptimeSeconds = 0;
  String _uptimeDisplay = '-';
  String _cpuLoad = '-';
  bool _isStatsVisible = true;
  String _username = '';
  String? _lastResourceHash;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Log Sync Service
  LogSyncService? _logSyncService;

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
    _provider = context.read<MikrotikProvider>();
    _service = _provider.service;
    _providerListener = () {
      final resource = _provider.resource ?? {};
      // Buat hash sederhana dari resource (uptime + cpu-load)
      final resourceHash = (resource['uptime']?.toString() ?? '') +
          (resource['cpu-load']?.toString() ?? '');
      if (_lastResourceHash != resourceHash) {
        _lastResourceHash = resourceHash;
        final uptimeStr = resource['uptime'] ?? '0';
        _uptimeSeconds = _parseUptimeToSeconds(uptimeStr);
        _uptimeDisplay = _formatUptime(_uptimeSeconds);
        _cpuLoad = resource['cpu-load']?.toString() ?? '-';
        setState(() {});
      }
    };
    _provider.addListener(_providerListener);
    // Inisialisasi nilai awal
    _providerListener();

    // Trigger sync ke database di background saat dashboard dibuka
    _triggerBackgroundSync();

    // Start Log Sync Service (10s interval + Local Notification)
    _logSyncService = LogSyncService(context);
    _logSyncService?.startAutoSync();

    // Reduced timer frequency to prevent battery drain and memory leaks
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      setState(() {
        _uptimeSeconds += 1; // Increment by 1 seconds
        _uptimeDisplay = _formatUptime(_uptimeSeconds);
      });
      // Fetch CPU load dari API less frequently
      try {
        final resource = await _service.getResource();
        if (!mounted) return;
        setState(() {
          _cpuLoad = resource['cpu-load']?.toString() ?? '-';
        });
      } catch (_) {}
    });
    // Timer polling PPP status (active/offline) every 3 seconds instead of 1 second
    _pppStatusTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) return;
      await _provider.fetchPPPStatusOnly();
    });
  }

  Future<void> _triggerBackgroundSync() async {
    final routerSession =
        Provider.of<RouterSessionProvider>(context, listen: false);
    final routerId = routerSession.routerId;
    if (routerId != null &&
        routerSession.ip != null &&
        routerSession.port != null &&
        routerSession.username != null &&
        routerSession.password != null) {
      final prefs = await SharedPreferences.getInstance();
      final useNativeApi = prefs.getBool('useNativeApi') ?? false;

      // Tunggu sampai provider selesai loading data
      // Agar tidak double fetch (Dashboard fetch + Sync fetch)
      final provider = Provider.of<MikrotikProvider>(context, listen: false);

      // Jika provider sedang loading, tunggu sebentar
      int retries = 0;
      while (provider.isLoading && retries < 20) {
        await Future.delayed(const Duration(milliseconds: 500));
        retries++;
      }

      // ignore: unawaited_futures
      ApiService.syncUsersFromMikrotik(
        routerId: routerId,
        ip: routerSession.ip!,
        port: routerSession.port!,
        username: routerSession.username!,
        password: routerSession.password!,
        enableLogging: true, // Enable logging hanya di dashboard
        useNativeApi: useNativeApi,
        existingService: routerSession.service,
        preLoadedSecrets:
            provider.pppSecrets.isNotEmpty ? provider.pppSecrets : null,
      );
    }
  }

  Future<void> _loadUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username') ?? '';
    final statsVisible = prefs.getBool('stats_visible') ?? true; // Default true
    if (mounted) {
      setState(() {
        _username = username.isNotEmpty
            ? username[0].toUpperCase() + username.substring(1)
            : 'User';
        _isStatsVisible = statsVisible;
      });
    }
  }

  Future<void> _saveStatsVisibility(bool isVisible) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('stats_visible', isVisible);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pppStatusTimer?.cancel();
    _logSyncService?.stopAutoSync(); // Stop Sync Service
    _provider.removeListener(_providerListener);
    super.dispose();
  }

  int _parseUptimeToSeconds(String uptime) {
    final regex = RegExp(r'((\d+)w)?((\d+)d)?((\d+)h)?((\d+)m)?((\d+)s)?');
    final match = regex.firstMatch(uptime);
    if (match == null) return 0;
    int w = int.tryParse(match.group(2) ?? '') ?? 0;
    int d = int.tryParse(match.group(4) ?? '') ?? 0;
    int h = int.tryParse(match.group(6) ?? '') ?? 0;
    int m = int.tryParse(match.group(8) ?? '') ?? 0;
    int s = int.tryParse(match.group(10) ?? '') ?? 0;
    return w * 604800 + d * 86400 + h * 3600 + m * 60 + s;
  }

  String _formatUptime(int seconds) {
    int w = seconds ~/ 604800;
    int d = (seconds % 604800) ~/ 86400;
    int h = (seconds % 86400) ~/ 3600;
    int m = (seconds % 3600) ~/ 60;
    int s = seconds % 60;
    String result = '';
    if (w > 0) result += '${w}w';
    if (d > 0) result += '${d}d';
    if (h > 0) result += '${h}h';
    if (m > 0) result += '${m}m';
    result += '${s}s';
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          Navigator.of(context).pop(); // Tutup drawer jika terbuka
          return false;
        } else {
          // Tampilkan dialog logout
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              title: const Row(
                children: [
                  Icon(Icons.logout, color: Colors.red, size: 32),
                  SizedBox(width: 10),
                  Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: const Text('Apakah Anda yakin ingin logout?',
                  style: TextStyle(fontSize: 16)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child:
                      const Text('Batal', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Logout',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
          if (confirm == true) {
            if (!mounted) return false;
            // Log logout activity
            try {
              final session =
                  Provider.of<RouterSessionProvider>(context, listen: false);
              final username = session.username;
              final routerId = session.routerId;

              if (username != null && routerId != null) {
                await LogService.logActivity(
                  username: username,
                  action: LogService.ACTION_LOGOUT,
                  routerId: routerId,
                  details: 'Logout berhasil via App',
                );
              }
            } catch (e) {
              debugPrint('Error logging logout: $e');
            }
            // Clear session to stop live monitor
            Provider.of<RouterSessionProvider>(context, listen: false)
                .clearSession();
            Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            return false;
          }
          return false;
        }
      },
      child: PopScope(
        canPop: false, // Prevent back navigation
        child: GradientContainer(
          child: Scaffold(
            key: _scaffoldKey,
            backgroundColor: Colors.transparent,
            extendBody: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              title: const Text(
                'Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  tooltip: 'Refresh',
                  onPressed: () async {
                    final provider = context.read<MikrotikProvider>();
                    await provider.refreshData(forceRefresh: true);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: 'Logout',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                        title: const Row(
                          children: [
                            Icon(Icons.logout, color: Colors.red, size: 32),
                            SizedBox(width: 10),
                            Text('Logout',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        content: const Text('Apakah Anda yakin ingin logout?',
                            style: TextStyle(fontSize: 16)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Batal',
                                style: TextStyle(color: Colors.grey)),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Logout',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      if (!mounted) return;
                      // Log logout activity
                      try {
                        final session = Provider.of<RouterSessionProvider>(
                            context,
                            listen: false);
                        final username = session.username;
                        final routerId = session.routerId;

                        if (username != null && routerId != null) {
                          await LogService.logActivity(
                            username: username,
                            action: LogService.ACTION_LOGOUT,
                            routerId: routerId,
                            details: 'Logout berhasil via App',
                          );
                        }
                      } catch (e) {
                        debugPrint('Error logging logout: $e');
                      }
                      // Clear session to stop live monitor
                      Provider.of<RouterSessionProvider>(context, listen: false)
                          .clearSession();
                      Navigator.pushNamedAndRemoveUntil(
                          context, '/', (route) => false);
                    }
                  },
                ),
              ],
            ),
            drawer: Drawer(
              child: Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            DrawerHeader(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF1976D2),
                                    Color(0xFF42A5F5)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  const Text(
                                    'Mikrotik Monitor',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Halo, $_username!',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                            ListTile(
                              leading: const Icon(Icons.dashboard),
                              title: const Text('Dashboard'),
                              onTap: () {
                                Navigator.of(context).pop();
                                // Stay on dashboard, just close drawer
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.people),
                              title: const Text('Semua User'),
                              onTap: () {
                                Navigator.of(context).pop();
                                Future.delayed(
                                    const Duration(milliseconds: 250), () {
                                  Navigator.of(context, rootNavigator: true)
                                      .pushNamed('/all-users');
                                });
                              },
                            ),
                            ExpansionTile(
                              leading: const Icon(Icons.vpn_key),
                              title: const Text('PPP'),
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.people),
                                  title: const Text('PPP Users'),
                                  contentPadding:
                                      const EdgeInsets.only(left: 72),
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    Future.delayed(
                                        const Duration(milliseconds: 250), () {
                                      Navigator.of(context, rootNavigator: true)
                                          .pushNamed('/secrets-active');
                                    });
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.account_box),
                                  title: const Text('PPP Profile'),
                                  contentPadding:
                                      const EdgeInsets.only(left: 72),
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    Future.delayed(
                                        const Duration(milliseconds: 250), () {
                                      Navigator.of(context, rootNavigator: true)
                                          .pushNamed('/ppp-profile');
                                    });
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.add),
                                  title: const Text('Tambah'),
                                  contentPadding:
                                      const EdgeInsets.only(left: 72),
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    Future.delayed(
                                        const Duration(milliseconds: 250), () {
                                      Navigator.of(context, rootNavigator: true)
                                          .pushNamed('/tambah');
                                    });
                                  },
                                ),
                              ],
                            ),
                            ListTile(
                              leading: const Icon(Icons.monitor_heart),
                              title: const Text('System Resource'),
                              onTap: () {
                                Navigator.of(context).pop();
                                Future.delayed(
                                    const Duration(milliseconds: 250), () {
                                  Navigator.of(context, rootNavigator: true)
                                      .pushNamed('/system-resource');
                                });
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.show_chart),
                              title: const Text('Traffic'),
                              onTap: () {
                                Navigator.of(context).pop();
                                Future.delayed(
                                    const Duration(milliseconds: 250), () {
                                  Navigator.of(context, rootNavigator: true)
                                      .pushNamed('/traffic');
                                });
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.call_split),
                              title: const Text('ODP Management'),
                              onTap: () {
                                Navigator.of(context).pop();
                                Future.delayed(
                                    const Duration(milliseconds: 250), () {
                                  Navigator.of(context, rootNavigator: true)
                                      .pushNamed('/odp');
                                });
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.map),
                              title: const Text('Customer Map'),
                              onTap: () {
                                Navigator.of(context).pop();
                                Future.delayed(
                                    const Duration(milliseconds: 250), () {
                                  Navigator.of(context, rootNavigator: true)
                                      .pushNamed('/customer-map');
                                });
                              },
                            ),
                            ExpansionTile(
                              leading: const Icon(Icons.account_balance_wallet),
                              title: const Text('Keuangan'),
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.receipt_long),
                                  title: const Text('Tagihan Bulanan'),
                                  contentPadding: const EdgeInsets.only(left: 72),
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    Future.delayed(
                                        const Duration(milliseconds: 250), () {
                                      Navigator.of(context, rootNavigator: true)
                                          .pushNamed('/billing');
                                    });
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.money_off),
                                  title: const Text('Pengeluaran'),
                                  contentPadding: const EdgeInsets.only(left: 72),
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    Future.delayed(
                                        const Duration(milliseconds: 250), () {
                                      Navigator.of(context, rootNavigator: true)
                                          .pushNamed('/expense');
                                    });
                                  },
                                ),
                              ],
                            ),
                            ListTile(
                              leading: const Icon(Icons.cloud),
                              title: const Text('GenieACS'),
                              onTap: () {
                                Navigator.of(context).pop();
                                Future.delayed(
                                    const Duration(milliseconds: 250), () {
                                  Navigator.of(context, rootNavigator: true)
                                      .pushNamed('/genieacs');
                                });
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.history),
                              title: const Text('Logs'),
                              onTap: () {
                                Navigator.of(context).pop();
                                Future.delayed(
                                    const Duration(milliseconds: 250), () {
                                  Navigator.of(context, rootNavigator: true)
                                      .pushNamed('/log');
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('Setting'),
                    onTap: () {
                      Navigator.of(context).pop();
                      Future.delayed(const Duration(milliseconds: 250), () {
                        Navigator.of(context, rootNavigator: true)
                            .pushNamed('/setting');
                      });
                    },
                  ),
                ],
              ),
            ),
            body: Consumer<MikrotikProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (provider.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Error: ${provider.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => provider.refreshData(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final resource = provider.resource ?? {};
                final identity = provider.identity ?? '-';
                final boardName = resource['board-name'] ?? '-';
                final version = resource['version'] ?? '-';
                final model = resource['platform'] ?? '-';

                return RefreshIndicator(
                  onRefresh: () async {
                    final provider = context.read<MikrotikProvider>();
                    await provider.refreshData(forceRefresh: true);
                  },
                  child: ListView(
                    padding: const EdgeInsets.only(
                        left: 12, right: 12, top: 8, bottom: 100),
                    children: [
                      // HEADER DENGAN GRADIENT DAN ICON
                      InkWell(
                        onTap: () {
                          Navigator.pushNamed(context, '/system-resource');
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 28, horizontal: 20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(identity,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              Row(children: [
                                const Icon(Icons.developer_board,
                                    color: Colors.white70, size: 18),
                                const SizedBox(width: 6),
                                Text('Board Name : $boardName',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 14)),
                              ]),
                              const SizedBox(height: 2),
                              Row(children: [
                                const Icon(Icons.router,
                                    color: Colors.white70, size: 18),
                                const SizedBox(width: 6),
                                Text('RouterOS : $version',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 14)),
                              ]),
                              const SizedBox(height: 2),
                              Row(children: [
                                const Icon(Icons.memory,
                                    color: Colors.white70, size: 18),
                                const SizedBox(width: 6),
                                Text('Model : $model',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 14)),
                              ]),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.access_time,
                                      color: Colors.white70, size: 18),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Uptime: $_uptimeDisplay',
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 14),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.speed,
                                      color: Colors.white70, size: 18),
                                  const SizedBox(width: 4),
                                  Text(
                                    'CPU: $_cpuLoad%',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _secretBox(context, provider),
                      const SizedBox(height: 16),
                      Padding(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: AspectRatio(
                                    aspectRatio: 1.3,
                                    child: _statGridBox(
                                      context,
                                      Icons.wifi,
                                      'Active',
                                      _isStatsVisible
                                          ? provider.pppSessions.length
                                          : -1,
                                      Colors.blue,
                                      '/secrets-active',
                                      statusFilter: 'Online',
                                      sortOption: 'Uptime (Shortest)',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: AspectRatio(
                                    aspectRatio: 1.3,
                                    child: _statGridBox(
                                      context,
                                      Icons.wifi_off,
                                      'Offline',
                                      _isStatsVisible
                                          ? provider.totalOfflineUsers
                                          : -1,
                                      Colors.red,
                                      '/secrets-active',
                                      statusFilter: 'Offline',
                                      sortOption: 'Last Logout (Newest)',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _billingBox(context),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            bottomNavigationBar: Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 30),
              height: 80,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 40,
                    spreadRadius: 0,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 1.5,
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.8),
                          Colors.white.withOpacity(0.5),
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNavItem(
                          context,
                          icon: Icons.dashboard_rounded,
                          label: 'Home',
                          isSelected: true,
                          onTap: () {},
                        ),
                        _buildNavItem(
                          context,
                          icon: Icons.add_circle_outline_rounded,
                          label: 'Tambah',
                          isSelected: false,
                          onTap: () => Navigator.pushNamed(context, '/tambah'),
                        ),
                        _buildNavItem(
                          context,
                          icon: Icons.vpn_key_rounded,
                          label: 'Profile',
                          isSelected: false,
                          onTap: () =>
                              Navigator.pushNamed(context, '/ppp-profile'),
                        ),
                        _buildNavItem(
                          context,
                          icon: Icons.settings_rounded,
                          label: 'Setting',
                          isSelected: false,
                          onTap: () => Navigator.pushNamed(context, '/setting'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statGridBox(BuildContext context, IconData icon, String label,
      int value, Color color, String route,
      {String? statusFilter, String? sortOption}) {
    return InkWell(
      onTap: () {
        if (route == '/secrets-active') {
          Navigator.pushNamed(
            context,
            route,
            arguments: {
              'statusFilter': statusFilter,
              'sortOption': sortOption,
            },
          );
        } else {
          Navigator.pushNamed(context, route);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: label == 'Active'
                ? [
                    const Color(0xFF42A5F5),
                    const Color(0xFF1976D2),
                  ]
                : label == 'Offline'
                    ? [
                        const Color(0xFFF44336),
                        const Color(0xFFD32F2F),
                      ]
                    : label == 'Secret'
                        ? [
                            const Color(0xFF4CAF50),
                            const Color(0xFF388E3C),
                          ]
                        : [
                            const Color(0xFFFFA726),
                            const Color(0xFFF57C00),
                          ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            if (label != 'Log')
              Text(
                value == -1 ? '***' : value.toString(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              )
            else
              const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _secretBox(BuildContext context, MikrotikProvider provider) {
    return InkWell(
      onTap: () {
        // Navigate ke All Users Screen saat kotak hijau diklik
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AllUsersScreen()),
        );
      },
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.people,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Total Users',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isStatsVisible
                              ? '${provider.pppSecrets.length}'
                              : '***',
                          style: const TextStyle(
                            fontSize: 36,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    final newValue = !_isStatsVisible;
                    setState(() {
                      _isStatsVisible = newValue;
                    });
                    _saveStatsVisibility(newValue);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _isStatsVisible ? Icons.visibility : Icons.visibility_off,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _billingBox(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFA726), Color(0xFFF57C00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/billing'),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.receipt_long,
                color: Colors.white,
                size: 28,
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  'Billing',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_forward,
                color: Colors.white,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context,
      {required IconData icon,
      required String label,
      required bool isSelected,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(20),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF0277BD)
                  : const Color(0xFF455A64),
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? const Color(0xFF0277BD)
                    : const Color(0xFF455A64),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
