import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/router_session_provider.dart';
import '../services/account_service.dart';
import '../widgets/gradient_container.dart';
import 'account_login_screen.dart';

/// Daftar router milik akun yang sedang masuk, diambil dari
/// `api/mobile_routers.php`.
///
/// Daftar ini menggantikan `monitored_routers` yang dulu disimpan sendiri di
/// HP. Perbedaan pentingnya: `router_id` datang dari kolom `software_id` di
/// server, bukan hasil tebakan aplikasi dari perangkat. Tebakan itulah yang
/// dulu menghasilkan ID cadangan dan membuat data antar router tertukar.
class RouterPickerScreen extends StatefulWidget {
  const RouterPickerScreen({super.key});

  @override
  State<RouterPickerScreen> createState() => _RouterPickerScreenState();
}

class _RouterPickerScreenState extends State<RouterPickerScreen> {
  bool _busy = true;
  String? _error;
  List<AccountRouter> _routers = [];
  Map<String, String?> _akun = {};

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final akun = await AccountService.getAccount();
      final daftar = await AccountService.fetchRouters();
      if (!mounted) return;

      // Selaraskan daftar lokal dengan server supaya Multi Dashboard memakai
      // sumber yang sama — termasuk router_id yang benar.
      await _simpanKeMonitoredRouters(daftar);

      setState(() {
        _akun = akun;
        _routers = daftar;
        _busy = false;
      });
    } on AccountSessionExpired catch (e) {
      if (!mounted) return;
      _kembaliKeLogin(e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _simpanKeMonitoredRouters(List<AccountRouter> daftar) async {
    final prefs = await SharedPreferences.getInstance();
    final isi = daftar
        .where((r) => r.softwareId.isNotEmpty)
        .map((r) => {
              'address': r.address,
              'username': r.username,
              'password': r.password,
              'routerId': r.softwareId,
            })
        .toList();
    await prefs.setString('monitored_routers', jsonEncode(isi));
  }

  void _kembaliKeLogin([String? pesan]) {
    if (pesan != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan)));
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AccountLoginScreen()),
      (route) => false,
    );
  }

  Future<void> _keluar() async {
    await AccountService.logout();
    if (!mounted) return;
    _kembaliKeLogin();
  }

  void _pilih(AccountRouter r) {
    if (r.softwareId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Router ini belum punya Software ID di web. '
            'Lengkapi dulu lewat Setting → Routers.',
          ),
        ),
      );
      return;
    }

    Provider.of<RouterSessionProvider>(context, listen: false).saveSession(
      routerId: r.softwareId,
      ip: r.host,
      port: r.port.toString(),
      username: r.username,
      password: r.password,
    );

    Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final nama = _akun['full_name'] ?? _akun['username'] ?? '';

    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Pilih Router'),
          actions: [
            IconButton(
              tooltip: 'Muat ulang',
              icon: const Icon(Icons.refresh),
              onPressed: _busy ? null : _muat,
            ),
            IconButton(
              tooltip: 'Keluar',
              icon: const Icon(Icons.logout),
              onPressed: _busy ? null : _keluar,
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (nama.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.account_circle,
                          color: Colors.white70, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Masuk sebagai $nama'
                          '${_akun['role'] != null ? ' (${_akun['role']})' : ''}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(child: _isi()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _isi() {
    if (_busy) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 14),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _muat,
                icon: const Icon(Icons.refresh),
                label: const Text('COBA LAGI'),
              ),
            ],
          ),
        ),
      );
    }

    if (_routers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Belum ada router terdaftar.\n'
            'Tambahkan dulu lewat web: Setting → Routers.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 15),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _muat,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
        itemCount: _routers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final r = _routers[i];
          final tanpaId = r.softwareId.isEmpty;
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              leading: CircleAvatar(
                backgroundColor:
                    tanpaId ? Colors.orange.shade100 : Colors.blue.shade100,
                child: Icon(
                  tanpaId ? Icons.warning_amber : Icons.router,
                  color: tanpaId ? Colors.orange.shade800 : Colors.blue.shade800,
                ),
              ),
              title: Text(
                r.name.isEmpty ? r.address : r.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 3),
                  Text(r.address, style: const TextStyle(fontSize: 12)),
                  Text(
                    tanpaId
                        ? 'Software ID belum diisi di web'
                        : '${r.softwareId}  •  ${r.onRouter} aktif dari ${r.totalCustomers} pelanggan',
                    style: TextStyle(
                      fontSize: 12,
                      color: tanpaId ? Colors.orange.shade800 : null,
                    ),
                  ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pilih(r),
            ),
          );
        },
      ),
    );
  }
}
