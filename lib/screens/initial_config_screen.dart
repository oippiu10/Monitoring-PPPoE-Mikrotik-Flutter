import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../widgets/gradient_container.dart';
import '../services/config_service.dart';
import '../services/api_service.dart';
import '../services/genieacs_config_service.dart';
import '../services/genieacs_service.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';

class InitialConfigScreen extends StatefulWidget {
  const InitialConfigScreen({super.key});

  @override
  State<InitialConfigScreen> createState() => _InitialConfigScreenState();
}

class _InitialConfigScreenState extends State<InitialConfigScreen> {
  final TextEditingController _apiUrlController = TextEditingController();
  final TextEditingController _genieacsUrlController = TextEditingController();
  final TextEditingController _genieacsUsernameController =
      TextEditingController();
  final TextEditingController _genieacsPasswordController =
      TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _genieacsFormKey = GlobalKey<FormState>();

  String _initialBaseUrl = '';
  bool _isDirty = false;
  bool _testing = false;
  bool? _lastTestOk; // null: belum dites, true: ok, false: gagal
  Map<String, dynamic>? _testResult;
  String _currentBaseUrl = '';

  // GenieACS state
  String _initialGenieACSUrl = '';
  bool _genieacsIsDirty = false;
  bool _genieacsTesting = false;
  bool? _genieacsLastTestOk;
  Map<String, dynamic>? _genieacsTestResult;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
    _apiUrlController.addListener(() {
      final current = _apiUrlController.text.trim();
      final changed = current != _initialBaseUrl.trim();
      if (changed != _isDirty) {
        setState(() {
          _isDirty = changed;
        });
      }
    });
    _genieacsUrlController.addListener(() {
      final current = _genieacsUrlController.text.trim();
      final changed = current != _initialGenieACSUrl.trim();
      if (changed != _genieacsIsDirty) {
        setState(() {
          _genieacsIsDirty = changed;
        });
      }
    });
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    _genieacsUrlController.dispose();
    _genieacsUsernameController.dispose();
    _genieacsPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentSettings() async {
    try {
      final baseUrl = await ConfigService.getBaseUrl();
      final genieacsUrl = await GenieACSConfigService.getGenieACSUrl() ?? '';
      final genieacsUsername =
          await GenieACSConfigService.getGenieACSUsername() ?? '';
      final genieacsPassword =
          await GenieACSConfigService.getGenieACSPassword() ?? '';

      if (mounted) {
        setState(() {
          _apiUrlController.text = baseUrl;
          _initialBaseUrl = baseUrl;
          _currentBaseUrl = baseUrl;
          _isDirty = false;
          _lastTestOk = null;
          _testResult = null;

          _genieacsUrlController.text = genieacsUrl;
          _genieacsUsernameController.text = genieacsUsername;
          _genieacsPasswordController.text = genieacsPassword;
          _initialGenieACSUrl = genieacsUrl;
          _genieacsIsDirty = false;
          _genieacsLastTestOk = null;
          _genieacsTestResult = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();

    final normalized = ConfigService.normalizeBaseUrl(_apiUrlController.text);
    _apiUrlController.text = normalized;
    await ConfigService.setBaseUrl(normalized);
    ApiService.clearCache();
    await ApiService.refreshBaseUrlFromStorage();

    setState(() {
      _initialBaseUrl = normalized;
      _currentBaseUrl = normalized;
      _isDirty = false;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Konfigurasi API berhasil disimpan'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _testApiConnection() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();

    setState(() {
      _testing = true;
      _lastTestOk = null;
      _testResult = null;
    });

    final normalized = ConfigService.normalizeBaseUrl(_apiUrlController.text);
    _apiUrlController.text = normalized;
    final result =
        await ConfigService.testConnectionDetailed(baseUrlOverride: normalized);

    if (!mounted) return;
    setState(() {
      _testing = false;
      _lastTestOk = result['success'];
      _testResult = result;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['success']
            ? 'Koneksi API berhasil! (${result['responseTime']}ms)'
            : 'Gagal terhubung ke API'),
        backgroundColor: result['success'] ? Colors.green : Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _resetToDefault() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset ke Default'),
        content: const Text(
            'Apakah Anda yakin ingin mengembalikan Base URL ke pengaturan default?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ConfigService.resetBaseUrl();
      await ApiService.refreshBaseUrlFromStorage();
      final defaultUrl = await ConfigService.getBaseUrl();

      _apiUrlController.text = defaultUrl;
      setState(() {
        _initialBaseUrl = defaultUrl;
        _currentBaseUrl = defaultUrl;
        _isDirty = false;
        _lastTestOk = null;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Base URL direset ke default'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _saveGenieACSSettings() async {
    if (!(_genieacsFormKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();

    final normalized =
        GenieACSConfigService.normalizeUrl(_genieacsUrlController.text);
    _genieacsUrlController.text = normalized;

    await GenieACSConfigService.setGenieACSUrl(normalized);
    await GenieACSConfigService.setGenieACSUsername(
        _genieacsUsernameController.text);
    await GenieACSConfigService.setGenieACSPassword(
        _genieacsPasswordController.text);

    setState(() {
      _initialGenieACSUrl = normalized;
      _genieacsIsDirty = false;
    });

    // Trigger background data fetch
    _fetchGenieACSDataInBackground();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Konfigurasi GenieACS berhasil disimpan. Memuat data...'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _fetchGenieACSDataInBackground() async {
    // Fetch in background without blocking UI
    try {
      final url =
          GenieACSConfigService.normalizeUrl(_genieacsUrlController.text);
      final username = _genieacsUsernameController.text;
      final password = _genieacsPasswordController.text;

      final service = GenieACSService(
        baseUrl: url,
        username: username,
        password: password,
      );

      print('[DEBUG] Fetching URL: $url');

      print('[GenieACS] Background fetch started...');
      final devices = await service.getDevices();

      // Cache the data
      await GenieACSConfigService.cacheDeviceData(devices);
      print(
          '[GenieACS] Background fetch completed. ${devices.length} devices cached.');
    } catch (e) {
      print('[GenieACS] Background fetch failed: $e');
    }
  }

  Future<void> _testGenieACSConnection() async {
    if (!(_genieacsFormKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();

    setState(() {
      _genieacsTesting = true;
      _genieacsLastTestOk = null;
      _genieacsTestResult = null;
    });

    final normalized =
        GenieACSConfigService.normalizeUrl(_genieacsUrlController.text);
    _genieacsUrlController.text = normalized;

    final stopwatch = Stopwatch()..start();
    try {
      final service = GenieACSService(
        baseUrl: normalized,
        username: _genieacsUsernameController.text,
        password: _genieacsPasswordController.text,
      );
      final isConnected = await service.testConnection();
      stopwatch.stop();

      if (!mounted) return;
      setState(() {
        _genieacsTesting = false;
        _genieacsLastTestOk = isConnected;
        _genieacsTestResult = {
          'success': isConnected,
          'responseTime': stopwatch.elapsedMilliseconds,
          'url': normalized,
        };
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isConnected
              ? 'Koneksi GenieACS berhasil! (${stopwatch.elapsedMilliseconds}ms)'
              : 'Gagal terhubung ke GenieACS'),
          backgroundColor: isConnected ? Colors.green : Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      stopwatch.stop();
      if (!mounted) return;
      setState(() {
        _genieacsTesting = false;
        _genieacsLastTestOk = false;
        _genieacsTestResult = {
          'success': false,
          'responseTime': stopwatch.elapsedMilliseconds,
          'error': e.toString(),
        };
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal terhubung: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildTestDetail(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
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
            'Konfigurasi Server',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: _resetToDefault,
              icon: const Icon(Icons.restore),
              tooltip: 'Reset ke Default',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current Configuration Card
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
                                Icon(
                                  Icons.info_outline,
                                  color: isDark
                                      ? Colors.blue[200]
                                      : Colors.blue[800],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Konfigurasi Saat Ini',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF2D2D2D)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.grey.shade700
                                      : Colors.grey.shade200,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Base URL Aktif:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _currentBaseUrl,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.settings,
                                    color:
                                        Colors.blue, // Always blue as requested
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Pengaturan API',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _apiUrlController,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Base URL',
                                  labelStyle: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                  hintText: 'https://example.com/api',
                                  hintStyle: TextStyle(
                                    color: isDark
                                        ? Colors.grey.shade600
                                        : Colors.grey.shade400,
                                  ),
                                  prefixIcon: const Icon(Icons.link),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  helperText:
                                      'Wajib menyertakan skema (http/https)',
                                  helperStyle: TextStyle(
                                    color: isDark
                                        ? Colors.grey.shade500
                                        : Colors.grey.shade600,
                                  ),
                                  suffixIcon: IconButton(
                                    tooltip: 'Clear Field',
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _apiUrlController.clear();
                                    },
                                  ),
                                ),
                                keyboardType: TextInputType.url,
                                validator: (value) {
                                  final v = (value ?? '').trim();
                                  if (v.isEmpty)
                                    return 'Base URL tidak boleh kosong';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Status indicator
                              if (_lastTestOk != null && _testResult != null)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: _lastTestOk == true
                                        ? Colors.green.withOpacity(0.1)
                                        : Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _lastTestOk == true
                                          ? Colors.green
                                          : Colors.red,
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            _lastTestOk == true
                                                ? Icons.check_circle_outline
                                                : Icons.error_outline,
                                            size: 20,
                                            color: _lastTestOk == true
                                                ? Colors.green[700]!
                                                : Colors.red[700]!,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _lastTestOk == true
                                                  ? 'Koneksi API berhasil'
                                                  : 'Gagal terhubung ke API',
                                              style: TextStyle(
                                                color: _lastTestOk == true
                                                    ? Colors.green[700]!
                                                    : Colors.red[700]!,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      _buildTestDetail('URL:',
                                          _testResult!['url'] ?? 'N/A', isDark),
                                      _buildTestDetail(
                                          'Status Code:',
                                          '${_testResult!['statusCode'] ?? 'N/A'}',
                                          isDark),
                                      _buildTestDetail(
                                          'Response Time:',
                                          '${_testResult!['responseTime'] ?? 0}ms',
                                          isDark),
                                    ],
                                  ),
                                ),
                              if (_lastTestOk != null)
                                const SizedBox(height: 16),

                              // Action buttons
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton.icon(
                                      onPressed:
                                          _testing ? null : _testApiConnection,
                                      icon: _testing
                                          ? const SizedBox(
                                              height: 16,
                                              width: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(Icons.wifi_tethering),
                                      label: Text(_testing
                                          ? 'Testing...'
                                          : 'Test Connection'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _testing
                                            ? Colors.grey[400]
                                            : (isDark
                                                ? Colors.blue[700]
                                                : Colors.blue[800]),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton.icon(
                                      onPressed:
                                          _isDirty ? _saveSettings : null,
                                      icon: Icon(
                                          _isDirty ? Icons.save : Icons.check),
                                      label: Text(_isDirty ? 'Save' : 'Saved'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _isDirty
                                            ? Colors.green
                                            : Colors.grey[400],
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // GenieACS Configuration Section
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Form(
                          key: _genieacsFormKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.cloud,
                                    color:
                                        Colors.blue, // Always blue as requested
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Pengaturan GenieACS',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _genieacsUrlController,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Server URL',
                                  labelStyle: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                  hintText: 'http://x.x.x.x:7557',
                                  hintStyle: TextStyle(
                                    color: isDark
                                        ? Colors.grey.shade600
                                        : Colors.grey.shade400,
                                  ),
                                  prefixIcon: const Icon(Icons.cloud),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                keyboardType: TextInputType.url,
                                validator: (value) {
                                  final v = (value ?? '').trim();
                                  if (v.isEmpty)
                                    return 'Server URL tidak boleh kosong';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _genieacsUsernameController,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Username',
                                  labelStyle: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                  prefixIcon: const Icon(Icons.person),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _genieacsPasswordController,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  labelStyle: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                  prefixIcon: const Icon(Icons.lock),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                obscureText: true,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton.icon(
                                      onPressed: _genieacsTesting
                                          ? null
                                          : _testGenieACSConnection,
                                      icon: _genieacsTesting
                                          ? const SizedBox(
                                              height: 16,
                                              width: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(Icons.wifi_tethering),
                                      label: Text(_genieacsTesting
                                          ? 'Testing...'
                                          : 'Test Connection'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _genieacsTesting
                                            ? Colors.grey[400]
                                            : (isDark
                                                ? Colors.blue[700]
                                                : Colors.blue[800]),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton.icon(
                                      onPressed: _genieacsIsDirty
                                          ? _saveGenieACSSettings
                                          : null,
                                      icon: Icon(_genieacsIsDirty
                                          ? Icons.save
                                          : Icons.check),
                                      label: Text(
                                          _genieacsIsDirty ? 'Save' : 'Saved'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _genieacsIsDirty
                                            ? Colors.green
                                            : Colors.grey[400],
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

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
                            Row(
                              children: [
                                const Icon(
                                  Icons.palette,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'App Settings',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
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
                                  color:
                                      isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                              value: isDark,
                              onChanged: (bool value) {
                                themeProvider.toggleTheme();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
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
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Cek ketersediaan update aplikasi terbaru',
                              style: TextStyle(
                                fontSize: 14,
                                color:
                                    isDark ? Colors.white70 : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildUpdateCheckButton(isDark),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
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
