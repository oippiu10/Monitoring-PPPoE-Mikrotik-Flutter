import 'package:flutter/material.dart';
import '../services/account_service.dart';
import '../widgets/gradient_container.dart';
import 'login_screen.dart';
import 'router_picker_screen.dart';

/// Layar masuk berbasis **akun web**, menggantikan pengisian
/// IP/port/user/password router beserta pengecekan lisensi.
///
/// Deteksi kemampuan server dilakukan tanpa permintaan tambahan: percobaan
/// login itu sendiri yang menentukan. Kalau server membalas 404, berarti belum
/// mendukung — aplikasi beralih ke [LoginScreen] lama dan mengingat keputusan
/// itu per base URL, jadi pengecekan tidak pernah terulang.
class AccountLoginScreen extends StatefulWidget {
  const AccountLoginScreen({super.key});

  @override
  State<AccountLoginScreen> createState() => _AccountLoginScreenState();
}

class _AccountLoginScreenState extends State<AccountLoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _busy = true;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _mulai();
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _mulai() async {
    // Server yang sudah terbukti tidak mendukung: langsung ke alur lama,
    // tanpa memperlihatkan form akun yang pasti gagal.
    final didukung = await AccountService.cachedSupport();
    if (!mounted) return;
    if (didukung == false) {
      _keAlurLama(ganti: true);
      return;
    }

    // Sudah punya token yang masih tersimpan → lewati layar ini.
    if (await AccountService.hasToken()) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const RouterPickerScreen()),
      );
      return;
    }

    if (mounted) setState(() => _busy = false);
  }

  void _keAlurLama({bool ganti = false}) {
    final rute = MaterialPageRoute(builder: (_) => const LoginScreen());
    if (ganti) {
      Navigator.of(context).pushReplacement(rute);
    } else {
      Navigator.of(context).push(rute);
    }
  }

  Future<void> _masuk() async {
    final u = _userCtrl.text.trim();
    final p = _passCtrl.text;
    if (u.isEmpty || p.isEmpty) {
      setState(() => _error = 'Username dan password wajib diisi.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final hasil = await AccountService.login(u, p);
    if (!mounted) return;

    switch (hasil.status) {
      case AccountLoginStatus.ok:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const RouterPickerScreen()),
        );
        break;

      case AccountLoginStatus.notSupported:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Server ini belum mendukung login akun. '
                'Memakai cara lama.'),
          ),
        );
        _keAlurLama(ganti: true);
        break;

      case AccountLoginStatus.rejected:
      case AccountLoginStatus.error:
        setState(() {
          _busy = false;
          _error = hasil.message;
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.router_outlined,
                        size: 64, color: isDark ? Colors.white : Colors.white),
                    const SizedBox(height: 16),
                    const Text(
                      'Masuk dengan Akun',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Gunakan akun yang sama seperti di web. '
                      'Daftar router diambil otomatis.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 28),

                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: _userCtrl,
                              enabled: !_busy,
                              autocorrect: false,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Username',
                                prefixIcon: Icon(Icons.person_outline),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _passCtrl,
                              enabled: !_busy,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _busy ? null : _masuk(),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscure
                                      ? Icons.visibility_off
                                      : Icons.visibility),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 14),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.error_outline,
                                      color: Colors.red, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: const TextStyle(
                                          color: Colors.red, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _busy ? null : _masuk,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade800,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: _busy
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('MASUK',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),
                    TextButton.icon(
                      onPressed: _busy ? null : () => _keAlurLama(),
                      icon: const Icon(Icons.settings_ethernet,
                          size: 18, color: Colors.white70),
                      label: const Text(
                        'Sambung manual ke router',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                    const Text(
                      'Untuk router yang belum terdaftar di web',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
