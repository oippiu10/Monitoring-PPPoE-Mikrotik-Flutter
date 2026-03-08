import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/router_session_provider.dart';
import '../widgets/gradient_container.dart';
import '../main.dart';

class EditPPPProfileScreen extends StatefulWidget {
  final Map<String, dynamic> profile;

  const EditPPPProfileScreen({
    super.key,
    required this.profile,
  });

  @override
  State<EditPPPProfileScreen> createState() => _EditPPPProfileScreenState();
}

class _EditPPPProfileScreenState extends State<EditPPPProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _localAddressController;
  late TextEditingController _remoteAddressController;
  late TextEditingController _rateLimitController;
  late TextEditingController _sessionTimeoutController;
  late TextEditingController _idleTimeoutController;

  late String _onlyOne;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // Initialize controllers with current profile data
    _nameController = TextEditingController(
      text: widget.profile['name']?.toString() ?? '',
    );
    _localAddressController = TextEditingController(
      text: widget.profile['local-address']?.toString() ?? '',
    );
    _remoteAddressController = TextEditingController(
      text: widget.profile['remote-address']?.toString() ?? '',
    );
    _rateLimitController = TextEditingController(
      text: widget.profile['rate-limit']?.toString() ?? '',
    );
    _sessionTimeoutController = TextEditingController(
      text: widget.profile['session-timeout']?.toString() ?? '',
    );
    _idleTimeoutController = TextEditingController(
      text: widget.profile['idle-timeout']?.toString() ?? '',
    );

    // Initialize only-one value
    final onlyOneValue = widget.profile['only-one']?.toString() ?? 'default';
    _onlyOne = onlyOneValue;
  }

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

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final routerSession = context.read<RouterSessionProvider>();
      final service = await routerSession.getService();

      final profileId = widget.profile['.id']?.toString();
      if (profileId == null) {
        throw Exception('Profile ID tidak ditemukan');
      }

      final data = <String, String>{};

      // Only include fields that have changed
      if (_nameController.text.trim() != widget.profile['name']?.toString()) {
        data['name'] = _nameController.text.trim();
      }
      if (_localAddressController.text.trim() !=
          widget.profile['local-address']?.toString()) {
        data['local-address'] = _localAddressController.text.trim();
      }
      if (_remoteAddressController.text.trim() !=
          widget.profile['remote-address']?.toString()) {
        data['remote-address'] = _remoteAddressController.text.trim();
      }
      if (_rateLimitController.text.trim() !=
          widget.profile['rate-limit']?.toString()) {
        data['rate-limit'] = _rateLimitController.text.trim();
      }
      if (_sessionTimeoutController.text.trim() !=
          widget.profile['session-timeout']?.toString()) {
        data['session-timeout'] = _sessionTimeoutController.text.trim();
      }
      if (_idleTimeoutController.text.trim() !=
          widget.profile['idle-timeout']?.toString()) {
        data['idle-timeout'] = _idleTimeoutController.text.trim();
      }
      if (_onlyOne != widget.profile['only-one']?.toString()) {
        data['only-one'] = _onlyOne;
      }

      if (data.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada perubahan yang disimpan'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
        return;
      }

      await service.updatePPPProfile(profileId, data);

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile berhasil diperbarui'),
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
          content: Text('Gagal memperbarui profile: ${e.toString()}'),
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
            'Edit PPP Profile',
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
                          Icons.edit_outlined,
                          color: Colors.orange,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Edit konfigurasi profile PPPoE',
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

                // Form Fields (sama seperti Add Profile Screen)
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

                // Update Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _updateProfile,
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
                      _isLoading ? 'Menyimpan...' : 'Simpan Perubahan',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[700],
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
