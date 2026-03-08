import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/mikrotik_provider.dart';
import '../widgets/gradient_container.dart';

class EditScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const EditScreen({super.key, required this.user});

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _selectedProfile;
  bool _isLoading = false;
  bool _isLoadingProfiles = true;
  String? _error;
  bool _obscurePassword = true;
  List<String> _profiles = [];

  @override
  void initState() {
    super.initState();
    _usernameController.text = widget.user['name'] ?? '';
    _passwordController.text = widget.user['password'] ?? '';
    _selectedProfile = widget.user['profile'];
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    try {
      setState(() {
        _error = null;
        _isLoadingProfiles = true;
      });

      final provider = Provider.of<MikrotikProvider>(context, listen: false);
      final profiles = await provider.service.getPPPProfile();

      if (mounted) {
        final loadedProfiles = profiles
            .map((profile) => profile['name'].toString())
            .toList()
          ..sort();

        String? selected = _selectedProfile;
        if (selected == null || !loadedProfiles.contains(selected)) {
          selected = loadedProfiles.isNotEmpty ? loadedProfiles.first : null;
        }

        setState(() {
          _profiles = loadedProfiles;
          _selectedProfile = selected;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Gagal memuat profile: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingProfiles = false);
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _showSuccessDialog({bool wasDisconnected = false}) async {
    bool obscureDialogPassword = true;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Widget buildDetailRow(IconData icon, String label, String value,
              {bool isPassword = false}) {
            return Row(
              children: [
                Icon(icon, size: 20, color: Colors.grey.shade600),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (isPassword)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                obscureDialogPassword ? '••••••••' : value,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                obscureDialogPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                size: 20,
                              ),
                              onPressed: () {
                                setDialogState(() {
                                  obscureDialogPassword =
                                      !obscureDialogPassword;
                                });
                              },
                            ),
                          ],
                        )
                      else
                        Text(
                          value,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          }

          return PopScope(
            canPop: false,
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Success Icon
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Icon(
                          Icons.check_circle,
                          color: Colors.green.shade400,
                          size: 80,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Success Title
                    const Text(
                      'User Berhasil Diperbarui',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // User Details
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          buildDetailRow(Icons.person, 'Username',
                              _usernameController.text),
                          const SizedBox(height: 8),
                          buildDetailRow(
                            Icons.lock,
                            'Password',
                            _passwordController.text,
                            isPassword: true,
                          ),
                          const SizedBox(height: 8),
                          buildDetailRow(Icons.category, 'Profile',
                              _selectedProfile ?? ''),
                        ],
                      ),
                    ),

                    // Disconnect Info Badge (if user was disconnected)
                    if (wasDisconnected) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 18, color: Colors.orange.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Koneksi aktif telah diputus. User akan menggunakan data baru saat reconnect.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // OK Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close dialog
                          Navigator.of(context).pop(
                              true); // Return to previous screen with refresh flag
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'OK',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _updateUser() async {
    // Reset error state
    setState(() => _error = null);

    // Validate form
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProfile == null) {
      setState(() => _error = 'Profile harus dipilih');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile harus dipilih'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show loading state
    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<MikrotikProvider>(context, listen: false);

      final result = await provider.service.updatePPPSecret(
        widget.user['name'],
        {
          'name': _usernameController.text.trim(),
          'password': _passwordController.text.trim(),
          'profile': _selectedProfile!,
        },
      );

      if (!mounted) return;

      // Show success dialog with disconnect info
      await _showSuccessDialog(
        wasDisconnected: result['disconnected'] ?? false,
      );

      // Refresh data
      provider.refreshData();
    } catch (e) {
      if (!mounted) return;

      final errorMessage = e.toString().replaceAll('Exception: ', '');
      setState(() => _error = errorMessage);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
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
    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Edit User PPP',
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Username field
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.person),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Username tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Password field
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: InputBorder.none,
                        prefixIcon: const Icon(Icons.lock),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(
                                () => _obscurePassword = !_obscurePassword);
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Profile dropdown
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: _isLoadingProfiles
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : DropdownButtonFormField<String>(
                            value: _selectedProfile,
                            decoration: const InputDecoration(
                              labelText: 'Profile',
                              border: InputBorder.none,
                              prefixIcon: Icon(Icons.category),
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 16),
                            ),
                            items: _profiles.map((String profile) {
                              return DropdownMenuItem<String>(
                                value: profile,
                                child: Text(profile),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedProfile = newValue;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Profile harus dipilih';
                              }
                              return null;
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // Error message
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Submit button
                SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _updateUser,
                    icon: const Icon(Icons.save),
                    label: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('SIMPAN'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade800,
                      foregroundColor: Colors.white,
                      elevation: 4,
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
      ),
    );
  }
}
