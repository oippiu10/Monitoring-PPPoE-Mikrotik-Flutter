import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:ui';
import '../widgets/gradient_container.dart';
import '../providers/router_session_provider.dart';
import '../providers/mikrotik_provider.dart';
import '../services/mikrotik_service.dart';
import '../services/mikrotik_native_service.dart';
import 'dart:async';
import 'all_users_screen.dart';

class MultiDashboardScreen extends StatefulWidget {
  const MultiDashboardScreen({super.key});

  @override
  State<MultiDashboardScreen> createState() => _MultiDashboardScreenState();
}

class _MultiDashboardScreenState extends State<MultiDashboardScreen> {
  final PageController _pageController = PageController();
  List<Map<String, dynamic>> _monitoredRouters = [];
  List<Map<String, String>> _savedLogins = [];
  int _currentPage = 0;
  bool _isLoading = true;
  bool _useNativeApi = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load monitored routers
    final String? monitoredStr = prefs.getString('monitored_routers');
    if (monitoredStr != null && monitoredStr.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(monitoredStr);
        _monitoredRouters = List<Map<String, dynamic>>.from(decoded);
      } catch (e) {
        _monitoredRouters = [];
      }
    }

    // Jika kosong, masukkan router yang sedang aktif dari session
    if (_monitoredRouters.isEmpty) {
      final session = Provider.of<RouterSessionProvider>(context, listen: false);
      if (session.ip != null) {
        _monitoredRouters.add({
          'address': '${session.ip}:${session.port ?? 8728}',
          'username': session.username,
          'password': session.password,
          'routerId': session.routerId,
        });
        await prefs.setString('monitored_routers', jsonEncode(_monitoredRouters));
      }
    }

    _useNativeApi = prefs.getBool('useNativeApi') ?? false;

    final savedLoginsRaw = prefs.getStringList('mikrotik_logins') ?? [];
    _savedLogins = savedLoginsRaw.map((e) {
      try {
        return Map<String, String>.from(jsonDecode(e));
      } catch (_) {
        return <String, String>{};
      }
    }).where((e) => e.isNotEmpty).toList();

    setState(() {
      _isLoading = false;
    });

    // Update global session ke halaman pertama
    if (_monitoredRouters.isNotEmpty) {
      _updateGlobalSession(0);
    }
  }

  void _updateGlobalSession(int index) {
    if (index < 0 || index >= _monitoredRouters.length) return;
    final router = _monitoredRouters[index];
    final parts = router['address'].toString().split(':');
    final ip = parts[0];
    final port = parts.length > 1 ? int.tryParse(parts[1]) ?? 8728 : 8728;
    
    // Update secara diam-diam tanpa memicu loading screen penuh
    final session = Provider.of<RouterSessionProvider>(context, listen: false);

    // routerId di 'monitored_routers' bisa kosong (router ditambah manual, atau
    // hasil import login lama). Kalau kosong dan router-nya sama persis dengan
    // sesi login yang sedang aktif, pakai routerId hasil login supaya tidak
    // tertimpa string kosong. Router yang berbeda TIDAK boleh mewarisi ID ini —
    // username PPPoE bisa sama antar router, datanya akan tertukar.
    var routerId = (router['routerId'] ?? '').toString();
    final isSameRouter = session.ip == ip && session.port == port.toString();
    if (routerId.isEmpty &&
        isSameRouter &&
        (session.routerId?.isNotEmpty ?? false)) {
      routerId = session.routerId!;
      router['routerId'] = routerId;
      _persistMonitoredRouters();
    }

    session.saveSession(
      ip: ip,
      port: port.toString(),
      username: router['username'],
      password: router['password'],
      routerId: routerId,
    );

    // Masih kosong berarti router ini belum pernah punya Software ID tersimpan
    // (ditambah manual, atau hasil import login lama). Ambil langsung dari
    // perangkatnya — tanpa ini semua halaman yang butuh router_id akan gagal.
    if (routerId.isEmpty) {
      _fetchRouterIdFromDevice(index);
    }
  }

  /// Ambil Software ID langsung dari MikroTik, simpan ke monitored_routers,
  /// lalu perbarui sesi global bila router ini masih yang sedang dipilih.
  Future<void> _fetchRouterIdFromDevice(int index) async {
    if (index < 0 || index >= _monitoredRouters.length) return;
    final router = _monitoredRouters[index];
    final parts = router['address'].toString().split(':');
    final ip = parts[0];
    final port = parts.length > 1 ? int.tryParse(parts[1]) ?? 8728 : 8728;
    final username = router['username']?.toString() ?? '';
    final password = router['password']?.toString() ?? '';

    dynamic service;
    try {
      if (_useNativeApi || port == 8728 || port == 8729) {
        service = MikrotikNativeService(
          ip: ip,
          port: port.toString(),
          username: username,
          password: password,
        );
      } else {
        service = MikrotikService(
          ip: ip,
          port: port.toString(),
          username: username,
          password: password,
        );
      }

      final fetched = await service.getRouterSerialOrId();
      if (fetched.isEmpty) return;

      // Jangan simpan ID cadangan hasil tebakan (RB-identity@ip:port atau
      // ip:port) — itu justru sumber kekacauan router_id selama ini.
      if (fetched.startsWith('RB-') || fetched.contains(':')) {
        debugPrint('[MultiDashboard] ID cadangan diabaikan: $fetched');
        return;
      }

      if (!mounted) return;
      router['routerId'] = fetched;
      await _persistMonitoredRouters();
      debugPrint('[MultiDashboard] Software ID $ip tersimpan: $fetched');

      if (!mounted) return;
      final session = Provider.of<RouterSessionProvider>(context, listen: false);
      if (session.ip == ip && session.port == port.toString()) {
        session.saveSession(
          ip: ip,
          port: port.toString(),
          username: username,
          password: password,
          routerId: fetched,
        );
      }
    } catch (e) {
      debugPrint('[MultiDashboard] Gagal ambil Software ID $ip: $e');
    } finally {
      if (service is MikrotikNativeService) service.dispose();
    }
  }

  Future<void> _persistMonitoredRouters() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('monitored_routers', jsonEncode(_monitoredRouters));
  }

  void _addNewRouter() {
    final ipController = TextEditingController();
    final portController = TextEditingController(text: '8728');
    final userController = TextEditingController();
    final passController = TextEditingController();
    bool isTesting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text('Tambah Router Pantauan', style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: ipController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'IP Address', labelStyle: TextStyle(color: Colors.white70)),
                  ),
                  TextField(
                    controller: portController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'API Port (Default: 8728)', labelStyle: TextStyle(color: Colors.white70)),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: userController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Username', labelStyle: TextStyle(color: Colors.white70)),
                  ),
                  TextField(
                    controller: passController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Password', labelStyle: TextStyle(color: Colors.white70)),
                    obscureText: true,
                  ),
                  if (isTesting) ...[
                    const SizedBox(height: 20),
                    const CircularProgressIndicator(),
                    const SizedBox(height: 10),
                    const Text('Mengetes koneksi...', style: TextStyle(color: Colors.white70)),
                  ]
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isTesting ? null : () => Navigator.pop(context),
                child: const Text('Batal', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                onPressed: isTesting
                    ? null
                    : () async {
                        final ip = ipController.text.trim();
                        final port = int.tryParse(portController.text.trim()) ?? 8728;
                        final username = userController.text.trim();
                        final password = passController.text.trim();

                        if (ip.isEmpty || username.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('IP dan Username wajib diisi!')));
                          return;
                        }

                        try {
                          MikrotikService service;
                          final prefs = await SharedPreferences.getInstance();
                          final useNativeApi = prefs.getBool('useNativeApi') ?? false;

                          if (useNativeApi || port == 8728 || port == 8729) {
                            service = MikrotikNativeService(
                              ip: ip,
                              port: port.toString(),
                              username: username,
                              password: password,
                            );
                          } else {
                            service = MikrotikService(
                              ip: ip,
                              port: port.toString(),
                              username: username,
                              password: password,
                            );
                          }
                          
                          // Test Connection
                          final identity = await service.getIdentity();
                          
                          if (!mounted) return;

                          // Ambil Software ID sekalian selagi tersambung —
                          // tanpa ini router tersimpan tanpa identitas dan
                          // semua halaman yang butuh router_id akan gagal.
                          String fetchedId = '';
                          try {
                            final id = await service.getRouterSerialOrId();
                            // Abaikan ID cadangan hasil tebakan
                            if (!id.startsWith('RB-') && !id.contains(':')) {
                              fetchedId = id;
                            }
                          } catch (e) {
                            debugPrint('[MultiDashboard] Software ID gagal: $e');
                          }

                          // Sukses!
                          final newRouter = {
                            'address': '$ip:$port',
                            'username': username,
                            'password': password,
                            'routerId': fetchedId,
                          };

                          setState(() {
                            _monitoredRouters.add(newRouter);
                          });

                          await prefs.setString('monitored_routers', jsonEncode(_monitoredRouters));

                          Navigator.pop(context); // Tutup dialog
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Berhasil terhubung ke ${identity['name']}!')));
                          
                          // Geser ke router baru
                          Future.delayed(const Duration(milliseconds: 300), () {
                            _pageController.animateToPage(
                              _monitoredRouters.length - 1,
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeInOut,
                            );
                          });

                        } catch (e) {
                          setStateDialog(() => isTesting = false);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Gagal terhubung: $e'),
                            backgroundColor: Colors.red,
                          ));
                        }
                      },
                child: const Text('Test & Tambah', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _removeRouter(int index) async {
    if (_monitoredRouters.length <= 1) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimal harus ada 1 router!')),
      );
      return;
    }

    setState(() {
      _monitoredRouters.removeAt(index);
    });
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('monitored_routers', jsonEncode(_monitoredRouters));
    
    // Reset page ke 0
    _pageController.jumpToPage(0);
    _updateGlobalSession(0);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Global Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () {
                Provider.of<RouterSessionProvider>(context, listen: false).clearSession();
                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
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
                              colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Text('Mikrotik Monitor', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Consumer<RouterSessionProvider>(
                                builder: (context, session, child) {
                                  return Text(
                                    'Halo, ${session.username ?? 'Admin'}!',
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                                  );
                                },
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
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.people),
                          title: const Text('Semua User'),
                          onTap: () {
                            Navigator.of(context).pop();
                            Future.delayed(const Duration(milliseconds: 250), () {
                              Navigator.of(context, rootNavigator: true).pushNamed('/all-users');
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
                              contentPadding: const EdgeInsets.only(left: 72),
                              onTap: () {
                                Navigator.of(context).pop();
                                Future.delayed(const Duration(milliseconds: 250), () {
                                  Navigator.of(context, rootNavigator: true).pushNamed('/secrets-active');
                                });
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.account_box),
                              title: const Text('PPP Profile'),
                              contentPadding: const EdgeInsets.only(left: 72),
                              onTap: () {
                                Navigator.of(context).pop();
                                Future.delayed(const Duration(milliseconds: 250), () {
                                  Navigator.of(context, rootNavigator: true).pushNamed('/ppp-profile');
                                });
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.add),
                              title: const Text('Tambah'),
                              contentPadding: const EdgeInsets.only(left: 72),
                              onTap: () {
                                Navigator.of(context).pop();
                                Future.delayed(const Duration(milliseconds: 250), () {
                                  Navigator.of(context, rootNavigator: true).pushNamed('/tambah');
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
                            Future.delayed(const Duration(milliseconds: 250), () {
                              Navigator.of(context, rootNavigator: true).pushNamed('/system-resource');
                            });
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.show_chart),
                          title: const Text('Traffic'),
                          onTap: () {
                            Navigator.of(context).pop();
                            Future.delayed(const Duration(milliseconds: 250), () {
                              Navigator.of(context, rootNavigator: true).pushNamed('/traffic');
                            });
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.call_split),
                          title: const Text('ODP Management'),
                          onTap: () {
                            Navigator.of(context).pop();
                            Future.delayed(const Duration(milliseconds: 250), () {
                              Navigator.of(context, rootNavigator: true).pushNamed('/odp');
                            });
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.map),
                          title: const Text('Customer Map'),
                          onTap: () {
                            Navigator.of(context).pop();
                            Future.delayed(const Duration(milliseconds: 250), () {
                              Navigator.of(context, rootNavigator: true).pushNamed('/customer-map');
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
                                Future.delayed(const Duration(milliseconds: 250), () {
                                  Navigator.of(context, rootNavigator: true).pushNamed('/billing');
                                });
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.money_off),
                              title: const Text('Pengeluaran'),
                              contentPadding: const EdgeInsets.only(left: 72),
                              onTap: () {
                                Navigator.of(context).pop();
                                Future.delayed(const Duration(milliseconds: 250), () {
                                  Navigator.of(context, rootNavigator: true).pushNamed('/expense');
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
                            Future.delayed(const Duration(milliseconds: 250), () {
                              Navigator.of(context, rootNavigator: true).pushNamed('/genieacs');
                            });
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.history),
                          title: const Text('Logs'),
                          onTap: () {
                            Navigator.of(context).pop();
                            Future.delayed(const Duration(milliseconds: 250), () {
                              Navigator.of(context, rootNavigator: true).pushNamed('/log');
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
                    Navigator.of(context, rootNavigator: true).pushNamed('/setting');
                  });
                },
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _monitoredRouters.length + 1,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                  if (index < _monitoredRouters.length) {
                    _updateGlobalSession(index);
                  }
                },
                itemBuilder: (context, index) {
                  if (index == _monitoredRouters.length) {
                    return _buildAddRouterPage();
                  }
                  return SingleRouterView(
                    routerConfig: _monitoredRouters[index],
                    useNativeApi: _useNativeApi,
                  );
                },
              ),
            ),
            
            // INDIKATOR TITIK DI PALING BAWAH
            Padding(
              padding: const EdgeInsets.only(bottom: 120, top: 10), // Memberi ruang untuk BottomNav
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _monitoredRouters.length + 1,
                  (index) => index == _monitoredRouters.length
                      ? Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.add, 
                            size: _currentPage == index ? 12 : 10, 
                            color: _currentPage == index ? Colors.black : Colors.black38,
                          ),
                        )
                      : Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 8 : 6,
                          height: _currentPage == index ? 8 : 6,
                          decoration: BoxDecoration(
                            color: _currentPage == index ? Colors.black : Colors.black38,
                            shape: BoxShape.circle,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
        
        // BOTTOM NAVIGATION
        bottomNavigationBar: _buildBottomNav(context),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 30),
      height: 80,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 40,
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
              border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(icon: Icons.dashboard_rounded, label: 'Home', isSelected: true, onTap: () {}),
                _buildNavItem(icon: Icons.add_circle_outline_rounded, label: 'Tambah', isSelected: false, onTap: () => Navigator.pushNamed(context, '/tambah')),
                _buildNavItem(icon: Icons.vpn_key_rounded, label: 'Profile', isSelected: false, onTap: () => Navigator.pushNamed(context, '/ppp-profile')),
                _buildNavItem(icon: Icons.settings_rounded, label: 'Setting', isSelected: false, onTap: () => Navigator.pushNamed(context, '/setting')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required String label, required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: isSelected ? BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(20)) : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? const Color(0xFF0277BD) : const Color(0xFF455A64), size: 26),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: isSelected ? const Color(0xFF0277BD) : const Color(0xFF455A64), fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  Widget _buildAddRouterPage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1976D2), Color(0xFF42A5F5)]),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
            ),
            child: const Icon(Icons.router, size: 64, color: Colors.white),
          ),
          const SizedBox(height: 24),
          const Text(
            'Kelola Dashboard',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Ketuk untuk menambah atau menghapus router dari layar pantauan utama Anda.',
            style: TextStyle(fontSize: 14, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Expanded(
            child: _savedLogins.isEmpty
                ? const Center(child: Text('Tidak ada riwayat router tersimpan.\nSilakan login manual terlebih dahulu di halaman Login utama.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    itemCount: _savedLogins.length,
                    itemBuilder: (context, index) {
                      final login = _savedLogins[index];
                      // Periksa apakah sudah ada di monitoredRouters
                      final isAlreadyAdded = _monitoredRouters.any((element) => element['address'] == login['address']);
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isAlreadyAdded ? Colors.blue.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isAlreadyAdded ? Colors.blue.withOpacity(0.5) : Colors.transparent, width: 1),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: isAlreadyAdded ? Colors.blue : Colors.grey.withOpacity(0.5),
                            child: const Icon(Icons.wifi, color: Colors.white, size: 20),
                          ),
                          title: Text(login['name'] ?? login['address'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Text('${login['username']} @ ${login['address']}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          trailing: isAlreadyAdded 
                            ? IconButton(
                                icon: const Icon(Icons.remove_circle, color: Colors.redAccent, size: 28),
                                onPressed: () => _removeRouterByAddress(login['address'] ?? ''),
                              )
                            : IconButton(
                                icon: const Icon(Icons.add_circle, color: Colors.greenAccent, size: 28),
                                onPressed: () => _testAndAddRouter(login),
                              ),
                          onTap: isAlreadyAdded 
                            ? () => _removeRouterByAddress(login['address'] ?? '')
                            : () => _testAndAddRouter(login),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _removeRouterByAddress(String address) async {
    if (_monitoredRouters.length <= 1) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimal harus ada 1 router!')),
      );
      return;
    }

    setState(() {
      _monitoredRouters.removeWhere((element) => element['address'] == address);
    });
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('monitored_routers', jsonEncode(_monitoredRouters));
    
    // Jump to the nearest valid page
    if (_currentPage >= _monitoredRouters.length) {
      _pageController.jumpToPage(_monitoredRouters.length - 1);
      _updateGlobalSession(_monitoredRouters.length - 1);
    }
  }

  void _testAndAddRouter(Map<String, String> login) async {
    final address = login['address'] ?? '';
    final username = login['username'] ?? '';
    final password = login['password'] ?? '';

    final parts = address.split(':');
    final ip = parts.isNotEmpty ? parts[0] : '';
    final port = parts.length > 1 ? int.tryParse(parts[1]) ?? 8728 : 8728;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Mengetes Koneksi...', style: TextStyle(color: Colors.white)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Harap tunggu...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );

    try {
      MikrotikService service;
      final prefs = await SharedPreferences.getInstance();
      final useNativeApi = prefs.getBool('useNativeApi') ?? false;

      if (useNativeApi || port == 8728 || port == 8729) {
        service = MikrotikNativeService(ip: ip, port: port.toString(), username: username, password: password);
      } else {
        service = MikrotikService(ip: ip, port: port.toString(), username: username, password: password);
      }
      
      final identity = await service.getIdentity();

      // Ambil Software ID selagi tersambung. Login tersimpan lama umumnya
      // belum menyimpannya, dan tanpa ini router masuk tanpa identitas.
      String routerId = (login['routerId'] ?? '').toString();
      if (routerId.isEmpty) {
        try {
          final id = await service.getRouterSerialOrId();
          // Abaikan ID cadangan hasil tebakan (RB-identity@ip:port / ip:port)
          if (!id.startsWith('RB-') && !id.contains(':')) {
            routerId = id;
          }
        } catch (e) {
          debugPrint('[MultiDashboard] Software ID gagal: $e');
        }
      }
      if (!mounted) return;

      Navigator.pop(context); // Tutup loading

      final newRouter = {
        'address': '$ip:$port',
        'username': username,
        'password': password,
        'routerId': routerId,
      };

      setState(() {
        _monitoredRouters.add(newRouter);
      });

      await prefs.setString('monitored_routers', jsonEncode(_monitoredRouters));

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Berhasil terhubung ke ${identity['name']}!')));
      
      // Kembali ke router yang baru ditambahkan
      Future.delayed(const Duration(milliseconds: 300), () {
        _pageController.animateToPage(
          _monitoredRouters.length - 1,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      });
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Tutup loading
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Gagal terhubung: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }
}

// Widget Tunggal untuk setiap Router
class SingleRouterView extends StatefulWidget {
  final Map<String, dynamic> routerConfig;
  final bool useNativeApi;

  const SingleRouterView({super.key, required this.routerConfig, required this.useNativeApi});

  @override
  State<SingleRouterView> createState() => _SingleRouterViewState();
}

class _SingleRouterViewState extends State<SingleRouterView> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late MikrotikService _service;
  late MikrotikProvider _provider;
  Timer? _timer;
  bool _isStatsVisible = true;
  int _uptimeSeconds = 0;
  String _uptimeDisplay = '-';
  String _cpuLoad = '-';

  @override
  void initState() {
    super.initState();
    _initConnection();
  }

  void _initConnection() {
    final router = widget.routerConfig;
    final parts = router['address'].toString().split(':');
    final ip = parts[0];
    final port = parts.length > 1 ? int.tryParse(parts[1]) ?? 8728 : 8728;

    if (widget.useNativeApi || port == 8728 || port == 8729) {
      _service = MikrotikNativeService(
        ip: ip,
        port: port.toString(),
        username: router['username'] ?? '',
        password: router['password'] ?? '',
      );
    } else {
      _service = MikrotikService(
        ip: ip,
        port: port.toString(),
        username: router['username'] ?? '',
        password: router['password'] ?? '',
      );
    }

    _provider = MikrotikProvider(_service);
    _provider.refreshData(forceRefresh: true).then((_) {
      if (mounted) {
        _updateLocalStats();
      }
    });

    // Lazy Polling setiap 4 detik
    _timer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted) return;
      if (_provider.identity == null) return; // Jangan polling jika belum pernah berhasil connect
      
      try {
        await _provider.fetchPPPStatusOnly();
        final resource = await _service.getResource();
        if (mounted) {
          setState(() {
            _cpuLoad = resource['cpu-load']?.toString() ?? '-';
            final uptimeStr = resource['uptime'] ?? '0';
            _uptimeSeconds = _parseUptimeToSeconds(uptimeStr);
            _uptimeDisplay = _formatUptime(_uptimeSeconds);
          });
        }
      } catch (e) {
        // Abaikan error polling agar UI tidak berkedip
      }
    });
  }

  void _updateLocalStats() {
    final resource = _provider.resource ?? {};
    _cpuLoad = resource['cpu-load']?.toString() ?? '-';
    final uptimeStr = resource['uptime'] ?? '0';
    _uptimeSeconds = _parseUptimeToSeconds(uptimeStr);
    _uptimeDisplay = _formatUptime(_uptimeSeconds);
    setState(() {});
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
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ChangeNotifierProvider<MikrotikProvider>.value(
      value: _provider,
      child: Consumer<MikrotikProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.identity == null && provider.error == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && provider.identity == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 64),
                    const SizedBox(height: 16),
                    const Text('Router Offline atau Tidak Terjangkau', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('${provider.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                      onPressed: () {
                        provider.refreshData(forceRefresh: true).then((_) {
                          if (mounted) _updateLocalStats();
                        });
                      },
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      label: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(height: 12),
                    const Text('Pastikan router menyala dan terhubung ke jaringan.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
            );
          }

          final identity = provider.identity ?? widget.routerConfig['address'];
          final resource = provider.resource ?? {};
          final boardName = resource['board-name'] ?? '-';
          final version = resource['version'] ?? '-';
          final model = resource['platform'] ?? '-';

          return RefreshIndicator(
            onRefresh: () async {
              await provider.refreshData(forceRefresh: true);
              _updateLocalStats();
            },
            child: ListView(
              padding: const EdgeInsets.only(left: 12, right: 12, top: 8),
              children: [
                // KARTU BIRU ROUTEROS
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(identity, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Row(children: [
                            const Icon(Icons.developer_board, color: Colors.white70, size: 18),
                            const SizedBox(width: 6),
                            Text('Board Name : $boardName', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                          ]),
                          const SizedBox(height: 2),
                          Row(children: [
                            const Icon(Icons.router, color: Colors.white70, size: 18),
                            const SizedBox(width: 6),
                            Text('RouterOS : $version', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                          ]),
                          const SizedBox(height: 2),
                          Row(children: [
                            const Icon(Icons.memory, color: Colors.white70, size: 18),
                            const SizedBox(width: 6),
                            Text('Model : $model', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                          ]),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.access_time, color: Colors.white70, size: 18),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text('Uptime: $_uptimeDisplay', style: const TextStyle(color: Colors.white70, fontSize: 14), overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.speed, color: Colors.white70, size: 18),
                              const SizedBox(width: 4),
                              Text('CPU: $_cpuLoad%', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _secretBox(context, provider),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1.3,
                        child: _statGridBox(
                          context,
                          Icons.wifi,
                          'Active',
                          _isStatsVisible ? provider.pppSessions.length : -1,
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
                          _isStatsVisible ? provider.totalOfflineUsers : -1,
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
          );
        },
      ),
    );
  }

  Widget _secretBox(BuildContext context, MikrotikProvider provider) {
    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const AllUsersScreen()));
      },
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF388E3C)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.people, color: Colors.white, size: 28),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Total Users', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(_isStatsVisible ? '${provider.pppSecrets.length}' : '***', style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _isStatsVisible = !_isStatsVisible;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: Icon(_isStatsVisible ? Icons.visibility : Icons.visibility_off, color: Colors.white, size: 28),
              ),
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
        gradient: const LinearGradient(colors: [Color(0xFFFFA726), Color(0xFFF57C00)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/billing'),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.receipt_long, color: Colors.white, size: 28),
            ),
            const Expanded(child: Center(child: Text('Billing', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w800)))),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.arrow_forward, color: Colors.white, size: 28),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statGridBox(BuildContext context, IconData icon, String label, int value, Color color, String route, {String? statusFilter, String? sortOption}) {
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
                ? [const Color(0xFF42A5F5), const Color(0xFF1976D2)]
                : label == 'Offline'
                    ? [const Color(0xFFF44336), const Color(0xFFD32F2F)]
                    : label == 'Secret'
                        ? [const Color(0xFF4CAF50), const Color(0xFF388E3C)]
                        : [const Color(0xFFFFA726), const Color(0xFFF57C00)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 4),
            if (label != 'Log')
              Text(value == -1 ? '***' : value.toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white))
            else
              const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}

