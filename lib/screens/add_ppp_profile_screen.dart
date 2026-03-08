import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/router_session_provider.dart';
import '../widgets/gradient_container.dart';
import '../main.dart';

class AddPPPProfileScreen extends StatefulWidget {
  const AddPPPProfileScreen({super.key});

  @override
  State<AddPPPProfileScreen> createState() => _AddPPPProfileScreenState();
}

class _AddPPPProfileScreenState extends State<AddPPPProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _localAddressController = TextEditingController();
  final _remoteAddressController = TextEditingController();
  final _rateLimitController = TextEditingController();
  final _sessionTimeoutController = TextEditingController();
  final _idleTimeoutController = TextEditingController();

  String _onlyOne = 'default';
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _localAddressController.dispose();
    _remoteAddressController.dispose();
    _rateLimitController.dispose();
    _sessionTimeoutController.dispose();
    _idleTimeoutController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final routerSession = context.read<RouterSessionProvider>();
      final service = await routerSession.getService();

      final data = <String, String>{
        'name': _nameController.text.trim(),
      };

      // Add optional fields only if they're not empty
      if (_localAddressController.text.trim().isNotEmpty) {
        data['local-address'] = _localAddressController.text.trim();
      }
      if (_remoteAddressController.text.trim().isNotEmpty) {
        data['remote-address'] = _remoteAddressController.text.trim();
      }
      if (_rateLimitController.text.trim().isNotEmpty) {
        data['rate-limit'] = _rateLimitController.text.trim();
      }
      if (_sessionTimeoutController.text.trim().isNotEmpty) {
        data['session-timeout'] = _sessionTimeoutController.text.trim();
      }
      if (_idleTimeoutController.text.trim().isNotEmpty) {
        data['idle-timeout'] = _idleTimeoutController.text.trim();
      }
      if (_onlyOne != 'default') {
        data['only-one'] = _onlyOne;
      }

      await service.addPPPProfile(data);

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile berhasil ditambahkan'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Go back to profile list
      Navigator.pop(context, true); // Return true to indicate success
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menambahkan profile: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Tambah PPP Profile',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Buat profile PPPoE baru untuk mengatur konfigurasi koneksi user',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white70 : Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Form Fields
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
                        // Profile Name (Required)
                        Text(
                          'Nama Profile *',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameController,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Contoh: 2Mbps, 5Mbps, Premium',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white38 : Colors.grey,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF2D2D2D)
                                : Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: Icon(
                              Icons.label_outline,
                              color: isDark ? Colors.white70 : Colors.grey[600],
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Nama profile harus diisi';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Local Address
                        Text(
                          'Local Address',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'IP address untuk router (gateway)',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _localAddressController,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Contoh: 10.10.10.1',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white38 : Colors.grey,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF2D2D2D)
                                : Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: Icon(
                              Icons.router_outlined,
                              color: isDark ? Colors.white70 : Colors.grey[600],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Remote Address
                        Text(
                          'Remote Address',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'IP pool untuk client',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _remoteAddressController,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Contoh: 10.10.10.2-10.10.10.254',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white38 : Colors.grey,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF2D2D2D)
                                : Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: Icon(
                              Icons.devices_outlined,
                              color: isDark ? Colors.white70 : Colors.grey[600],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Rate Limit
                        Text(
                          'Rate Limit',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Kecepatan upload/download (format: upload/download)',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _rateLimitController,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Contoh: 2M/2M, 5M/5M, 10M/10M',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white38 : Colors.grey,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF2D2D2D)
                                : Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: Icon(
                              Icons.speed_outlined,
                              color: isDark ? Colors.white70 : Colors.grey[600],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Session Timeout
                        Text(
                          'Session Timeout',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Batas waktu sesi (dalam detik, 0 = unlimited)',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _sessionTimeoutController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Contoh: 0, 3600, 86400',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white38 : Colors.grey,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF2D2D2D)
                                : Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: Icon(
                              Icons.timer_outlined,
                              color: isDark ? Colors.white70 : Colors.grey[600],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Idle Timeout
                        Text(
                          'Idle Timeout',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Batas waktu idle (dalam detik, 0 = unlimited)',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _idleTimeoutController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Contoh: 0, 300, 600',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white38 : Colors.grey,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF2D2D2D)
                                : Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: Icon(
                              Icons.hourglass_empty_outlined,
                              color: isDark ? Colors.white70 : Colors.grey[600],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Only One
                        Text(
                          'Only One',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Batasi satu koneksi per user',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF2D2D2D)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonFormField<String>(
                            value: _onlyOne,
                            dropdownColor:
                                isDark ? const Color(0xFF2D2D2D) : Colors.white,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: Icon(
                                Icons.person_outline,
                                color:
                                    isDark ? Colors.white70 : Colors.grey[600],
                              ),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'default',
                                child: Text('Default'),
                              ),
                              DropdownMenuItem(
                                value: 'yes',
                                child: Text('Yes (Hanya 1 koneksi)'),
                              ),
                              DropdownMenuItem(
                                value: 'no',
                                child: Text('No (Multiple koneksi)'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() => _onlyOne = value!);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveProfile,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      _isLoading ? 'Menyimpan...' : 'Simpan Profile',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
