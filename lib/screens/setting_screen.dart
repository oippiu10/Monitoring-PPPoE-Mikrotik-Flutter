import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/gradient_container.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../main.dart';

import '../services/api_service.dart';
import '../services/log_service.dart';
import '../services/log_sync_service.dart';
import '../providers/router_session_provider.dart';
import 'message_template_screen.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({Key? key}) : super(key: key);

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  String _currentIp = '';
  String _currentPort = '';
  String _currentUsername = '';
  String _currentUserGroup = '';
  bool _showNotifications = true;
  bool _loadingGroup = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _currentIp = prefs.getString('ip') ?? '';
      _currentPort = prefs.getString('port') ?? '';
      _currentUsername = prefs.getString('username') ?? '';
      _showNotifications = prefs.getBool('showNotifications') ?? true;
    });

    // Load group info after settings are loaded
    if (_currentIp.isNotEmpty &&
        _currentPort.isNotEmpty &&
        _currentUsername.isNotEmpty) {
      if (mounted) {
        _loadUserGroupInfo();
      }
    }
  }

  Future<void> _loadUserGroupInfo() async {
    // Only try to load group info if we have connection details
    if (_currentIp.isEmpty ||
        _currentPort.isEmpty ||
        _currentUsername.isEmpty) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _loadingGroup = true;
      _currentUserGroup = ''; // Reset group info while loading
    });

    try {
      // Use the new API integration
      final group = await ApiService.checkUserGroup(
        ip: _currentIp,
        port: _currentPort,
        username: _currentUsername,
        // Note: Password might need to be retrieved from secure storage in a real app,
        // but for now we assume it's available or handled by the session/provider if stored there.
        // However, looking at _loadCurrentSettings, password isn't loaded into state.
        // We need to get it from SharedPreferences or Provider.
        password: await _getPassword(),
      );

      if (!mounted) return;
      setState(() {
        _currentUserGroup = group;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _currentUserGroup = '---';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingGroup = false;
        });
      }
    }
  }

  Future<String> _getPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('password') ?? '';
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showNotifications', _showNotifications);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pengaturan berhasil disimpan'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Setting',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadUserGroupInfo,
              tooltip: 'Refresh Group Info',
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Connection Info Section
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connection Info',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Informasi koneksi saat ini ke perangkat Mikrotik',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Left-right layout for connection info
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left column: IP and Port
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInfoRow(
                                    Icons.router,
                                    'IP Address',
                                    _currentIp.isEmpty
                                        ? 'Not configured'
                                        : _currentIp,
                                    isDark),
                                const SizedBox(height: 12),
                                _buildInfoRow(
                                    Icons.person,
                                    'Username',
                                    _currentUsername.isEmpty
                                        ? 'Not configured'
                                        : _currentUsername,
                                    isDark),
                              ],
                            ),
                          ),
                          const SizedBox(
                              width: 16), // Add some space between columns
                          // Right column: Username and Group
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInfoRow(
                                    Icons.settings_ethernet,
                                    'Port',
                                    _currentPort.isEmpty
                                        ? 'Not configured'
                                        : _currentPort,
                                    isDark),
                                const SizedBox(height: 12),
                                _buildInfoRow(
                                    Icons.group,
                                    'Group',
                                    _loadingGroup
                                        ? 'Loading...'
                                        : (_currentUserGroup.isEmpty
                                            ? 'Not loaded'
                                            : _currentUserGroup),
                                    isDark),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // API Configuration Section
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'API Configuration',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Kelola konfigurasi Base URL API untuk koneksi ke server',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, '/api-config');
                          },
                          icon: const Icon(Icons.settings),
                          label: const Text('Buka Konfigurasi API'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isDark ? Colors.blue[700] : Colors.blue[800],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // App Settings Section
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'App Settings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: Text(
                          'Dark Mode',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          'Mengaktifkan tema gelap',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        value: isDark,
                        onChanged: (bool value) {
                          themeProvider.toggleTheme();
                        },
                      ),
                      SwitchListTile(
                        title: Text(
                          'Notifikasi',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          'Tampilkan notifikasi perubahan status',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        value: _showNotifications,
                        onChanged: (bool value) async {
                          final logSyncService = LogSyncService(context);

                          if (value) {
                            // ENABLE
                            bool hasPermission =
                                await logSyncService.checkPermission();

                            if (!hasPermission) {
                              hasPermission =
                                  await logSyncService.requestPermission();
                              if (!hasPermission) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Izin notifikasi diperlukan.'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                                return;
                              }
                            }

                            setState(() {
                              _showNotifications = true;
                            });
                            await _saveSettings();

                            // Notifikasi Konfirmasi Aktif
                            await logSyncService.testNotification(
                                title: "Status Notifikasi",
                                body: "Notifikasi berhasil diaktifkan.");
                          } else {
                            // DISABLE
                            // Kirim notifikasi dulu SEBELUM dimatikan (karena setelah false, service akan memblokir)
                            // Tapi tunggu, service mengecek SharedPreferences.
                            // Jadi urutannya: Kirim Notif -> Update State -> Save Prefs.

                            await logSyncService.testNotification(
                                title: "Status Notifikasi",
                                body:
                                    "Notifikasi dinonaktifkan. Anda tidak akan menerima update notifikasi lagi.");

                            setState(() {
                              _showNotifications = false;
                            });
                            await _saveSettings();
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildActionButton(
                        icon: Icons.message,
                        label: 'Template Pesan WhatsApp',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const MessageTemplateScreen()),
                          );
                        },
                        color: isDark ? Colors.blueGrey[700] : Colors.blueGrey,
                      ),
                      const SizedBox(height: 12),
                      _buildActionButton(
                        icon: Icons.history,
                        label: 'System Logs (Audit Trail)',
                        onPressed: () {
                          Navigator.pushNamed(context, '/system-logs');
                        },
                        color: isDark ? Colors.blueGrey[700] : Colors.blueGrey,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Maintenance Section
              // Maintenance Section
              /*
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Maintenance',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Hapus data router lama yang tidak terpakai',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildActionButton(
                        icon: Icons.delete_forever,
                        label: 'Hapus Data Router',
                        onPressed: () => _showDeleteDataDialog(context),
                        color: Colors.orange[800],
                      ),
                      const SizedBox(height: 12),
                      _buildActionButton(
                        icon: Icons.perm_identity,
                        label: 'Cek & Perbaiki Router ID',
                        onPressed: () => _checkAndFixRouterId(context),
                        color: Colors.blueGrey,
                      ),
                    ],
                  ),
                ),
              ),
              */
              const SizedBox(height: 16),

              // App Update Section
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.system_update,
                            color: Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'App Update',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Cek ketersediaan update aplikasi terbaru',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildUpdateCheckButton(isDark),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Logout Button

              _buildActionButton(
                icon: Icons.backup,
                label: 'Database Setting',
                onPressed: () {
                  Navigator.pushNamed(context, '/export-ppp');
                },
              ),
              const SizedBox(height: 12),
              _buildActionButton(
                icon: Icons.logout,
                label: 'Logout',
                onPressed: () => _showLogoutConfirmation(context),
                color: Colors.red,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, bool isDark) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isDark ? Colors.blue[200] : Colors.blue[800],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
  }) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon),
        label: Text(label),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              color ?? (isDark ? Colors.blue[700] : Colors.blue[800]),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }


  /*
  Future<void> _showDeleteDataDialog(BuildContext context) async {
    final isDark =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final routerIdController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          'Hapus Data Router',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Masukkan ID Router yang ingin dihapus datanya. PERINGATAN: Data tidak dapat dikembalikan.',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: routerIdController,
              decoration: InputDecoration(
                labelText: 'Router ID',
                border: const OutlineInputBorder(),
                hintText: 'Contoh: RB-DIST@...',
                labelStyle:
                    TextStyle(color: isDark ? Colors.white70 : Colors.grey),
                hintStyle: TextStyle(
                    color: isDark ? Colors.white30 : Colors.grey[300]),
              ),
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (routerIdController.text.isEmpty) return;
              Navigator.pop(context);
              _performDeleteData(routerIdController.text);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  */

  /*
  Future<void> _performDeleteData(String routerId) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await ApiService.deleteRouterData(routerId);
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Data berhasil dihapus'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Gagal menghapus data: $e'),
            backgroundColor: Colors.red),
      );
    }
  }
  */

  /*
  Future<void> _checkAndFixRouterId(BuildContext context) async {
    final session = Provider.of<RouterSessionProvider>(context, listen: false);
    final currentId = session.routerId;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final service = await session.getService();
      // Force fetch ID from router
      final realId = await service.getRouterSerialOrId();

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      final isMatch = currentId == realId;
      final isDark =
          Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          title: Text('Status Router ID',
              style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ID di Aplikasi:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black54)),
              Text(currentId ?? 'Kosong',
                  style:
                      TextStyle(color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 12),
              Text('ID dari Router (Live):',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black54)),
              Text(realId,
                  style:
                      TextStyle(color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 20),
              if (isMatch)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Expanded(
                          child: Text('ID Sinkron. Tidak ada masalah.',
                              style: TextStyle(color: Colors.green))),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                          child: Text('ID Berbeda! Sebaiknya diperbarui.',
                              style: TextStyle(color: Colors.orange))),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
            if (!isMatch)
              ElevatedButton(
                onPressed: () {
                  // Update session
                  session.saveSession(
                    routerId: realId,
                    ip: session.ip!,
                    port: session.port!,
                    username: session.username!,
                    password: session.password!,
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Router ID berhasil diperbarui! Silakan refresh halaman user.'),
                        backgroundColor: Colors.green),
                  );
                },
                child: const Text('Perbaiki ID'),
              ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Gagal mengecek ID: $e'),
            backgroundColor: Colors.red),
      );
    }
  }
  */

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    final isDark =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          'Konfirmasi Logout',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          'Apakah Anda yakin ingin keluar?',
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Batal',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Logout',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      // Capture session early
      final session =
          Provider.of<RouterSessionProvider>(context, listen: false);

      // Log logout activity
      try {
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

      // Clear session immediately after logging (or even if logging fails)
      // We use the captured session variable to ensure we don't rely on context if unmounted
      session.clearSession();

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  Widget _buildUpdateCheckButton(bool isDark) {
    return InkWell(
      onTap: _checkForUpdates,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? Colors.white24 : Colors.black12,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.system_update,
              size: 20,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            const SizedBox(width: 12),
            Text(
              'Check for Updates',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkForUpdates() async {
    try {
      // Show loading dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Check for updates
      final updateInfo = await UpdateService.checkForUpdate();

      // Close loading dialog
      if (!mounted) return;
      Navigator.of(context).pop();

      // Show update dialog if available
      if (updateInfo.updateAvailable && mounted) {
        await showDialog(
          context: context,
          builder: (context) => UpdateDialog(
            updateInfo: updateInfo,
            isRequired: updateInfo.updateRequired,
          ),
        );
      } else if (mounted) {
        // Already up to date
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aplikasi sudah menggunakan versi terbaru!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (!mounted) return;
      Navigator.of(context).pop();

      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memeriksa update: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
