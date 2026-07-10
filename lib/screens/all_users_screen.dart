import 'package:flutter/material.dart';
import '../services/api_service.dart' show ApiService;
import '../services/mikrotik_service.dart';
import 'edit_data_tambahan_screen.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../providers/router_session_provider.dart';
import '../providers/mikrotik_provider.dart';
import '../widgets/gradient_container.dart';

class AllUsersScreen extends StatefulWidget {
  const AllUsersScreen({Key? key}) : super(key: key);

  @override
  State<AllUsersScreen> createState() => _AllUsersScreenState();
}

class _AllUsersScreenState extends State<AllUsersScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _pppSecrets = []; // Store PPP secrets locally
  int _totalCount = 0; // Total user dari database (sebelum filter search)
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortOption = 'Username (A-Z)';
  final List<String> _sortOptions = [
    'Username (A-Z)',
    'Username (Z-A)',
    'Profile (A-Z)',
    'Profile (Z-A)',
    'ODP (A-Z)',
    'ODP (Z-A)',
    'Data Belum Lengkap (Campuran)',
    'WA Kosong (Prioritas)',
    'Maps/Koordinat Kosong',
    'ODP Kosong (Prioritas)',
    'Alamat Kosong (Prioritas)',
    'Redaman Kosong (Prioritas)',
  ];

  bool _processedArgs = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_processedArgs) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['initialSearch'] != null) {
        final search = args['initialSearch'] as String;
        setState(() {
          _searchQuery = search;
          _searchController.text = search;
        });
      }
      _processedArgs = true;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Load both users and PPP secrets
  Future<void> _loadData() async {
    await Future.wait([
      _loadUsersFromApi(),
      _loadPPPSecrets(),
    ]);
  }

  // Load PPP secrets from MikroTik
  Future<void> _loadPPPSecrets() async {
    if (!mounted) return;

    try {
      // Access MikrotikProvider via RouterSessionProvider to avoid ProviderNotFoundException
      final session =
          Provider.of<RouterSessionProvider>(context, listen: false);
      // Ensure provider is initialized and get the instance
      final provider = await session.getMikrotikProvider();

      // If provider has data, use it immediately
      if (provider.pppSecrets.isNotEmpty) {
        if (mounted) {
          setState(() {
            _pppSecrets = provider.pppSecrets;
          });
        }
        return;
      }

      // If no data, trigger refresh via provider
      await provider.refreshData();

      if (mounted) {
        setState(() {
          _pppSecrets = provider.pppSecrets;
        });
      }
    } catch (e) {
      print('[AllUsers] Error loading PPP secrets: $e');
      // Don't show error to user, just use empty list
      if (mounted) {
        setState(() {
          _pppSecrets = [];
        });
      }
    }
  }

  // Initialize MikroTik service
  Future<MikrotikService> _initializeMikrotikService() async {
    final routerSession =
        Provider.of<RouterSessionProvider>(context, listen: false);
    return routerSession.getService();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Fungsi baru: load users dari API PHP
  Future<void> _loadUsersFromApi() async {
    if (!mounted) return;
    final routerSession =
        Provider.of<RouterSessionProvider>(context, listen: false);
    final routerId = routerSession.routerId;
    if (routerId == null ||
        routerSession.ip == null ||
        routerSession.port == null ||
        routerSession.username == null ||
        routerSession.password == null) {
      setState(() {
        _isLoading = false;
        _error = 'Belum login atau gagal ambil router!';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Sinkronisasi sekarang dilakukan di background saat dashboard dibuka
      // Tidak perlu sync lagi di sini, langsung ambil data dari database

      final String routerIdValue = routerId;
      final data = await ApiService.getAllUsers(routerId: routerIdValue);
      if (!mounted) return;
      if (data['success'] == true) {
        // Ambil semua user dari database (tidak perlu filter berdasarkan Mikrotik)
        // Karena data sudah disinkronkan dan di-filter berdasarkan router_id di backend
        if (mounted) {
          setState(() {
            _users = List<Map<String, dynamic>>.from(data['users'] ?? []);
            _totalCount = data['count'] as int? ?? _users.length;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = data['error'] ?? 'Gagal memuat data dari API';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Gagal memuat data: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _showSortDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Urutkan Berdasarkan',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87),
            ),
          ),
          Divider(height: 1, color: isDark ? Colors.grey.shade700 : null),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _sortOptions.length,
              itemBuilder: (context, index) {
                final option = _sortOptions[index];
                final isSelected = option == _sortOption;
                return ListTile(
                  title: Text(
                    option,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? (isDark
                              ? Colors.blue.shade300
                              : Theme.of(context).primaryColor)
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check,
                          color: isDark
                              ? Colors.blue.shade300
                              : Theme.of(context).primaryColor)
                      : null,
                  onTap: () {
                    setState(() {
                      _sortOption = option;
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredUsersByPPP(
      List<Map<String, dynamic>> pppSecrets) {
    // Create a Set of usernames that exist in PPP (for fast lookup)
    final pppUsernames = pppSecrets
        .where((s) => (s['name']?.toString().trim().isNotEmpty ?? false))
        .map((s) => s['name'].toString())
        .toSet();

    // Filter database users to only show those that exist in PPP
    List<Map<String, dynamic>> users = _users.where((user) {
      final username = user['username']?.toString() ?? '';
      return username.isNotEmpty && pppUsernames.contains(username);
    }).toList();

    // Debug logging
    print('[AllUsers] Total from DB: ${_users.length}');
    print('[AllUsers] Total in PPP: ${pppUsernames.length}');
    print('[AllUsers] After filtering by PPP: ${users.length}');
    print(
        '[AllUsers] Hidden (not in PPP): ${_users.length - users.length} users');

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      users = users.where((user) {
        final username = user['username'].toString().toLowerCase();
        final profile = user['profile'].toString().toLowerCase();
        final wa = user['wa']?.toString().toLowerCase() ?? '';
        final odpName = user['odp_name']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        return username.contains(query) ||
            profile.contains(query) ||
            wa.contains(query) ||
            odpName.contains(query);
      }).toList();
      print('[AllUsers] After search filter: ${users.length}');
    }

    // Sorting
    users.sort((a, b) {
      switch (_sortOption) {
        case 'Username (A-Z)':
          return a['username'].toString().compareTo(b['username'].toString());
        case 'Username (Z-A)':
          return b['username'].toString().compareTo(a['username'].toString());
        case 'Profile (A-Z)':
          return a['profile'].toString().compareTo(b['profile'].toString());
        case 'Profile (Z-A)':
          return b['profile'].toString().compareTo(a['profile'].toString());
        case 'ODP (A-Z)':
          final aOdp = a['odp_name']?.toString() ?? '';
          final bOdp = b['odp_name']?.toString() ?? '';
          if (aOdp.isEmpty) return 1;
          if (bOdp.isEmpty) return -1;
          return aOdp.compareTo(bOdp);
        case 'ODP (Z-A)':
          final aOdp = a['odp_name']?.toString() ?? '';
          final bOdp = b['odp_name']?.toString() ?? '';
          if (aOdp.isEmpty) return 1;
          if (bOdp.isEmpty) return -1;
          return bOdp.compareTo(aOdp);
        case 'Data Belum Lengkap (Campuran)':
          int completeness(Map<String, dynamic> u) {
            int score = 0;
            final wa = u['wa']?.toString().trim() ?? '';
            if (wa.isEmpty || wa == '-') score++;
            
            final odp = u['odp_name']?.toString().trim() ?? '';
            if (odp.isEmpty || odp == '-') score++;
            
            final maps = u['maps']?.toString().trim() ?? '';
            final lat = u['lat']?.toString().trim() ?? '';
            if ((maps.isEmpty || maps == '-') && (lat.isEmpty || lat == '-')) score++;
            
            return score;
          }
          final scoreA = completeness(a);
          final scoreB = completeness(b);
          if (scoreA != scoreB) {
            return scoreB.compareTo(scoreA);
          }
          return a['username'].toString().compareTo(b['username'].toString());
        case 'WA Kosong (Prioritas)':
          int checkWa(Map<String, dynamic> u) {
            final wa = u['wa']?.toString().trim() ?? '';
            return (wa.isEmpty || wa == '-') ? 1 : 0;
          }
          final scoreAWa = checkWa(a);
          final scoreBWa = checkWa(b);
          if (scoreAWa != scoreBWa) return scoreBWa.compareTo(scoreAWa);
          return a['username'].toString().compareTo(b['username'].toString());
        case 'Maps/Koordinat Kosong':
          int checkMaps(Map<String, dynamic> u) {
            final maps = u['maps']?.toString().trim() ?? '';
            final lat = u['lat']?.toString().trim() ?? '';
            return ((maps.isEmpty || maps == '-') && (lat.isEmpty || lat == '-')) ? 1 : 0;
          }
          final scoreAMaps = checkMaps(a);
          final scoreBMaps = checkMaps(b);
          if (scoreAMaps != scoreBMaps) return scoreBMaps.compareTo(scoreAMaps);
          return a['username'].toString().compareTo(b['username'].toString());
        case 'ODP Kosong (Prioritas)':
          int checkOdp(Map<String, dynamic> u) {
            final odp = u['odp_name']?.toString().trim() ?? '';
            return (odp.isEmpty || odp == '-') ? 1 : 0;
          }
          final scoreAOdp = checkOdp(a);
          final scoreBOdp = checkOdp(b);
          if (scoreAOdp != scoreBOdp) return scoreBOdp.compareTo(scoreAOdp);
          return a['username'].toString().compareTo(b['username'].toString());
        case 'Alamat Kosong (Prioritas)':
          int checkAlamat(Map<String, dynamic> u) {
            final alamat = u['alamat']?.toString().trim() ?? '';
            return (alamat.isEmpty || alamat == '-') ? 1 : 0;
          }
          final scoreAAlamat = checkAlamat(a);
          final scoreBAlamat = checkAlamat(b);
          if (scoreAAlamat != scoreBAlamat) return scoreBAlamat.compareTo(scoreAAlamat);
          return a['username'].toString().compareTo(b['username'].toString());
        case 'Redaman Kosong (Prioritas)':
          int checkRedaman(Map<String, dynamic> u) {
            final redaman = u['redaman']?.toString().trim() ?? '';
            return (redaman.isEmpty || redaman == '-') ? 1 : 0;
          }
          final scoreARedaman = checkRedaman(a);
          final scoreBRedaman = checkRedaman(b);
          if (scoreARedaman != scoreBRedaman) return scoreBRedaman.compareTo(scoreARedaman);
          return a['username'].toString().compareTo(b['username'].toString());
        default:
          return 0;
      }
    });

    print('[AllUsers] Final count: ${users.length}');
    return users;
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus User',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87)),
        content: Text(
          'Yakin ingin menghapus user "${user['username']}"?',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Batal',
              style:
                  TextStyle(color: isDark ? Colors.blue.shade300 : Colors.blue),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        if (!mounted) return;
        // Asumsikan ApiService punya deleteUser
        final routerIdProvider =
            Provider.of<RouterSessionProvider>(context, listen: false);
        final String? routerIdValue = routerIdProvider.routerId;
        if (routerIdValue == null) {
          throw Exception('Silakan login router ulang');
        }
        await ApiService.deleteUser(
            routerId: routerIdValue,
            username: user['username'] as String,
            adminUsername: routerIdProvider.username);
        if (mounted) {
          setState(() {
            _users.removeWhere((u) => u['username'] == user['username']);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('User berhasil dihapus'),
                backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Gagal menghapus user: $e'),
                backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showUserDetailSheet(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) => Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor:
                            isDark ? Colors.blue.shade900 : Colors.blue.shade50,
                        child: Icon(Icons.person,
                            color: isDark
                                ? Colors.blue.shade300
                                : Colors.blue.shade700,
                            size: 38),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user['username'] ?? '-',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isDark ? Colors.white : Colors.black87),
                            ),
                            Text(
                              user['profile'] ?? '-',
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                  fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    children: [
                      if (user['foto'] != null &&
                          user['foto'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Builder(
                            builder: (context) {
                              String fotoUrl = user['foto'];
                              if (!fotoUrl.startsWith('http')) {
                                fotoUrl = '${ApiService.baseUrl}/' + fotoUrl;
                              }
                              return GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    barrierDismissible: true,
                                    builder: (context) => Dialog(
                                      backgroundColor: Colors.transparent,
                                      insetPadding: EdgeInsets.all(10),
                                      child: Stack(
                                        children: [
                                          GestureDetector(
                                            onTap: () =>
                                                Navigator.of(context).pop(),
                                            child: Container(
                                              color:
                                                  Colors.black.withOpacity(0.8),
                                              child: Center(
                                                child: InteractiveViewer(
                                                  child: Image.network(
                                                    fotoUrl,
                                                    fit: BoxFit.contain,
                                                    errorBuilder: (context,
                                                            error,
                                                            stackTrace) =>
                                                        const Icon(
                                                            Icons.broken_image,
                                                            color: Colors.white,
                                                            size: 80),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 10,
                                            right: 10,
                                            child: IconButton(
                                              icon: const Icon(Icons.close,
                                                  color: Colors.white,
                                                  size: 30),
                                              onPressed: () =>
                                                  Navigator.of(context).pop(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.network(
                                    fotoUrl,
                                    height: 180,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        height: 180,
                                        color: Colors.grey[200],
                                        child: const Center(
                                          child: Icon(Icons.broken_image,
                                              size: 48, color: Colors.grey),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 24),
                      Container(
                        decoration: BoxDecoration(
                          color:
                              isDark ? const Color(0xFF2D2D2D) : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                            vertical: 18, horizontal: 16),
                        child: Column(
                          children: [
                            _infoRow(Icons.person_outline, 'Username',
                                user['username'] ?? '-'),
                            _buildDivider(),
                            _infoRow(Icons.lock_outline, 'Password',
                                user['password'] ?? '-',
                                isPassword: true),
                            _buildDivider(),
                            _infoRow(Icons.category, 'Profile',
                                user['profile'] ?? '-'),
                            if (user['odp_name'] != null &&
                                user['odp_name'].toString().isNotEmpty) ...[
                              _buildDivider(),
                              _infoRow(
                                  Icons.call_split, 'ODP', user['odp_name'].toString()),
                            ],
                            if (user['wa']?.toString().isNotEmpty ?? false) ...[
                              _buildDivider(),
                              _infoRow(null, 'WA', user['wa']?.toString() ?? '-',
                                  isWA: true),
                            ],
                            if (user['maps']?.toString().isNotEmpty ?? false) ...[
                              _buildDivider(),
                              _infoRow(null, 'Maps', user['maps']?.toString() ?? '-',
                                  isMaps: true),
                            ],
                            if (user['alamat'] != null &&
                                user['alamat'].toString().isNotEmpty) ...[
                              _buildDivider(),
                              _infoRow(Icons.home_outlined, 'Alamat',
                                  user['alamat']),
                            ],
                            if (user['redaman'] != null &&
                                user['redaman'].toString().isNotEmpty) ...[
                              _buildDivider(),
                              _infoRow(Icons.signal_cellular_alt, 'Redaman',
                                  '${user['redaman']} dBm'),
                            ],
                            if (user['tanggal_tagihan'] != null &&
                                user['tanggal_tagihan']
                                    .toString()
                                    .isNotEmpty) ...[
                              _buildDivider(),
                              _infoRow(
                                Icons.calendar_month_outlined,
                                'Jatuh Tempo',
                                (() {
                                  try {
                                    final date = DateTime.tryParse(
                                        user['tanggal_tagihan']);
                                    return date != null
                                        ? DateFormat('d MMMM yyyy', 'id_ID')
                                            .format(date)
                                        : user['tanggal_tagihan'];
                                  } catch (_) {
                                    return user['tanggal_tagihan'];
                                  }
                                })(),
                              ),
                            ],
                            if (user['lat'] != null &&
                                user['lng'] != null &&
                                user['lat'].toString().isNotEmpty &&
                                user['lng'].toString().isNotEmpty) ...[
                              _buildDivider(),
                              _infoRow(
                                Icons.location_on_outlined,
                                'Koordinat',
                                '${user['lat']}, ${user['lng']}',
                                isCoordinates: true,
                                lat: user['lat'],
                                lng: user['lng'],
                              ),
                            ],
                            if (user['tanggal_dibuat']?.toString().isNotEmpty ??
                                false) ...[
                              _buildDivider(),
                              _infoRow(
                                Icons.calendar_today,
                                'Tanggal dibuat',
                                user['tanggal_dibuat'] != null
                                    ? (() {
                                        try {
                                          return DateFormat(
                                                  'dd MMM yyyy, HH:mm', 'id_ID')
                                              .format(DateTime.tryParse(
                                                      user['tanggal_dibuat']) ??
                                                  DateTime.now());
                                        } catch (_) {
                                          return user['tanggal_dibuat'];
                                        }
                                      })()
                                    : '-',
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.center,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          EditDataTambahanScreen(
                                        username: user['username'],
                                        currentData: {
                                          'wa': user['wa'] ?? '',
                                          'maps': user['maps'] ?? '',
                                          'foto': user['foto'] ?? '',
                                          'odp_id': user['odp_id'],
                                        },
                                      ),
                                    ),
                                  ).then((value) {
                                    if (value == true) _loadUsersFromApi();
                                  });
                                },
                                icon: const Icon(Icons.edit_note),
                                label: const Text('Edit Data Tambahan'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark
                                      ? Colors.blue.shade700
                                      : Colors.blue.shade800,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => _deleteUser(user),
                                icon: const Icon(Icons.delete),
                                label: const Text('Hapus'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Tambahkan fungsi dialog popup di tengah
  Future<void> _showCopyOpenDialog({
    required BuildContext context,
    required String title,
    required String value,
    required String openLabel,
    required VoidCallback onOpen,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Center(
            child: Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                border: Border.all(
                    color:
                        isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
                color: isDark ? const Color(0xFF2D2D2D) : Colors.grey.shade100,
              ),
              child: SelectableText(
                value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87),
                textAlign: TextAlign.center,
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isDark ? Colors.blue.shade700 : Colors.blue.shade800,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.copy),
                    label: const Text('Salin'),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: value));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Disalin ke clipboard!'),
                            backgroundColor: Colors.green),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isDark ? Colors.blue.shade700 : Colors.blue.shade800,
                      foregroundColor: Colors.white,
                    ),
                    icon: title == 'Nomor WhatsApp'
                        ? Image.asset('assets/WhatsApp.svg.png',
                            width: 24, height: 24)
                        : title == 'Link Maps'
                            ? Image.asset(
                                'assets/pngimg.com - google_maps_pin_PNG26.png',
                                width: 24,
                                height: 24)
                            : const Icon(Icons.open_in_new),
                    label: Text(openLabel),
                    onPressed: () {
                      Navigator.pop(context);
                      onOpen();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Tambahkan fungsi _infoRow untuk tampilan modern
  Widget _infoRow(IconData? icon, String label, String value,
      {bool isPassword = false,
      bool isWA = false,
      bool isMaps = false,
      bool isCoordinates = false,
      dynamic lat,
      dynamic lng,
      bool lightBackground = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final useDark = lightBackground ? false : isDark;
    Widget? leadingIcon;
    if (isWA) {
      leadingIcon =
          Image.asset('assets/WhatsApp.svg.png', width: 22, height: 22);
    } else if (isMaps) {
      leadingIcon = Image.asset('assets/pngimg.com - google_maps_pin_PNG26.png',
          width: 22, height: 22);
    } else if (isCoordinates) {
      leadingIcon = Image.asset('assets/pngimg.com - google_maps_pin_PNG26.png',
          width: 22, height: 22);
    } else if (icon != null) {
      leadingIcon = Icon(icon,
          color: useDark ? Colors.blue.shade300 : Colors.blueAccent, size: 22);
    }

    Widget valueWidget;
    if (isPassword) {
      final ValueNotifier<bool> obscure = ValueNotifier<bool>(true);
      valueWidget = ValueListenableBuilder<bool>(
        valueListenable: obscure,
        builder: (context, isObscure, _) => Row(
          children: [
            Expanded(
              child: Text(
                isObscure ? '••••••••' : value,
                style: TextStyle(
                    fontSize: 15,
                    color: useDark ? Colors.white70 : Colors.black54),
                overflow: TextOverflow.visible,
                maxLines: null,
              ),
            ),
            InkWell(
              onTap: () => obscure.value = !isObscure,
              child: Icon(
                isObscure ? Icons.visibility_off : Icons.visibility,
                size: 18,
                color: useDark ? Colors.white70 : Colors.grey,
              ),
            ),
          ],
        ),
      );
    } else {
      valueWidget = Text(
        value,
        style: TextStyle(
          fontSize: 15,
          color: isWA || isMaps
              ? (useDark ? Colors.blue.shade300 : Colors.blue)
              : (useDark ? Colors.white70 : Colors.black87),
          decoration:
              isWA || isMaps ? TextDecoration.underline : TextDecoration.none,
        ),
        overflow: TextOverflow.visible,
        maxLines: null,
      );
    }

    // Kembalikan popup salin & buka untuk WA dan Maps
    if ((isWA && value.isNotEmpty) ||
        (isMaps && value.isNotEmpty) ||
        (isCoordinates && value.isNotEmpty)) {
      valueWidget = InkWell(
        onTap: () async {
          if (isWA) {
            _showCopyOpenDialog(
              context: context,
              title: 'Nomor WhatsApp',
              value: value,
              openLabel: 'Buka',
              onOpen: () async {
                String waNumber = value.replaceAll(RegExp(r'[^0-9]'), '');
                if (waNumber.startsWith('0')) {
                  waNumber = '62' + waNumber.substring(1);
                }
                final uri = Uri.parse('whatsapp://send?phone=$waNumber');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Tidak dapat membuka WhatsApp.')),
                  );
                }
              },
            );
          } else if (isMaps) {
            _showCopyOpenDialog(
              context: context,
              title: 'Link Maps',
              value: value,
              openLabel: 'Buka',
              onOpen: () async {
                String mapsUrl = value;
                if (!value.startsWith('http') && !value.startsWith('geo:')) {
                  mapsUrl =
                      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(value)}';
                }
                final uri = Uri.parse(mapsUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Tidak dapat membuka link: $value')),
                  );
                }
              },
            );
          } else if (isCoordinates) {
            final url =
                'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
            _showCopyOpenDialog(
              context: context,
              title: 'Koordinat Lokasi',
              value: value,
              openLabel: 'Buka Maps',
              onOpen: () async {
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(Uri.parse(url),
                      mode: LaunchMode.externalApplication);
                }
              },
            );
          }
        },
        child: valueWidget,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (leadingIcon != null) ...[
            leadingIcon,
            const SizedBox(width: 10),
          ],
          Text('${label}:',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: useDark ? Colors.white : Colors.black87)),
          const SizedBox(width: 8),
          Expanded(child: valueWidget),
        ],
      ),
    );
  }

  Widget _buildDivider() =>
      const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Semua User',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadUsersFromApi,
            ),
          ],
        ),
        body: Column(
          children: [
            // Search Bar with Filter Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                          color:
                              isDark ? const Color(0xFF2D2D2D) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87),
                          decoration: InputDecoration(
                            hintText: 'Cari user...',
                            hintStyle: TextStyle(
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.black54),
                            prefixIcon: Icon(
                              Icons.search,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.black54,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.clear,
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : Colors.black54,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
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
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                        onPressed: _showSortDialog,
                        tooltip: 'Filter',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // User List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 16),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _loadData,
                                icon: const Icon(Icons.refresh),
                                label: const Text('COBA LAGI'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade800,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          child: Builder(
                            builder: (context) {
                              final filteredUsers =
                                  _getFilteredUsersByPPP(_pppSecrets);
                              return filteredUsers.isEmpty
                                  ? ListView(
                                      physics: const AlwaysScrollableScrollPhysics(),
                                      children: [
                                        SizedBox(
                                          height: MediaQuery.of(context).size.height * 0.5,
                                          child: const Center(
                                            child: Text(
                                              'Tidak ada user yang ditemukan',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : ListView.separated(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 8),
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      itemCount: filteredUsers.length,
                                      separatorBuilder: (context, index) =>
                                          const SizedBox(height: 8),
                                      itemBuilder: (context, index) {
                                        final user = filteredUsers[index];
                                        return GestureDetector(
                                          onTap: () =>
                                              _showUserDetailSheet(user),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 200),
                                            curve: Curves.easeInOut,
                                            child: Card(
                                              elevation: 1,
                                              margin: EdgeInsets.zero,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                side: BorderSide(
                                                    color: isDark
                                                        ? Colors.grey.shade700
                                                        : Colors.grey.shade200,
                                                    width: 1),
                                              ),
                                              color: isDark
                                                  ? const Color(0xFF1E1E1E)
                                                  : Colors.white,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 10),
                                                child: Row(
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 20,
                                                      backgroundColor: isDark
                                                          ? Colors.blue.shade900
                                                          : Colors.blue.shade50,
                                                      child: Icon(Icons.person,
                                                          color: isDark
                                                              ? Colors
                                                                  .blue.shade300
                                                              : Colors.blue
                                                                  .shade700,
                                                          size: 22),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            user['username'].toString(),
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 15,
                                                              color: isDark
                                                                  ? Colors.white
                                                                  : Colors
                                                                      .black87,
                                                            ),
                                                          ),
                                                          Text(
                                                            'Profile: ${user['profile']}',
                                                            style: TextStyle(
                                                                fontSize: 13,
                                                                color: isDark
                                                                    ? Colors
                                                                        .white70
                                                                    : Colors
                                                                        .black54),
                                                          ),
                                                          if (user['odp_name']
                                                                  ?.toString()
                                                                  .isNotEmpty ??
                                                              false)
                                                            Row(
                                                              children: [
                                                                Icon(
                                                                    Icons
                                                                        .call_split,
                                                                    size: 16,
                                                                    color: isDark
                                                                        ? Colors
                                                                            .blue
                                                                            .shade300
                                                                        : Colors
                                                                            .blue
                                                                            .shade800),
                                                                const SizedBox(
                                                                    width: 4),
                                                                Flexible(
                                                                  child: Text(
                                                                    'ODP: ${user['odp_name']}',
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            12,
                                                                        color: isDark
                                                                            ? Colors.white70
                                                                            : Colors.black),
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          if (user['wa']
                                                                  ?.toString()
                                                                  .isNotEmpty ??
                                                              false)
                                                            Row(
                                                              children: [
                                                                Image.asset(
                                                                    'assets/WhatsApp.svg.png',
                                                                    width: 16,
                                                                    height: 16),
                                                                const SizedBox(
                                                                    width: 4),
                                                                Flexible(
                                                                  child: Text(
                                                                    'WA: ${user['wa']}',
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            12,
                                                                        color: isDark
                                                                            ? Colors.white70
                                                                            : Colors.black),
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          if (user['maps']
                                                                  ?.toString()
                                                                  .isNotEmpty ??
                                                              false)
                                                            Row(
                                                              children: [
                                                                Image.asset(
                                                                    'assets/pngimg.com - google_maps_pin_PNG26.png',
                                                                    width: 16,
                                                                    height: 16),
                                                                const SizedBox(
                                                                    width: 4),
                                                                Flexible(
                                                                  child: Text(
                                                                    'Maps: ${user['maps']}',
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            12,
                                                                        color: isDark
                                                                            ? Colors.white70
                                                                            : Colors.black),
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
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
                                            ),
                                          ),
                                        );
                                      },
                                    );
                            },
                          ),
              ),
            ),
            // Footer jumlah user
            Builder(
              builder: (context) {
                final filteredUsers = _getFilteredUsersByPPP(_pppSecrets);
                return Container(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                  child: Text(
                    'Total User: ${filteredUsers.length}${_searchQuery.isNotEmpty ? ' (${filteredUsers.length} ditampilkan)' : ''}',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
