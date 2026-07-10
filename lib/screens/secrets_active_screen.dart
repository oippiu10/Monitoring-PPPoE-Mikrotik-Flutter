import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../providers/mikrotik_provider.dart';
import '../services/mikrotik_service.dart';
import '../widgets/gradient_container.dart';
import '../screens/edit_screen.dart';
import 'package:flutter/widgets.dart';
import '../providers/router_session_provider.dart';
import '../services/api_service.dart';

class SecretsActiveScreen extends StatefulWidget {
  const SecretsActiveScreen({Key? key}) : super(key: key);

  @override
  State<SecretsActiveScreen> createState() => _SecretsActiveScreenState();
}

class _SecretsActiveScreenState extends State<SecretsActiveScreen> {
  String? _lastDataHash;
  DateTime? _fetchTime;
  Timer? _timer;

  String _searchQuery = '';
  String _sortOption = 'Uptime (Shortest)';
  String _statusFilter = 'Semua';
  bool _processedDashboardArgs = false; // Add this flag
  final List<String> _sortOptions = [
    'Name (A-Z)',
    'Name (Z-A)',
    'Uptime (Longest)',
    'Uptime (Shortest)',
    'Last Logout (Newest)',
    'Last Logout (Oldest)',
    'IP Address (A-Z)',
    'IP Address (Z-A)',
  ];
  final List<String> _statusOptions = ['Semua', 'Online', 'Offline'];
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _interfaces = [];
  bool _loadingInterface = false;

  int _itemsPerPage = 50;
  int _currentMax = 50;
  late ScrollController _scrollController;

  Future<void> _fetchInterfaces(MikrotikService service) async {
    setState(() => _loadingInterface = true);
    try {
      final data = await service.getInterface();
      if (mounted) setState(() => _interfaces = data);
    } catch (e) {
      // ignore error, just show 0B
    } finally {
      if (mounted) setState(() => _loadingInterface = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      final provider = Provider.of<MikrotikProvider>(context, listen: false);
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        setState(() {
          if (_currentMax < provider.pppSecrets.length) {
            _currentMax += _itemsPerPage;
          }
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check for route arguments only once
    if (!_processedDashboardArgs) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        setState(() {
          _statusFilter = args['statusFilter'] ?? 'Semua';
          _sortOption = args['sortOption'] ?? 'Uptime (Shortest)';
          _processedDashboardArgs = true; // Mark as processed
        });
      } else {
        _processedDashboardArgs = true; // No args, mark as processed
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _showFilterDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text('Filter',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: isDark ? Colors.white : Colors.black87,
                  )),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              dropdownColor: isDark ? const Color(0xFF2D2D2D) : Colors.white,
              value: _sortOption,
              items: _sortOptions
                  .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(
                        e,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      )))
                  .toList(),
              onChanged: (v) => setState(() => _sortOption = v!),
              decoration: InputDecoration(
                labelText: 'Shortlist',
                labelStyle: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.blue.shade300 : Colors.blue,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              dropdownColor: isDark ? const Color(0xFF2D2D2D) : Colors.white,
              value: _statusFilter,
              items: _statusOptions
                  .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(
                        e,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      )))
                  .toList(),
              onChanged: (v) => setState(() => _statusFilter = v!),
              decoration: InputDecoration(
                labelText: 'Status Koneksi',
                labelStyle: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.blue.shade300 : Colors.blue,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showUserDetail(BuildContext parentContext, Map<String, dynamic> user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOnline = user['isOnline'] == true;
    final profile = user['profile-info'] ?? {};
    // Create a timer to update the UI
    Timer? timer;

    showModalBottomSheet(
      context: parentContext,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        // Start the timer when the bottom sheet is shown
        timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (bottomSheetContext.mounted) {
            // Force rebuild of the bottom sheet
            (bottomSheetContext as Element).markNeedsBuild();
          }
        });

        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) => Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Sticky Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isOnline
                              ? Colors.blue.shade50
                              : Colors.red.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person,
                          color: isOnline
                              ? Colors.blue.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user['name'] ?? '-',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              user['profile'] ?? '-',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isOnline
                              ? (isDark
                                  ? Colors.green.shade900
                                  : Colors.green.shade50)
                              : (isDark
                                  ? Colors.red.shade900
                                  : Colors.red.shade50),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isOnline ? Colors.green : Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isOnline ? 'Online' : 'Offline',
                              style: TextStyle(
                                fontSize: 12,
                                color: isOnline
                                    ? (isDark
                                        ? Colors.green.shade300
                                        : Colors.green)
                                    : (isDark
                                        ? Colors.red.shade300
                                        : Colors.red),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    children: [
                      // User header moved up

                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color:
                                isDark ? Colors.grey[700]! : Colors.grey[300]!,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color:
                              isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E1E1E)
                                    : Colors.white,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info,
                                    color: isOnline
                                        ? Colors.blue[700]
                                        : Colors.red[700],
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'User Info',
                                    style: TextStyle(
                                      color: isOnline
                                          ? Colors.blue[700]
                                          : Colors.red[700],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildDivider(),
                            _buildDetailItem(
                              Icons.person_outline,
                              'Name',
                              user['name'] ?? '-',
                              canCopy: true,
                              iconColor: isOnline
                                  ? (isDark
                                      ? Colors.blue.shade300
                                      : Colors.blue.shade700)
                                  : (isDark
                                      ? Colors.red.shade300
                                      : Colors.red.shade700),
                            ),
                            _buildDivider(),
                            _buildDetailItem(
                              Icons.lock_outline,
                              'Password',
                              user['password'] ?? '-',
                              isPassword: true,
                              iconColor: isOnline
                                  ? (isDark
                                      ? Colors.blue.shade300
                                      : Colors.blue.shade700)
                                  : (isDark
                                      ? Colors.red.shade300
                                      : Colors.red.shade700),
                            ),
                            _buildDetailItem(
                              Icons.settings_outlined,
                              'Service',
                              user['service'] ?? '-',
                              iconColor: isOnline
                                  ? (isDark
                                      ? Colors.blue.shade300
                                      : Colors.blue.shade700)
                                  : (isDark
                                      ? Colors.red.shade300
                                      : Colors.red.shade700),
                            ),
                            _buildDivider(),
                            _buildDetailItem(
                              Icons.wifi_outlined,
                              'IP',
                              user['address'] ?? '-',
                              canCopy: true,
                              iconColor: isOnline
                                  ? (isDark
                                      ? Colors.blue.shade300
                                      : Colors.blue.shade700)
                                  : (isDark
                                      ? Colors.red.shade300
                                      : Colors.red.shade700),
                            ),
                            _buildDivider(),
                            StatefulBuilder(builder: (context, setState) {
                              return _buildDetailItem(
                                Icons.timer_outlined,
                                'Uptime',
                                _getRealtimeUptime(user['uptime']),
                                iconColor: isOnline
                                    ? (isDark
                                        ? Colors.blue.shade300
                                        : Colors.blue.shade700)
                                    : (isDark
                                        ? Colors.red.shade300
                                        : Colors.red.shade700),
                              );
                            }),
                            if (user['caller-id'] != null &&
                                user['caller-id'].toString().isNotEmpty) ...[
                              _buildDivider(),
                              _buildDetailItem(
                                Icons.perm_device_info,
                                'MAC Address',
                                user['caller-id'] ?? '-',
                                canCopy: true,
                                iconColor: isOnline
                                    ? (isDark
                                        ? Colors.blue.shade300
                                        : Colors.blue.shade700)
                                    : (isDark
                                        ? Colors.red.shade300
                                        : Colors.red.shade700),
                              ),
                            ],
                            _buildDivider(),
                            _buildDetailItem(
                              Icons.logout_outlined,
                              'Last logout',
                              formatLastLogout(user['last-logged-out'] ??
                                  user['last_logout']),
                              iconColor: isOnline
                                  ? (isDark
                                      ? Colors.blue.shade300
                                      : Colors.blue.shade700)
                                  : (isDark
                                      ? Colors.red.shade300
                                      : Colors.red.shade700),
                            ),
                            _buildDivider(),
                            _buildDetailItem(
                              Icons.link_off_outlined,
                              'Last disconnect',
                              user['last-disconnect-reason'] ?? '-',
                              iconColor: isOnline
                                  ? (isDark
                                      ? Colors.blue.shade300
                                      : Colors.blue.shade700)
                                  : (isDark
                                      ? Colors.red.shade300
                                      : Colors.red.shade700),
                            ),
                            _buildDivider(),
                            _buildDetailItem(
                              Icons.block_outlined,
                              'Disabled',
                              user['disabled'] ?? 'false',
                              iconColor: isOnline
                                  ? (isDark
                                      ? Colors.blue.shade300
                                      : Colors.blue.shade700)
                                  : (isDark
                                      ? Colors.red.shade300
                                      : Colors.red.shade700),
                            ),
                            _buildDivider(),
                            _buildDetailItem(
                              Icons.route_outlined,
                              'Routes',
                              user['routes'] ?? '-',
                              iconColor: isOnline
                                  ? (isDark
                                      ? Colors.blue.shade300
                                      : Colors.blue.shade700)
                                  : (isDark
                                      ? Colors.red.shade300
                                      : Colors.red.shade700),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color:
                                isDark ? Colors.grey[700]! : Colors.grey[300]!,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color:
                              isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E1E1E)
                                    : Colors.white,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.orange[700],
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'PPP Profile',
                                    style: TextStyle(
                                      color: Colors.orange[700],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildDetailItem(
                              Icons.speed,
                              'Rate Limit',
                              profile['rate-limit'] ?? '-',
                              iconColor: isDark
                                  ? Colors.orange.shade300
                                  : Colors.orange[700],
                            ),
                            _buildDivider(),
                            _buildDetailItem(
                              Icons.dns,
                              'DNS Server',
                              profile['dns-server'] ?? '-',
                              iconColor: isDark
                                  ? Colors.orange.shade300
                                  : Colors.orange[700],
                            ),
                            _buildDivider(),
                            _buildDetailItem(
                              Icons.router,
                              'Local Address',
                              profile['local-address'] ?? '-',
                              iconColor: isDark
                                  ? Colors.orange.shade300
                                  : Colors.orange[700],
                            ),
                            _buildDivider(),
                            _buildDetailItem(
                              Icons.public,
                              'Remote Address',
                              profile['remote-address'] ?? '-',
                              iconColor: isDark
                                  ? Colors.orange.shade300
                                  : Colors.orange[700],
                            ),
                            if (profile['parent-queue'] != null) ...[
                              _buildDivider(),
                              _buildDetailItem(
                                Icons.account_tree,
                                'Parent Queue',
                                profile['parent-queue'],
                                iconColor: isDark
                                    ? Colors.orange.shade300
                                    : Colors.orange[700],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(bottomSheetContext);
                          Navigator.pushNamed(
                            parentContext,
                            '/all-users',
                            arguments: {'initialSearch': user['name']},
                          );
                        },
                        icon: Icon(
                          Icons.search,
                          color: isDark ? Colors.white : Colors.white,
                        ),
                        label: Text(
                          'Cari di Database',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isDark ? Colors.green.shade700 : Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(bottomSheetContext);
                          Navigator.pushNamed(
                            parentContext,
                            '/traffic',
                            arguments: {'initialInterface': user['name']},
                          );
                        },
                        icon: Icon(
                          Icons.network_check,
                          color: isDark ? Colors.white : Colors.white,
                        ),
                        label: Text(
                          'Cek Trafik',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isDark ? Colors.orange.shade800 : Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(bottomSheetContext);
                                final provider = Provider.of<MikrotikProvider>(
                                    parentContext,
                                    listen: false);
                                Navigator.push(
                                  parentContext,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ChangeNotifierProvider.value(
                                      value: provider,
                                      child: EditScreen(user: user),
                                    ),
                                  ),
                                );
                              },
                              icon: Icon(
                                Icons.edit,
                                color: isDark ? Colors.white : Colors.white,
                              ),
                              label: Text(
                                'Edit',
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    isDark ? Colors.blue.shade700 : Colors.blue,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(bottomSheetContext);
                                _showDeleteConfirmation(parentContext, user);
                              },
                              icon: Icon(
                                Icons.delete,
                                color: isDark ? Colors.white : Colors.white,
                              ),
                              label: Text(
                                'Delete',
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    isDark ? Colors.red.shade700 : Colors.red,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      // Cancel the timer when the bottom sheet is closed
      timer?.cancel();
    });
  }

  Widget _buildDetailItem(IconData icon, String label, String value,
      {bool isPassword = false, bool canCopy = false, Color? iconColor}) {
    final ValueNotifier<bool> passwordVisible = ValueNotifier<bool>(false);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final themeColor = isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700;
    final statusColor = iconColor ?? themeColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 24,
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: statusColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 1),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: isPassword
                          ? ValueListenableBuilder<bool>(
                              valueListenable: passwordVisible,
                              builder: (context, isVisible, _) {
                                return Text(
                                  isVisible ? value : '••••••••',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                );
                              },
                            )
                          : Text(
                              value,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color:
                                    isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                    ),
                    if (isPassword)
                      GestureDetector(
                        onTap: () =>
                            passwordVisible.value = !passwordVisible.value,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            passwordVisible.value
                                ? Icons.visibility_off
                                : Icons.visibility,
                            size: 16,
                            color: statusColor,
                          ),
                        ),
                      )
                    else if (canCopy)
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: value));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '$label copied to clipboard',
                                style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              backgroundColor: isDarkMode
                                  ? Colors.grey[800]
                                  : Colors.grey[200],
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.copy,
                            size: 16,
                            color: statusColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      thickness: 1,
      color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
    );
  }

  void _showDeleteConfirmation(
      BuildContext parentContext, Map<String, dynamic> user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.red.shade900 : Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_rounded,
                color: isDark ? Colors.red.shade300 : Colors.red[700],
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Confirm Delete',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete user "${user['name']}"?',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade400 : Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'CANCEL',
              style: TextStyle(
                color: isDark ? Colors.blue.shade300 : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final provider =
                    Provider.of<MikrotikProvider>(parentContext, listen: false);

                // Check if user is online and disconnect first
                final isOnline = user['isOnline'] == true;
                if (isOnline) {
                  print(
                      '[PPP Delete] User ${user['name']} is online, disconnecting first...');
                  try {
                    // Find the active session ID
                    final sessions = provider.pppSessions;
                    final session = sessions.firstWhere(
                      (s) => s['name'] == user['name'],
                      orElse: () => {},
                    );

                    if (session.isNotEmpty && session['.id'] != null) {
                      await provider.service.disconnectSession(session['.id']);
                      print(
                          '[PPP Delete] User ${user['name']} disconnected successfully');
                      // Wait a bit for the disconnection to complete
                      await Future.delayed(const Duration(milliseconds: 500));
                    }
                  } catch (disconnectError) {
                    print(
                        '[PPP Delete] Failed to disconnect: $disconnectError');
                    // Continue with delete attempt anyway
                  }
                }

                // Delete from MikroTik
                await provider.service.deletePPPSecret(user['.id']);

                // Also delete from database for synchronization
                try {
                  final routerSession = Provider.of<RouterSessionProvider>(
                      parentContext,
                      listen: false);
                  final routerId = routerSession.routerId;

                  if (routerId != null && routerId.isNotEmpty) {
                    await ApiService.deleteUser(
                      routerId: routerId,
                      username: user['name'] as String,
                      adminUsername: routerSession.username,
                    );
                    print(
                        '[PPP Delete] User ${user['name']} deleted from database');
                  }
                } catch (dbError) {
                  // Log database delete error but don't fail the operation
                  print('[PPP Delete] Database delete failed: $dbError');
                }

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  // Show success snackbar
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[800] : Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.green,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'User ${user['name']} berhasil dihapus',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: isDark ? Colors.grey[900] : Colors.green,
                      duration: const Duration(seconds: 3),
                      behavior: SnackBarBehavior.fixed,
                    ),
                  );
                  // Refresh the data
                  provider.refreshData();
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);

                  // Parse error message to provide better feedback
                  String errorMessage = 'Gagal menghapus user ${user['name']}';
                  String errorDetail = e.toString();

                  // Check for common error patterns
                  if (errorDetail.contains('in use') ||
                      errorDetail.contains('active')) {
                    errorMessage = 'User ${user['name']} sedang aktif/online';
                    errorDetail =
                        'Disconnect user terlebih dahulu sebelum menghapus';
                  } else if (errorDetail.contains('not found') ||
                      errorDetail.contains('no such')) {
                    errorMessage = 'User ${user['name']} tidak ditemukan';
                    errorDetail = 'User mungkin sudah dihapus';
                  } else if (errorDetail.contains('timeout') ||
                      errorDetail.contains('connection')) {
                    errorMessage = 'Koneksi ke MikroTik gagal';
                    errorDetail = 'Periksa koneksi internet atau router';
                  }

                  print('[PPP Delete Error] $errorDetail');

                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color:
                                      isDark ? Colors.grey[800] : Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.red,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  errorMessage,
                                  style: TextStyle(
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 36),
                            child: Text(
                              errorDetail,
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: isDark ? Colors.grey[900] : Colors.red,
                      duration: const Duration(seconds: 5),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.red.shade700 : Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Card(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Icon(Icons.search,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Cari username...',
                          hintStyle: TextStyle(
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade500,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 12),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Card(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.filter_list,
                  color: _statusFilter != 'Semua' ||
                          _sortOption != 'Uptime (Shortest)'
                      ? (isDark ? Colors.blue.shade300 : Colors.blue.shade800)
                      : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                ),
                onPressed: _showFilterDialog,
                tooltip: 'Filter',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'PPP',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () async {
                  final provider =
                      Provider.of<MikrotikProvider>(context, listen: false);
                  await provider.refreshData(forceRefresh: true);
                  await _fetchInterfaces(provider.service);
                  setState(() {
                    _currentMax = _itemsPerPage;
                  });
                },
              ),
            ),
          ],
        ),
        body: Consumer<MikrotikProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (provider.error != null) {
              return Center(
                child: Text(
                  'Error: ${provider.error}',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              );
            }

            // Fetch interface jika belum
            if (_interfaces.isEmpty && !_loadingInterface) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _fetchInterfaces(provider.service);
              });
            }

            // Set waktu fetch saat data pppSessions berubah
            final dataHash = provider.pppSessions
                .map((e) => (e['name'] ?? '') + (e['uptime'] ?? ''))
                .join(',');
            if (_lastDataHash != dataHash) {
              _lastDataHash = dataHash;
              _fetchTime = DateTime.now();
            }

            // Gabungkan secrets dan active
            final profiles = provider.pppProfiles;
            final activeMap = {
              for (var s in provider.pppSessions) s['name']: s
            };
            // Konsisten dengan sinkronisasi DB: abaikan secret dengan name kosong
            final users = provider.pppSecrets
                .where(
                    (s) => (s['name']?.toString().trim().isNotEmpty ?? false))
                .map((secret) {
              final session = activeMap[secret['name']];
              final profileInfo = profiles.firstWhere(
                (p) => p['name'] == secret['profile'],
                orElse: () => {},
              );
              return {
                ...secret,
                if (session != null) ...session,
                'isOnline': session != null,
                'profile-info': profileInfo,
              };
            }).toList();

            // Filtering - but don't filter out users when coming from dashboard navigation
            List<Map<String, dynamic>> filtered = users.where((u) {
              final q = _searchQuery.toLowerCase();
              // When from dashboard navigation, show all users (no status filtering)
              // Only apply search filter
              if (_processedDashboardArgs && _statusFilter != 'Semua') {
                // Apply only search filter, not status filter
                return (u['name'] ?? '').toLowerCase().contains(q) ||
                    (u['address'] ?? '').toLowerCase().contains(q) ||
                    (u['profile'] ?? '').toLowerCase().contains(q);
              } else {
                // Normal filtering behavior (apply both search and status filters)
                if (_statusFilter == 'Online' && !u['isOnline']) {
                  return false;
                }
                if (_statusFilter == 'Offline' && u['isOnline']) {
                  return false;
                }
                return (u['name'] ?? '').toLowerCase().contains(q) ||
                    (u['address'] ?? '').toLowerCase().contains(q) ||
                    (u['profile'] ?? '').toLowerCase().contains(q);
              }
            }).toList();

            // Sorting
            switch (_sortOption) {
              case 'Name (A-Z)':
                filtered.sort(
                    (a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
                break;
              case 'Name (Z-A)':
                filtered.sort(
                    (a, b) => (b['name'] ?? '').compareTo(a['name'] ?? ''));
                break;
              case 'Uptime (Longest)':
                filtered.sort((a, b) => _parseFlexibleUptime(b['uptime'])
                    .compareTo(_parseFlexibleUptime(a['uptime'])));
                break;
              case 'Uptime (Shortest)':
                filtered.sort((a, b) => _parseFlexibleUptime(a['uptime'])
                    .compareTo(_parseFlexibleUptime(b['uptime'])));
                break;
              case 'Last Logout (Newest)':
                filtered.sort((a, b) {
                  final aLogout = _parseLogoutDate(
                      a['last-logged-out'] ?? a['last_logout']);
                  final bLogout = _parseLogoutDate(
                      b['last-logged-out'] ?? b['last_logout']);
                  if (aLogout == null && bLogout == null) return 0;
                  if (aLogout == null) return 1;
                  if (bLogout == null) return -1;
                  return bLogout
                      .compareTo(aLogout); // DESCENDING: terbaru di atas
                });
                break;
              case 'Last Logout (Oldest)':
                filtered.sort((a, b) {
                  final aLogout = _parseLogoutDate(
                      a['last-logged-out'] ?? a['last_logout']);
                  final bLogout = _parseLogoutDate(
                      b['last-logged-out'] ?? b['last_logout']);
                  if (aLogout == null && bLogout == null) return 0;
                  if (aLogout == null) return 1;
                  if (bLogout == null) return -1;
                  return aLogout
                      .compareTo(bLogout); // ASCENDING: terlama di atas
                });
                break;
              case 'IP Address (A-Z)':
                filtered.sort((a, b) =>
                    (a['address'] ?? '').compareTo(b['address'] ?? ''));
                break;
              case 'IP Address (Z-A)':
                filtered.sort((a, b) =>
                    (b['address'] ?? '').compareTo(a['address'] ?? ''));
                break;
            }

            // Pisahkan offline dan online, sort offline by last-logged-out DESC
            final offline =
                filtered.where((u) => u['isOnline'] != true).toList();
            final online =
                filtered.where((u) => u['isOnline'] == true).toList();

            // Sort offline users based on sort option
            if (_sortOption == 'Last Logout (Newest)') {
              offline.sort((a, b) {
                final aLogout =
                    _parseLogoutDate(a['last-logged-out'] ?? a['last_logout']);
                final bLogout =
                    _parseLogoutDate(b['last-logged-out'] ?? b['last_logout']);
                if (aLogout == null && bLogout == null) return 0;
                if (aLogout == null) return 1;
                if (bLogout == null) return -1;
                return bLogout
                    .compareTo(aLogout); // DESCENDING: terbaru di atas
              });
            } else if (_sortOption == 'Last Logout (Oldest)') {
              offline.sort((a, b) {
                final aLogout =
                    _parseLogoutDate(a['last-logged-out'] ?? a['last_logout']);
                final bLogout =
                    _parseLogoutDate(b['last-logged-out'] ?? b['last_logout']);
                if (aLogout == null && bLogout == null) return 0;
                if (aLogout == null) return 1;
                if (bLogout == null) return -1;
                return aLogout.compareTo(bLogout); // ASCENDING: terlama di atas
              });
            } else {
              // Default sorting for offline users: A-Z
              offline
                  .sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
            }

            // Sort online users by uptime based on sort option
            if (_sortOption == 'Uptime (Shortest)') {
              online.sort((a, b) => _parseFlexibleUptime(a['uptime'])
                  .compareTo(_parseFlexibleUptime(b['uptime'])));
            } else if (_sortOption == 'Uptime (Longest)') {
              online.sort((a, b) => _parseFlexibleUptime(b['uptime'])
                  .compareTo(_parseFlexibleUptime(a['uptime'])));
            }

            // Create display list based on filter - show priority users first, then others
            // When from initial dashboard navigation, prioritize users but show all
            final displayList =
                (_processedDashboardArgs && _statusFilter != 'Semua')
                    ? (_statusFilter == 'Online'
                        ? [...online, ...offline]
                        : _statusFilter == 'Offline'
                            ? [...offline, ...online]
                            : [...offline, ...online])
                    : (_statusFilter == 'Online'
                        ? [...online]
                        : _statusFilter == 'Offline'
                            ? [...offline]
                            : [...offline, ...online]);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchBar(),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      // Calculate totals
                      final totalUsers = offline.length + online.length;
                      final totalActive = online.length;
                      final totalOffline = offline.length;

                      // For filtered display (when not from initial dashboard navigation)
                      final filteredTotal = (_processedDashboardArgs &&
                              _statusFilter != 'Semua')
                          ? totalUsers
                          : filtered.length;
                      final filteredActive = (_processedDashboardArgs &&
                              _statusFilter != 'Semua')
                          ? totalActive
                          : filtered
                              .where((u) => u['isOnline'] == true)
                              .length;
                      final filteredOffline = filteredTotal - filteredActive;

                      return Column(
                        children: [
                          Expanded(
                            child: RefreshIndicator(
                              onRefresh: () async {
                                final provider =
                                    Provider.of<MikrotikProvider>(context, listen: false);
                                await provider.refreshData(forceRefresh: true);
                                await _fetchInterfaces(provider.service);
                                setState(() {
                                  _currentMax = _itemsPerPage;
                                });
                              },
                              child: ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 8),
                                itemCount: displayList.length > _currentMax
                                    ? _currentMax + 1
                                    : displayList.length,
                                itemBuilder: (context, i) {
                                  if (i == _currentMax &&
                                      displayList.length > _currentMax) {
                                    return const Center(
                                        child: Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 16),
                                      child: CircularProgressIndicator(),
                                    ));
                                  }
                                  final user = displayList[i];
                                  final isOnline = user['isOnline'] == true;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF1E1E1E)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isOnline
                                            ? (isDark
                                                ? Colors.blue.shade700
                                                : Colors.blue.shade200)
                                            : (isDark
                                                ? Colors.red.shade700
                                                : Colors.red.shade200),
                                        width: 1.0,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.04),
                                          blurRadius: 2,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                      dense: true,
                                      leading: Stack(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: isOnline
                                                ? (isDark
                                                    ? Colors.blue.shade900
                                                    : Colors.blue[50])
                                                : (isDark
                                                    ? Colors.red.shade900
                                                    : Colors.red[50]),
                                            radius: 14,
                                            child: Icon(Icons.person,
                                                color: isOnline
                                                    ? (isDark
                                                        ? Colors.blue.shade300
                                                        : Colors.blue[700])
                                                    : (isDark
                                                        ? Colors.red.shade300
                                                        : Colors.red[400]),
                                                size: 16),
                                          ),
                                          Positioned(
                                            bottom: 0,
                                            right: 0,
                                            child: CircleAvatar(
                                              radius: 5,
                                              backgroundColor: isDark
                                                  ? Colors.grey[900]
                                                  : Colors.white,
                                              child: Icon(
                                                isOnline
                                                    ? Icons.circle
                                                    : Icons.cancel,
                                                color: isOnline
                                                    ? Colors.green
                                                    : Colors.red,
                                                size: 7,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      title: Text(
                                        user['name'] ?? '-',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          letterSpacing: 0.1,
                                          color: isOnline
                                              ? (isDark
                                                  ? Colors.blue.shade300
                                                  : Colors.blue[800])
                                              : (isDark
                                                  ? Colors.red.shade300
                                                  : Colors.red[700]),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                      subtitle: isOnline
                                          ? Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(user['profile'] ?? '-',
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color: isDark
                                                            ? Colors
                                                                .blue.shade400
                                                            : Colors.blue[400]),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 1),
                                                const SizedBox(height: 1),
                                                Row(
                                                  children: [
                                                    Icon(Icons.location_on,
                                                        size: 11,
                                                        color: isDark
                                                            ? Colors
                                                                .blue.shade500
                                                            : Colors.blue[300]),
                                                    const SizedBox(width: 2),
                                                    Flexible(
                                                      child: Text(
                                                          user['address'] ??
                                                              '-',
                                                          style: TextStyle(
                                                              fontSize: 11,
                                                              color: isDark
                                                                  ? Colors.blue
                                                                      .shade400
                                                                  : Colors.blue[
                                                                      400]),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          maxLines: 1),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Icon(Icons.access_time,
                                                        size: 11,
                                                        color: isDark
                                                            ? Colors
                                                                .blue.shade500
                                                            : Colors.blue[300]),
                                                    const SizedBox(width: 2),
                                                    Flexible(
                                                      child: Text(
                                                          _getRealtimeUptime(
                                                              user['uptime']),
                                                          style: TextStyle(
                                                              fontSize: 11,
                                                              color: isDark
                                                                  ? Colors.blue
                                                                      .shade400
                                                                  : Colors.blue[
                                                                      400]),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          maxLines: 1),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            )
                                          : Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(user['profile'] ?? '-',
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color: isDark
                                                            ? Colors
                                                                .red.shade400
                                                            : Colors.red[400]),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 1),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 1),
                                                  child: Text(
                                                      'Last logout: ' +
                                                          formatLastLogout(user[
                                                                  'last-logged-out'] ??
                                                              user[
                                                                  'last_logout']),
                                                      style: TextStyle(
                                                          fontSize: 11,
                                                          color: isDark
                                                              ? Colors
                                                                  .red.shade300
                                                              : Colors
                                                                  .red[300]),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      maxLines: 1),
                                                ),
                                              ],
                                            ),
                                      trailing: isOnline
                                          ? (() {
                                              final ifaceName =
                                                  'pppoe-${user['name']}';
                                              final iface =
                                                  _interfaces.firstWhere(
                                                (iface) =>
                                                    ((iface['name'] ?? '')
                                                            .replaceAll(
                                                                RegExp(r'[<>]'),
                                                                '') ==
                                                        ifaceName),
                                                orElse: () =>
                                                    <String, dynamic>{},
                                              );
                                              final rx =
                                                  iface['rx-byte'] ?? '0';
                                              final tx =
                                                  iface['tx-byte'] ?? '0';
                                              return SizedBox(
                                                width: 54,
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  alignment: Alignment.topRight,
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.end,
                                                    children: [
                                                      Text(
                                                        _formatBytes(rx),
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          color: isDark
                                                              ? Colors
                                                                  .blue.shade300
                                                              : Colors.blue,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                        textAlign:
                                                            TextAlign.right,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        maxLines: 1,
                                                      ),
                                                      Text(
                                                        _formatBytes(tx),
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          color: isDark
                                                              ? Colors.green
                                                                  .shade300
                                                              : Colors.green,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                        textAlign:
                                                            TextAlign.right,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        maxLines: 1,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            })()
                                          : null,
                                      onTap: () =>
                                          _showUserDetail(context, user),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          Padding(
                              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.people,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                      size: 18),
                                  const SizedBox(width: 4),
                                  Text('$filteredTotal total',
                                      style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                          fontSize: 14)),
                                  const Text(' | ',
                                      style: TextStyle(fontSize: 14)),
                                  Icon(Icons.check_circle,
                                      color: isDark
                                          ? Colors.green.shade300
                                          : Colors.green,
                                      size: 18),
                                  const SizedBox(width: 4),
                                  Text('$filteredActive active',
                                      style: TextStyle(
                                          color: isDark
                                              ? Colors.green.shade300
                                              : Colors.green,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold)),
                                  const Text(' | ',
                                      style: TextStyle(fontSize: 14)),
                                  Icon(Icons.cancel,
                                      color: isDark
                                          ? Colors.red.shade300
                                          : Colors.red,
                                      size: 18),
                                  const SizedBox(width: 4),
                                  Text('$filteredOffline offline',
                                      style: TextStyle(
                                          color: isDark
                                              ? Colors.red.shade300
                                              : Colors.red,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
      ),
    );
  }

  String _getRealtimeUptime(String? baseUptime) {
    if (baseUptime == null || _fetchTime == null) return '-';

    // Parse base uptime ke detik
    final baseSeconds = _parseUptimeToSeconds(baseUptime);

    // Hitung selisih waktu sejak terakhir fetch
    final diffSeconds = DateTime.now().difference(_fetchTime!).inSeconds;

    // Total uptime dalam detik
    final totalSeconds = baseSeconds + diffSeconds;

    // Format hasil
    return _formatUptime(totalSeconds);
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

    List<String> parts = [];
    if (w > 0) parts.add('${w}w');
    if (d > 0) parts.add('${d}d');
    if (h > 0) parts.add('${h}h');
    if (m > 0) parts.add('${m}m');
    if (s > 0 || parts.isEmpty) parts.add('${s}s');

    return parts.join('');
  }

  String _formatBytes(dynamic bytes) {
    if (bytes == null) return '-';
    int val = 0;
    try {
      val = int.parse(bytes.toString());
    } catch (_) {
      return '-';
    }
    if (val >= 1073741824) {
      return '${(val / 1073741824).toStringAsFixed(2)} GB';
    } else if (val >= 1048576) {
      return '${(val / 1048576).toStringAsFixed(2)} MB';
    } else if (val >= 1024) {
      return '${(val / 1024).toStringAsFixed(2)} KB';
    } else {
      return '$val B';
    }
  }

  Duration _parseFlexibleUptime(String? uptime) {
    if (uptime == null) return Duration.zero;
    return Duration(seconds: _parseUptimeToSeconds(uptime));
  }

  String formatLastLogout(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty || dateStr == 'jan/01/1970 00:00:00')
      return '-';
    const bulanMap = {
      'jan': [1, 'Januari'],
      'feb': [2, 'Februari'],
      'mar': [3, 'Maret'],
      'apr': [4, 'April'],
      'may': [5, 'Mei'],
      'jun': [6, 'Juni'],
      'jul': [7, 'Juli'],
      'aug': [8, 'Agustus'],
      'sep': [9, 'September'],
      'oct': [10, 'Oktober'],
      'nov': [11, 'November'],
      'dec': [12, 'Desember'],
    };
    const hariMap = [
      'Minggu',
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu'
    ];
    try {
      DateTime date;
      String jam = '';
      // Cek format ISO (2025-06-24 16:14:53)
      final isoMatch =
          RegExp(r'^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$')
              .firstMatch(dateStr);
      if (isoMatch != null) {
        date = DateTime(
          int.parse(isoMatch.group(1)!),
          int.parse(isoMatch.group(2)!),
          int.parse(isoMatch.group(3)!),
          int.parse(isoMatch.group(4)!),
          int.parse(isoMatch.group(5)!),
          int.parse(isoMatch.group(6)!),
        );
        jam =
            '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
      } else {
        // Format Mikrotik: jun/24/2025 00:59:54
        final parts = dateStr.split(' ');
        final tgl = parts[0].split('/');
        final bulanInfo = bulanMap[tgl[0].toLowerCase()];
        if (bulanInfo == null) return dateStr;
        date = DateTime(
          int.parse(tgl[2]),
          bulanInfo[0] as int,
          int.parse(tgl[1]),
          int.parse(parts[1].split(':')[0]),
          int.parse(parts[1].split(':')[1]),
          int.parse(parts[1].split(':')[2]),
        );
        jam = parts[1];
      }
      final hari = hariMap[date.weekday % 7];
      final bulanNama = [
        '',
        'Januari',
        'Februari',
        'Maret',
        'April',
        'Mei',
        'Juni',
        'Juli',
        'Agustus',
        'September',
        'Oktober',
        'November',
        'Desember'
      ][date.month];
      return '$hari, ${date.day} $bulanNama ${date.year} $jam';
    } catch (_) {
      return dateStr;
    }
  }

  DateTime? _parseLogoutDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty || dateStr == 'jan/01/1970 00:00:00')
      return null;
    try {
      // ISO format: 2025-06-24 16:14:53
      final isoMatch =
          RegExp(r'^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$')
              .firstMatch(dateStr);
      if (isoMatch != null) {
        return DateTime(
          int.parse(isoMatch.group(1)!),
          int.parse(isoMatch.group(2)!),
          int.parse(isoMatch.group(3)!),
          int.parse(isoMatch.group(4)!),
          int.parse(isoMatch.group(5)!),
          int.parse(isoMatch.group(6)!),
        );
      } else {
        // Mikrotik format: jun/24/2025 00:59:54
        final parts = dateStr.split(' ');
        final tgl = parts[0].split('/');
        const bulanMap = {
          'jan': 1,
          'feb': 2,
          'mar': 3,
          'apr': 4,
          'may': 5,
          'jun': 6,
          'jul': 7,
          'aug': 8,
          'sep': 9,
          'oct': 10,
          'nov': 11,
          'dec': 12,
        };
        final bulan = bulanMap[tgl[0].toLowerCase()];
        if (bulan == null) return null;
        return DateTime(
          int.parse(tgl[2]),
          bulan,
          int.parse(tgl[1]),
          int.parse(parts[1].split(':')[0]),
          int.parse(parts[1].split(':')[1]),
          int.parse(parts[1].split(':')[2]),
        );
      }
    } catch (_) {
      return null;
    }
  }
}
