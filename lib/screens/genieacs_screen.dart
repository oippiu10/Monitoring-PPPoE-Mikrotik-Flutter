import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/gradient_container.dart';
import 'package:provider/provider.dart';

import '../services/genieacs_service.dart';
import '../services/genieacs_config_service.dart';
import '../main.dart';

class GenieACSScreen extends StatefulWidget {
  const GenieACSScreen({Key? key}) : super(key: key);

  @override
  State<GenieACSScreen> createState() => _GenieACSScreenState();
}

class _GenieACSScreenState extends State<GenieACSScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = false;
  bool _isRefreshing = false;
  GenieACSService? _service;
  List<Map<String, dynamic>> _devices = [];
  Timer? _searchDebounce;
  Timer? _updateTimer;

  bool _isSelectionMode = false;
  final Set<String> _selectedDeviceIds = {};

  // Filter and sort options
  String _sortOption = 'Last Inform (Newest)';
  String _statusFilter = 'Semua';
  String _rxFilter = 'Semua';
  final List<String> _sortOptions = [
    'Last Inform (Newest)',
    'Last Inform (Oldest)',
    'PPPoE Username (A-Z)',
    'PPPoE Username (Z-A)',
    'Model (A-Z)',
    'Model (Z-A)',
  ];
  final List<String> _statusOptions = ['Semua', 'Online', 'Idle', 'Offline'];
  final List<String> _rxOptions = [
    'Semua',
    'RX Bagus',
    'RX Lumayan',
    'RX Kritis'
  ];

  @override
  void initState() {
    super.initState();
    _loadCachedData();
    _refreshDataInBackground();

    // Timer untuk update "Baru saja" per detik
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        // Force rebuild untuk update "Last Inform" time
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    _updateTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCachedData() async {
    try {
      final devices = await GenieACSConfigService.getCachedDeviceData();
      if (mounted) {
        setState(() {
          _devices = devices;
        });
      }
    } catch (e) {
      print('[GenieACS] Error loading cached data: $e');
    }
  }

  Future<void> _refreshDataInBackground() async {
    // Check if configured
    final isConfigured = await GenieACSConfigService.isConfigured();
    if (!isConfigured) return;

    setState(() => _isLoading = true);

    try {
      final url = await GenieACSConfigService.getGenieACSUrl();
      final username = await GenieACSConfigService.getGenieACSUsername();
      final password = await GenieACSConfigService.getGenieACSPassword();

      if (url != null && username != null && password != null) {
        _service = GenieACSService(
          baseUrl: url,
          username: username,
          password: password,
        );

        print('[GenieACS] Refreshing data...');
        final devices = await _service!.getDevices();

        // Cache the data
        await GenieACSConfigService.cacheDeviceData(devices);

        if (mounted) {
          setState(() {
            _devices = devices;
            _isLoading = false;
          });
        }
        print('[GenieACS] Data refreshed. ${devices.length} devices loaded.');
      }
    } catch (e) {
      print('[GenieACS] Refresh error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _summonSelectedDevices() async {
    if (_selectedDeviceIds.isEmpty) return;

    final targetIds = _selectedDeviceIds.toList();
    setState(() {
      _isSelectionMode = false;
      _selectedDeviceIds.clear();
    });

    int successCount = 0;
    int progress = 0;
    StateSetter? dialogSetState;
    bool isDialogClosed = false;

    // Background runner
    Future<void> runBatch() async {
      for (var id in targetIds) {
        if (isDialogClosed) break; // safeguard
        try {
          bool result = await _service!.refreshConnection(id);
          if (result) successCount++;
        } catch (e) {
          // ignore
        }

        progress++;
        // Update dialog state if still active
        if (dialogSetState != null && !isDialogClosed && mounted) {
          dialogSetState!(() {});
        }

        await Future.delayed(const Duration(milliseconds: 300));
      }

      isDialogClosed = true;
      if (mounted) {
        Navigator.of(context).pop();
      }
    }

    // FIRE the background function immediately
    runBatch();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            dialogSetState = setDialogState;

            return WillPopScope(
              onWillPop: () async => false,
              child: AlertDialog(
                title: const Text('Summon Devices'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                        'Memproses $progress dari ${targetIds.length} device...'),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    isDialogClosed = true; // force boundary just in case

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Summon selesai. $successCount berhasil dari ${targetIds.length}.'),
          backgroundColor:
              successCount == targetIds.length ? Colors.green : Colors.orange,
        ),
      );
      _manualRefresh();
    }
  }

  Future<void> _manualRefresh() async {
    setState(() => _isRefreshing = true);
    await _refreshDataInBackground();
    if (mounted) {
      setState(() => _isRefreshing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data diperbarui'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  List<Map<String, dynamic>> _getFilteredAndSortedDevices() {
    final lowercaseQuery = _searchController.text.toLowerCase();

    // First filter by search query
    List<Map<String, dynamic>> filtered = _devices.where((device) {
      if (lowercaseQuery.isEmpty) return true;

      final pppoeUsername =
          DeviceInfoExtractor.getPPPoEUsername(device).toLowerCase();
      final deviceId = DeviceInfoExtractor.getDeviceId(device).toLowerCase();
      final pppoeIP = DeviceInfoExtractor.getPPPoEIP(device).toLowerCase();
      final serialNumber =
          DeviceInfoExtractor.getSerialNumber(device).toLowerCase();

      return pppoeUsername.contains(lowercaseQuery) ||
          pppoeIP.contains(lowercaseQuery) ||
          deviceId.contains(lowercaseQuery) ||
          serialNumber.contains(lowercaseQuery);
    }).toList();

    // Then filter by status
    if (_statusFilter != 'Semua') {
      filtered = filtered.where((device) {
        final status = DeviceInfoExtractor.getConnectionStatus(device);
        return status.toLowerCase() == _statusFilter.toLowerCase();
      }).toList();
    }

    // Then filter by RX Power
    if (_rxFilter != 'Semua') {
      filtered = filtered.where((device) {
        final rxPowerStr = DeviceInfoExtractor.getRXPower(device);
        if (rxPowerStr == '-') return false;

        try {
          final rxPower = double.parse(rxPowerStr);
          switch (_rxFilter) {
            case 'RX Bagus':
              return rxPower >= -20;
            case 'RX Lumayan':
              return rxPower >= -25 && rxPower < -20;
            case 'RX Kritis':
              return rxPower >= -30 && rxPower < -25;
            default:
              return true;
          }
        } catch (e) {
          return false;
        }
      }).toList();
    }

    // Then sort
    filtered.sort((a, b) {
      switch (_sortOption) {
        case 'Last Inform (Newest)':
          final aDate =
              DateTime.tryParse(a['_lastInform'] ?? '') ?? DateTime(1970);
          final bDate =
              DateTime.tryParse(b['_lastInform'] ?? '') ?? DateTime(1970);
          return bDate.compareTo(aDate);
        case 'Last Inform (Oldest)':
          final aDate =
              DateTime.tryParse(a['_lastInform'] ?? '') ?? DateTime(1970);
          final bDate =
              DateTime.tryParse(b['_lastInform'] ?? '') ?? DateTime(1970);
          return aDate.compareTo(bDate);
        case 'PPPoE Username (A-Z)':
          return DeviceInfoExtractor.getPPPoEUsername(a)
              .compareTo(DeviceInfoExtractor.getPPPoEUsername(b));
        case 'PPPoE Username (Z-A)':
          return DeviceInfoExtractor.getPPPoEUsername(b)
              .compareTo(DeviceInfoExtractor.getPPPoEUsername(a));
        case 'Model (A-Z)':
          return DeviceInfoExtractor.getModel(a)
              .compareTo(DeviceInfoExtractor.getModel(b));
        case 'Model (Z-A)':
          return DeviceInfoExtractor.getModel(b)
              .compareTo(DeviceInfoExtractor.getModel(a));
        default:
          return 0;
      }
    });

    return filtered;
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
                labelText: 'Urutkan',
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
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              dropdownColor: isDark ? const Color(0xFF2D2D2D) : Colors.white,
              value: _rxFilter,
              items: _rxOptions
                  .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(
                        e,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      )))
                  .toList(),
              onChanged: (v) => setState(() => _rxFilter = v!),
              decoration: InputDecoration(
                labelText: 'Filter RX Power',
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
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isDark ? Colors.blue.shade700 : Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Selesai'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog(Map<String, dynamic> device) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Ekstrak profil WLAN via helper untuk mencakup semua interface
    final List<Map<String, String>> ssidList =
        DeviceInfoExtractor.getSSIDList(device);
    Map<int, String> availableSsids = {};
    Map<int, bool> availableStatuses = {};

    for (var wlan in ssidList) {
      int idx = int.tryParse(wlan['index'] ?? '1') ?? 1;
      availableSsids[idx] = wlan['ssid'] ?? '-';
      availableStatuses[idx] = wlan['enable'] == 'TRUE';
    }

    // Berikan default jika tidak ada yang ditemukan
    if (availableSsids.isEmpty) {
      availableSsids[1] = '-';
      availableStatuses[1] = true;
    }

    int selectedWlanIndex = availableSsids.keys.first;
    final ssidController = TextEditingController(
        text: availableSsids[selectedWlanIndex] != '-'
            ? availableSsids[selectedWlanIndex]
            : '');
    final passwordController = TextEditingController();

    bool getWifiStatus(int index) {
      return availableStatuses[index] ?? false;
    }

    bool wifiEnabled = getWifiStatus(selectedWlanIndex);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isLoading = false;

        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.wifi, color: Colors.blue),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Konfigurasi WiFi',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Device: ${DeviceInfoExtractor.getPPPoEUsername(device)}',
                    style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  // Dropdown Selector
                  if (availableSsids.length > 1) ...[
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      value: selectedWlanIndex,
                      decoration: InputDecoration(
                        labelText: 'Pilih Profil WiFi',
                        prefixIcon: const Icon(Icons.router),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade100,
                      ),
                      items: availableSsids.entries
                          .map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text('WLAN ${e.key}: ${e.value}',
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedWlanIndex = val;
                            ssidController.text = availableSsids[val] != '-'
                                ? availableSsids[val]!
                                : '';
                            wifiEnabled = getWifiStatus(val);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: ssidController,
                    decoration: InputDecoration(
                      labelText: 'Nama WiFi (SSID)',
                      prefixIcon: const Icon(Icons.wifi_tethering),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor:
                          isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password Baru',
                      hintText: 'Biarkan kosong jika tidak diganti',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor:
                          isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable SSID'),
                    subtitle: Text(wifiEnabled ? 'Aktif' : 'Mati',
                        style: const TextStyle(fontSize: 12)),
                    value: wifiEnabled,
                    activeColor: Colors.blue,
                    onChanged: (val) {
                      setDialogState(() {
                        wifiEnabled = val;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              if (!isLoading)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Tutup',
                      style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54)),
                ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (ssidController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('SSID tidak boleh kosong',
                                      style: TextStyle(color: Colors.white)),
                                  backgroundColor: Colors.red));
                          return;
                        }
                        if (passwordController.text.trim().isNotEmpty &&
                            passwordController.text.trim().length < 8) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Password minimal 8 karakter',
                                      style: TextStyle(color: Colors.white)),
                                  backgroundColor: Colors.red));
                          return;
                        }

                        setDialogState(() {
                          isLoading = true;
                        });
                        final deviceId =
                            DeviceInfoExtractor.getDeviceId(device);

                        bool success = await _service!.changeSSIDAndPassword(
                          deviceId,
                          selectedWlanIndex,
                          ssidController.text.trim(),
                          passwordController.text.trim().isNotEmpty
                              ? passwordController.text.trim()
                              : '',
                          enable: wifiEnabled,
                        );

                        if (mounted) {
                          setDialogState(() {
                            isLoading = false;
                          });
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success
                                  ? 'WiFi berhasil diubah!'
                                  : 'Gagal mengirim perintah!'),
                              backgroundColor:
                                  success ? Colors.green : Colors.red,
                            ),
                          );
                          if (success) _manualRefresh();
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Simpan',
                        style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        });
      },
    );
  }

  void _showDeviceDetails(Map<String, dynamic> device) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child:
                        const Icon(Icons.router, size: 28, color: Colors.blue),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Device Details',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.person,
                                size: 14,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                DeviceInfoExtractor.getPPPoEUsername(device),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.grey.shade300
                                      : Colors.grey.shade700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getStatusColorForValue(
                                        DeviceInfoExtractor.getConnectionStatus(
                                            device),
                                        isDark)
                                    .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                DeviceInfoExtractor.getConnectionStatus(device),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _getStatusColorForValue(
                                      DeviceInfoExtractor.getConnectionStatus(
                                          device),
                                      isDark),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color:
                          isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      color: isDark ? Colors.white70 : Colors.black54,
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Tutup',
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Virtual Parameters section (moved to top)
                    _buildDetailSection(
                      'Virtual Parameters',
                      _buildGridRows(
                          DeviceInfoExtractor.getVirtualParameters(device)
                              .entries
                              .toList()
                              .asMap()
                              .entries
                              .map((entry) {
                        final indexNumber = entry.key + 1;
                        final displayName =
                            _formatVirtualParameterName(entry.value.key);
                        return _buildDetailRow(
                            '$indexNumber. $displayName', entry.value.value);
                      }).toList()),
                      isDark,
                    ),
                    const SizedBox(height: 12),
                    _buildDetailSection(
                      'Device Information',
                      _buildGridRows([
                        _buildDetailRow('Device ID',
                            DeviceInfoExtractor.getDeviceId(device)),
                        _buildDetailRow('Serial Number',
                            DeviceInfoExtractor.getSerialNumber(device)),
                        _buildDetailRow('Manufacturer',
                            DeviceInfoExtractor.getManufacturer(device)),
                        _buildDetailRow(
                            'Model', DeviceInfoExtractor.getModel(device)),
                        _buildDetailRow('Product Class',
                            DeviceInfoExtractor.getProductClass(device)),
                        _buildDetailRow(
                            'OUI', DeviceInfoExtractor.getOUI(device)),
                      ]),
                      isDark,
                    ),
                    const SizedBox(height: 12),
                    _buildDetailSection(
                      'Network',
                      _buildGridRows([
                        _buildDetailRow('Status',
                            DeviceInfoExtractor.getConnectionStatus(device)),
                        _buildDetailRow('Last Inform',
                            DeviceInfoExtractor.getLastInform(device)),
                        _buildDetailRow('IP Address',
                            DeviceInfoExtractor.getIPAddress(device) ?? '-'),
                        _buildDetailRow('PPPoE Username',
                            DeviceInfoExtractor.getPPPoEUsername(device),
                            onTap: () {
                          Navigator.pop(context); // close details modal first
                          _showEditPPPoEDialog(device);
                        }, showEditIcon: true),
                        _buildDetailRow('PPPoE Password', '*** (Tap Edit)',
                            onTap: () {
                          Navigator.pop(context); // close details modal first
                          _showEditPPPoEDialog(device);
                        }, showEditIcon: true),
                        _buildDetailRow(
                            'PPPoE IP', DeviceInfoExtractor.getPPPoEIP(device)),
                        _buildDetailRow('PPPoE MAC',
                            DeviceInfoExtractor.getPPPoEMac(device)),
                        _buildDetailRow(
                            'SSID', DeviceInfoExtractor.getSSID(device)),
                        _buildDetailRow('MAC Address',
                            DeviceInfoExtractor.getMACAddress(device)),
                      ]),
                      isDark,
                    ),
                    const SizedBox(height: 12),
                    _buildDetailSection(
                      'Status & Performance',
                      _buildGridRows([
                        _buildDetailRow('RX Power',
                            DeviceInfoExtractor.getRXPowerWithStatus(device)),
                        _buildDetailRow(
                            'Temperature',
                            DeviceInfoExtractor.getTemperatureWithStatus(
                                device)),
                        _buildDetailRow('Active Devices',
                            DeviceInfoExtractor.getActiveWithStatus(device)),
                        _buildDetailRow('Device Uptime',
                            DeviceInfoExtractor.getDeviceUptime(device)),
                        _buildDetailRow('PPPoE Uptime',
                            DeviceInfoExtractor.getPPPoEUptime(device)),
                        _buildDetailRow(
                            'PON Mode', DeviceInfoExtractor.getPONMode(device)),
                      ]),
                      isDark,
                    ),
                    const SizedBox(height: 12),
                    _buildDetailSection(
                      'Firmware',
                      _buildGridRows([
                        _buildDetailRow(
                            'Firmware',
                            DeviceInfoExtractor.getFirmwareVersion(device) ??
                                '-'),
                        _buildDetailRow(
                            'Hardware',
                            DeviceInfoExtractor.getHardwareVersion(device) ??
                                '-'),
                      ]),
                      isDark,
                    ),
                    const SizedBox(height: 12),
                    _buildDetailSection(
                      'Timing',
                      _buildGridRows([
                        _buildDetailRow('Registered',
                            DeviceInfoExtractor.getRegisteredTime(device)),
                        _buildDetailRow('Last Communication',
                            DeviceInfoExtractor.getLastCommunication(device)),
                      ]),
                      isDark,
                    ),
                    const SizedBox(height: 12),
                    if (DeviceInfoExtractor.getTags(device).isNotEmpty)
                      _buildDetailSection(
                        'Tags',
                        [
                          Wrap(
                            spacing: 8,
                            children: DeviceInfoExtractor.getTags(device)
                                .map((tag) => Chip(
                                      label: Text(tag),
                                      backgroundColor: Colors.blue.shade50,
                                    ))
                                .toList(),
                          ),
                        ],
                        isDark,
                      ),

                    const SizedBox(height: 12),
                    _buildTableSection(
                      'WLAN Configuration (${DeviceInfoExtractor.getSSIDList(device).length})',
                      ['No.', 'Enable', 'SSID', 'Security', 'Password'],
                      DeviceInfoExtractor.getSSIDList(device)
                          .map((w) => [
                                w['index']!,
                                w['enable']!,
                                w['ssid']!,
                                w['security']!,
                                w['password']!
                              ])
                          .toList(),
                      isDark,
                      inactiveColumnIndex: 1,
                      inactiveValue: 'FALSE',
                      headerTrailing: IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        color: Colors.blue,
                        tooltip: 'Atur WiFi',
                        onPressed: () {
                          Navigator.pop(context);
                          _showChangePasswordDialog(device);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildTableSection(
                      'LAN Hosts (${DeviceInfoExtractor.getLanHosts(device).length})',
                      [
                        'No.',
                        'Hostname',
                        'IP Address',
                        'MAC Address',
                        'Type',
                        'Active'
                      ],
                      DeviceInfoExtractor.getLanHosts(device)
                          .toList()
                          .asMap()
                          .entries
                          .map((e) => [
                                (e.key + 1).toString(),
                                e.value['hostname']!,
                                e.value['ip']!,
                                e.value['mac']!,
                                e.value['type']!,
                                e.value['active']!
                              ])
                          .toList(),
                      isDark,
                      inactiveColumnIndex: 5,
                      inactiveValue: 'No',
                    ),
                    const SizedBox(height: 12),
                    _buildTableSection(
                      'WAN Profiles (${DeviceInfoExtractor.getWanProfiles(device).length})',
                      ['No.', 'Type', 'VLAN', 'IP Address', 'NAT', 'Path'],
                      DeviceInfoExtractor.getWanProfiles(device)
                          .toList()
                          .asMap()
                          .entries
                          .map((e) => [
                                (e.key + 1).toString(),
                                e.value['type']!,
                                e.value['vlan']!,
                                e.value['ip']!,
                                e.value['nat']!,
                                e.value['path']!.split('.').last
                              ])
                          .toList(),
                      isDark,
                    ),
                    const SizedBox(height: 24),

                    // Quick Actions Row
                    const Divider(),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.api, size: 22),
                        label: const Text(
                          'Summon Perangkat (Refresh Data)',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5),
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                            content: Text(
                                'Mengirim perintah summon ke perangkat...',
                                style: TextStyle(color: Colors.white)),
                            backgroundColor: Colors.blue,
                          ));
                          if (_service != null) {
                            bool success = await _service!.refreshConnection(
                                DeviceInfoExtractor.getDeviceId(device));
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(
                                  success
                                      ? 'Summon berhasil ditarik, merefresh tabel...'
                                      : 'Gagal melakukan summon',
                                  style: const TextStyle(color: Colors.white)),
                              backgroundColor:
                                  success ? Colors.green : Colors.red,
                            ));
                            if (success) _manualRefresh();
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableSection(
      String title, List<String> headers, List<List<String>> rows, bool isDark,
      {Widget? headerTrailing,
      int? inactiveColumnIndex,
      String? inactiveValue}) {
    if (rows.isEmpty) return const SizedBox.shrink();

    bool isExpanded = false;
    final bool showToggle = rows.length > 2;

    return StatefulBuilder(
      builder: (context, setState) {
        final List<List<String>> visibleRows =
            (showToggle && !isExpanded) ? rows.take(2).toList() : rows;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left:
                      BorderSide(color: Colors.blue.withOpacity(0.8), width: 3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: showToggle
                        ? () => setState(() => isExpanded = !isExpanded)
                        : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.table_chart,
                                color: Colors.blue, size: 18),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          if (showToggle)
                            Padding(
                              padding: const EdgeInsets.only(right: 4.0),
                              child: Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: isDark ? Colors.white54 : Colors.black54,
                                size: 20,
                              ),
                            ),
                          if (headerTrailing != null) headerTrailing,
                        ],
                      ),
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 36,
                      dataRowMinHeight: 36,
                      dataRowMaxHeight: 36,
                      columnSpacing: 16,
                      horizontalMargin: 12,
                      headingTextStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontSize: 13),
                      dataTextStyle: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontSize: 12),
                      columns: headers
                          .map((h) => DataColumn(label: Text(h)))
                          .toList(),
                      rows: visibleRows.map((row) {
                        bool isInactive = false;
                        if (inactiveColumnIndex != null &&
                            inactiveValue != null &&
                            inactiveColumnIndex < row.length) {
                          isInactive =
                              row[inactiveColumnIndex] == inactiveValue;
                        }
                        return DataRow(
                          cells: row
                              .map((cell) => DataCell(Text(
                                    cell,
                                    style: TextStyle(
                                      color: isInactive
                                          ? (isDark
                                              ? Colors.grey.shade600
                                              : Colors.grey.shade400)
                                          : (isDark
                                              ? Colors.white70
                                              : Colors.black87),
                                      fontStyle: isInactive
                                          ? FontStyle.italic
                                          : FontStyle.normal,
                                    ),
                                  )))
                              .toList(),
                        );
                      }).toList(),
                    ),
                  ),
                  if (showToggle)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
                      child: Center(
                        child: TextButton.icon(
                          onPressed: () =>
                              setState(() => isExpanded = !isExpanded),
                          icon: Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                            size: 16,
                          ),
                          label: Text(
                            isExpanded
                                ? 'Lebih Sedikit'
                                : 'Lihat Selengkapnya (${rows.length - 2} baris)',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.blue,
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children, bool isDark) {
    // Determine section color based on title
    Color sectionColor;
    IconData sectionIcon;
    switch (title) {
      case 'Virtual Parameters':
        sectionColor = Colors.purple;
        sectionIcon = Icons.tune;
        break;
      case 'Device Information':
        sectionColor = Colors.blue;
        sectionIcon = Icons.info;
        break;
      case 'Network':
        sectionColor = Colors.cyan;
        sectionIcon = Icons.network_check;
        break;
      case 'Status & Performance':
        sectionColor = Colors.orange;
        sectionIcon = Icons.speed;
        break;
      case 'Firmware':
        sectionColor = Colors.teal;
        sectionIcon = Icons.memory;
        break;
      case 'Timing':
        sectionColor = Colors.indigo;
        sectionIcon = Icons.access_time;
        break;
      case 'Tags':
        sectionColor = Colors.green;
        sectionIcon = Icons.label;
        break;
      default:
        sectionColor = Colors.grey;
        sectionIcon = Icons.category;
    }

    bool isExpanded = false;
    final bool showToggle = children.length > 2;

    return StatefulBuilder(
      builder: (context, setState) {
        final List<Widget> visibleChildren =
            (showToggle && !isExpanded) ? children.take(2).toList() : children;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                      color: sectionColor.withOpacity(0.8), width: 3),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: showToggle
                          ? () => setState(() => isExpanded = !isExpanded)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: EdgeInsets.only(bottom: showToggle ? 8.0 : 0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: sectionColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(sectionIcon,
                                  color: sectionColor, size: 18),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            if (showToggle)
                              Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: isDark ? Colors.white54 : Colors.black54,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...visibleChildren,
                    if (showToggle)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Center(
                          child: TextButton.icon(
                            onPressed: () =>
                                setState(() => isExpanded = !isExpanded),
                            icon: Icon(
                              isExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 16,
                            ),
                            label: Text(
                              isExpanded
                                  ? 'Lebih Sedikit'
                                  : 'Lihat Selengkapnya (${children.length - 2})',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: sectionColor,
                              minimumSize: const Size(0, 36),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
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
      },
    );
  }

  List<Widget> _buildGridRows(List<Widget> items) {
    List<Widget> rows = [];
    for (int i = 0; i < items.length; i += 2) {
      if (i + 1 < items.length) {
        rows.add(IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: items[i]),
              const SizedBox(width: 8),
              Expanded(child: items[i + 1]),
            ],
          ),
        ));
      } else {
        rows.add(IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: items[i]),
              const SizedBox(width: 8),
              Expanded(child: const SizedBox()), // Empty slot
            ],
          ),
        ));
      }
    }
    return rows;
  }

  Widget _buildDetailRow(String label, String value,
      {VoidCallback? onTap, bool showEditIcon = false}) {
    final isDark =
        mounted ? Theme.of(context).brightness == Brightness.dark : true;

    // Get icon for label
    IconData icon;
    Color iconColor;
    switch (label) {
      case 'Device ID':
        icon = Icons.qr_code;
        iconColor = Colors.blue;
        break;
      case 'Serial Number':
        icon = Icons.confirmation_number;
        iconColor = Colors.orange;
        break;
      case 'Manufacturer':
        icon = Icons.business;
        iconColor = Colors.purple;
        break;
      case 'Model':
        icon = Icons.devices;
        iconColor = Colors.indigo;
        break;
      case 'Product Class':
        icon = Icons.inventory_2;
        iconColor = Colors.brown;
        break;
      case 'OUI':
        icon = Icons.fingerprint;
        iconColor = Colors.pink;
        break;
      case 'Status':
        icon = Icons.power_settings_new;
        iconColor = _getStatusColorForValue(value, isDark);
        break;
      case 'Last Inform':
        icon = Icons.access_time;
        iconColor = Colors.cyan;
        break;
      case 'IP Address':
        icon = Icons.language;
        iconColor = Colors.blue;
        break;
      case 'PPPoE IP':
        icon = Icons.cloud;
        iconColor = Colors.blue.shade700;
        break;
      case 'PPPoE MAC':
        icon = Icons.router;
        iconColor = Colors.green.shade700;
        break;
      case 'SSID':
        icon = Icons.wifi;
        iconColor = Colors.purple;
        break;
      case 'MAC Address':
        icon = Icons.network_cell;
        iconColor = Colors.teal;
        break;
      case 'RX Power':
        icon = Icons.signal_cellular_alt;
        iconColor = _getRXPowerColor(value);
        break;
      case 'Temperature':
        icon = Icons.thermostat;
        iconColor = _getTemperatureColor(value);
        break;
      case 'Active Devices':
        icon = Icons.people;
        iconColor = Colors.green;
        break;
      case 'Device Uptime':
        icon = Icons.timer;
        iconColor = Colors.indigo;
        break;
      case 'PPPoE Uptime':
        icon = Icons.history;
        iconColor = Colors.deepPurple;
        break;
      case 'PON Mode':
        icon = Icons.cable;
        iconColor = Colors.amber;
        break;
      case 'Firmware':
        icon = Icons.update;
        iconColor = Colors.teal;
        break;
      case 'Hardware':
        icon = Icons.build;
        iconColor = Colors.grey;
        break;
      case 'Registered':
        icon = Icons.calendar_today;
        iconColor = Colors.orange;
        break;
      case 'Last Communication':
        icon = Icons.chat_bubble_outline;
        iconColor = Colors.cyan;
        break;
      default:
        if (label.contains(RegExp(r'^\d+\.'))) {
          icon = Icons.tune;
          // Assign random but consistent color palette based on label hash
          final colors = [
            Colors.blue,
            Colors.purple,
            Colors.orange,
            Colors.teal,
            Colors.cyan,
            Colors.pink,
            Colors.deepOrange,
            Colors.indigo
          ];
          iconColor =
              colors[label.codeUnits.fold(0, (p, c) => p + c) % colors.length];
        } else {
          icon = Icons.label_outline;
          iconColor = Colors.grey;
        }
    }

    // Determine if value needs badge decoration
    final hasStatus = value.toLowerCase().contains('bagus') ||
        value.toLowerCase().contains('lumayan') ||
        value.toLowerCase().contains('kritis') ||
        value.toLowerCase().contains('online') ||
        value.toLowerCase().contains('offline') ||
        value.toLowerCase().contains('idle') ||
        value.toLowerCase().contains('anget') ||
        value.toLowerCase().contains('adem') ||
        value.toLowerCase().contains('panas') ||
        value.toLowerCase().contains('normal') ||
        value.toLowerCase().contains('medium') ||
        value.toLowerCase().contains('over') ||
        value.toLowerCase().contains('empty');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color:
            isDark ? iconColor.withOpacity(0.12) : iconColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color:
              isDark ? iconColor.withOpacity(0.3) : iconColor.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 14, color: iconColor),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: hasStatus && value != '-'
                        ? Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getStatusColorForValue(value, isDark)
                                    .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _getStatusColorForValue(value, isDark)
                                      .withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                value,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _getStatusColorForValue(value, isDark),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )
                        : Text(
                            value,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                  if (showEditIcon)
                    const Padding(
                      padding: EdgeInsets.only(left: 4.0),
                      child: Icon(Icons.edit, size: 14, color: Colors.blue),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditPPPoEDialog(Map<String, dynamic> device) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String currentUsername = DeviceInfoExtractor.getPPPoEUsername(device);
    if (currentUsername == '-' || currentUsername == 'Unknown')
      currentUsername = '';

    final usernameController = TextEditingController(text: currentUsername);
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isLoading = false;

        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.public, color: Colors.blue),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Ubah Konfigurasi PPPoE',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Device ID: ${DeviceInfoExtractor.getDeviceId(device)}',
                    style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: usernameController,
                    decoration: InputDecoration(
                      labelText: 'PPPoE Username Baru',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor:
                          isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'PPPoE Password Baru',
                      hintText: 'Biarkan kosong untuk test API / tanpa passwd',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor:
                          isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (!isLoading)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Batal',
                      style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54)),
                ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (usernameController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Username tidak boleh kosong',
                                      style: TextStyle(color: Colors.white)),
                                  backgroundColor: Colors.red));
                          return;
                        }

                        setDialogState(() {
                          isLoading = true;
                        });
                        final deviceId =
                            DeviceInfoExtractor.getDeviceId(device);

                        bool success = await _service!.changePPPoECredentials(
                          deviceId,
                          'InternetGatewayDevice.WANDevice.1.WANConnectionDevice.1.WANPPPConnection.1',
                          usernameController.text.trim(),
                          passwordController.text.trim(),
                        );

                        if (mounted) {
                          setDialogState(() {
                            isLoading = false;
                          });
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success
                                  ? 'PPPoE berhasil diupdate!'
                                  : 'Gagal mengirim perintah!'),
                              backgroundColor:
                                  success ? Colors.green : Colors.red,
                            ),
                          );
                          if (success) _manualRefresh();
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Simpan',
                        style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        });
      },
    );
  }

  Color _getStatusColorForValue(String value, bool isDark) {
    final lowerValue = value.toLowerCase();
    if (lowerValue.contains('bagus') ||
        lowerValue.contains('normal') ||
        lowerValue.contains('online')) {
      return Colors.green;
    } else if (lowerValue.contains('lumayan') ||
        lowerValue.contains('medium')) {
      return Colors.orange;
    } else if (lowerValue.contains('kritis') ||
        lowerValue.contains('offline')) {
      return Colors.red;
    } else if (lowerValue.contains('adem')) {
      return Colors.blue;
    } else if (lowerValue.contains('anget')) {
      return Colors.orange;
    } else if (lowerValue.contains('panas')) {
      return Colors.red;
    } else if (lowerValue.contains('over')) {
      return Colors.red;
    } else if (lowerValue.contains('empty')) {
      return Colors.grey;
    }
    return Colors.grey;
  }

  Color _getRXPowerColor(String value) {
    if (value.toLowerCase().contains('bagus')) return Colors.green;
    if (value.toLowerCase().contains('lumayan')) return Colors.orange;
    if (value.toLowerCase().contains('kritis')) return Colors.red;
    return Colors.grey;
  }

  Color _getTemperatureColor(String value) {
    if (value.toLowerCase().contains('adem')) return Colors.blue;
    if (value.toLowerCase().contains('anget')) return Colors.orange;
    if (value.toLowerCase().contains('panas')) return Colors.red;
    return Colors.grey;
  }

  String _formatVirtualParameterName(String key) {
    // Map technical names to user-friendly names
    final nameMap = {
      'ipTR069': 'IP TR-069',
      'ponMac': 'PON MAC',
      'rxPower': 'RX Power',
      'wlanPassword': 'WLAN Password',
      'activedevices': 'Active Devices',
      'getSerialNumber': 'Serial Number',
      'getdeviceuptime': 'Device Uptime',
      'getponmode': 'PON Mode',
      'getpppuptime': 'PPPoE Uptime',
      'gettemp': 'Temperature',
      'pppoeIP': 'PPPoE IP',
      'pppoeMac': 'PPPoE MAC',
      'pppoePassword': 'PPPoE Password',
      'pppoeUsername': 'PPPoE Username',
      'superPassword': 'Super Password',
      'getIPTR069': 'IP TR-069',
      'getPonMac': 'PON MAC',
      'getTemperature': 'Temperature',
      'getDeviceUptime': 'Device Uptime',
      'getPPPoEUptime': 'PPPoE Uptime',
      'getPONMode': 'PON Mode',
      'getPPPoEMac': 'PPPoE MAC',
      'getActiveDevices': 'Active Devices',
      'getRXPower': 'RX Power',
      'getPPPoEIP': 'PPPoE IP',
      'getPPPoEUsername': 'PPPoE Username',
    };

    // Check if direct mapping exists
    if (nameMap.containsKey(key)) {
      return nameMap[key]!;
    }

    // Otherwise, format by removing 'get' prefix and converting camelCase to Title Case
    String formatted = key.replaceAll(RegExp(r'^get'), '');
    formatted = formatted.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(1)}',
    );
    formatted = formatted.trim();

    // Convert first letter to uppercase
    if (formatted.isNotEmpty) {
      formatted = formatted[0].toUpperCase() + formatted.substring(1);
    }

    return formatted.isEmpty ? key : formatted;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final filteredDevices = _getFilteredAndSortedDevices();

    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _isSelectionMode
            ? AppBar(
                backgroundColor:
                    isDark ? const Color(0xFF1E1E1E) : Colors.white,
                elevation: 4,
                leading: IconButton(
                  icon: Icon(Icons.close,
                      color: isDark ? Colors.white : Colors.black87),
                  onPressed: () {
                    setState(() {
                      _isSelectionMode = false;
                      _selectedDeviceIds.clear();
                    });
                  },
                ),
                title: Text(
                  '${_selectedDeviceIds.length} Terpilih',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        final currentList = _getFilteredAndSortedDevices();
                        _selectedDeviceIds.clear();
                        _selectedDeviceIds.addAll(
                          currentList.map((d) =>
                              DeviceInfoExtractor.getDeviceId(d).toString()),
                        );
                      });
                    },
                    child: const Text('Semua',
                        style: TextStyle(color: Colors.blue)),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        final currentList = _getFilteredAndSortedDevices();
                        for (var d in currentList) {
                          if (DeviceInfoExtractor.getConnectionStatus(d)
                                  .toLowerCase() ==
                              'offline') {
                            _selectedDeviceIds.add(
                                DeviceInfoExtractor.getDeviceId(d).toString());
                          }
                        }
                      });
                    },
                    child: const Text('Offline',
                        style: TextStyle(color: Colors.red)),
                  ),
                ],
              )
            : AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                iconTheme: const IconThemeData(color: Colors.white),
                title: const Text(
                  'GenieACS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                centerTitle: true,
                actions: [
                  IconButton(
                    icon: _isRefreshing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.refresh),
                    onPressed: _isRefreshing ? null : _manualRefresh,
                    tooltip: 'Refresh',
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () {
                      Navigator.pushNamed(context, '/api-config');
                    },
                    tooltip: 'Pengaturan',
                  ),
                ],
              ),
        floatingActionButton: _isSelectionMode && _selectedDeviceIds.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: _summonSelectedDevices,
                backgroundColor: Colors.orange,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: Text(
                  'Summon (${_selectedDeviceIds.length})',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              )
            : null,
        body: _isLoading && _devices.isEmpty
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : Column(
                children: [
                  Expanded(
                      child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 16),
                                if (_devices.isEmpty)
                                  Card(
                                    elevation: 2,
                                    color: isDark
                                        ? const Color(0xFF1E1E1E)
                                        : Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        children: [
                                          const Icon(Icons.cloud_off,
                                              size: 64, color: Colors.grey),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Belum Dikonfigurasi',
                                            style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black87),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Silakan konfigurasi GenieACS di Settings',
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: isDark
                                                    ? Colors.white70
                                                    : Colors.black54),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else ...[
                                  // Search and Filter Bar
                                  Container(
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF1E1E1E)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withOpacity(isDark ? 0.2 : 0.05),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _searchController,
                                            onChanged: (value) {
                                              _searchDebounce?.cancel();
                                              _searchDebounce = Timer(
                                                  const Duration(
                                                      milliseconds: 500),
                                                  () => setState(() {}));
                                            },
                                            decoration: InputDecoration(
                                              hintText: 'Cari perangkat...',
                                              hintStyle: TextStyle(
                                                  color: isDark
                                                      ? Colors.white54
                                                      : Colors.black45),
                                              prefixIcon: Icon(Icons.search,
                                                  color: isDark
                                                      ? Colors.white70
                                                      : Colors.black54),
                                              suffixIcon: _searchController
                                                      .text.isNotEmpty
                                                  ? IconButton(
                                                      icon: Icon(Icons.clear,
                                                          color: isDark
                                                              ? Colors.white70
                                                              : Colors.black54),
                                                      onPressed: () {
                                                        _searchController
                                                            .clear();
                                                        setState(() {});
                                                      },
                                                    )
                                                  : null,
                                              border: InputBorder.none,
                                              isDense: true,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 12),
                                            ),
                                            style: TextStyle(
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black87),
                                          ),
                                        ),
                                        Container(
                                            height: 30,
                                            width: 1,
                                            color: isDark
                                                ? Colors.grey.shade700
                                                : Colors.grey.shade300),
                                        IconButton(
                                          icon: Icon(
                                            Icons.tune,
                                            color: _statusFilter != 'Semua' ||
                                                    _sortOption !=
                                                        'Last Inform (Newest)' ||
                                                    _rxFilter != 'Semua'
                                                ? Colors.blue
                                                : (isDark
                                                    ? Colors.white70
                                                    : Colors.black54),
                                          ),
                                          onPressed: _showFilterDialog,
                                          tooltip: 'Filter',
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  // Devices List Header
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        bottom: 12, left: 4),
                                    child: Text(
                                      'Daftar Perangkat (${filteredDevices.length})',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.black54,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  // Devices List
                                  if (_isLoading)
                                    const Expanded(
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    )
                                  else if (filteredDevices.isEmpty)
                                    Expanded(
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.search_off,
                                                size: 80,
                                                color: isDark
                                                    ? Colors.white24
                                                    : Colors.black26),
                                            const SizedBox(height: 16),
                                            Text(
                                              'Tidak ada perangkat ditemukan',
                                              style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark
                                                      ? Colors.white70
                                                      : Colors.black54),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  else
                                    Expanded(
                                      child: ListView.builder(
                                        padding:
                                            const EdgeInsets.only(bottom: 20),
                                        physics: const BouncingScrollPhysics(),
                                        itemCount: filteredDevices.length,
                                        itemBuilder: (context, index) {
                                          return _buildPremiumDeviceCard(
                                              filteredDevices[index], isDark);
                                        },
                                      ),
                                    ),
                                ],
                              ]))),
                  _buildFooter(),
                ],
              ),
      ),
    );
  }

  Widget _buildFooter() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    if (_isLoading && _devices.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_devices.isEmpty) return const SizedBox.shrink();

    int activeCount = 0;
    int offlineCount = 0;

    for (var d in _devices) {
      final status = DeviceInfoExtractor.getConnectionStatus(d).toLowerCase();
      if (status == 'online' || status == 'idle') {
        activeCount++;
      } else {
        offlineCount++;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            offset: const Offset(0, -4),
            blurRadius: 16,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isLoading) ...[
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
              ] else ...[
                Icon(Icons.router,
                    color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                    size: 16),
                const SizedBox(width: 8),
              ],
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                  children: [
                    TextSpan(
                        text: '${_devices.length} ',
                        style: TextStyle(
                            color: isDark
                                ? Colors.blue.shade300
                                : Colors.blue.shade700,
                            fontWeight: FontWeight.bold)),
                    const TextSpan(text: 'Total   •   '),
                    TextSpan(
                        text: '$activeCount ',
                        style: TextStyle(
                            color: isDark
                                ? Colors.green.shade400
                                : Colors.green.shade600,
                            fontWeight: FontWeight.bold)),
                    const TextSpan(text: 'Online   •   '),
                    TextSpan(
                        text: '$offlineCount ',
                        style: TextStyle(
                            color: isDark
                                ? Colors.red.shade400
                                : Colors.red.shade600,
                            fontWeight: FontWeight.bold)),
                    const TextSpan(text: 'Offline'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(Map<String, dynamic> device) {
    final status = DeviceInfoExtractor.getConnectionStatus(device);
    switch (status.toLowerCase()) {
      case 'online':
        return Colors.green;
      case 'idle':
        return Colors.orange;
      case 'offline':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildPremiumDeviceCard(Map<String, dynamic> device, bool isDark) {
    final statusColor = _getStatusColor(device);
    final isSelected =
        _selectedDeviceIds.contains(DeviceInfoExtractor.getDeviceId(device));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onLongPress: () {
            if (!_isSelectionMode) {
              setState(() {
                _isSelectionMode = true;
                _selectedDeviceIds.add(DeviceInfoExtractor.getDeviceId(device));
              });
            }
          },
          onTap: () {
            if (_isSelectionMode) {
              setState(() {
                final deviceId = DeviceInfoExtractor.getDeviceId(device);
                if (_selectedDeviceIds.contains(deviceId)) {
                  _selectedDeviceIds.remove(deviceId);
                  if (_selectedDeviceIds.isEmpty) {
                    _isSelectionMode = false;
                  }
                } else {
                  _selectedDeviceIds.add(deviceId);
                }
              });
            } else {
              _showDeviceDetails(device);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isSelectionMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Checkbox(
                      value: isSelected,
                      activeColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                      onChanged: (bool? value) {
                        setState(() {
                          final deviceId =
                              DeviceInfoExtractor.getDeviceId(device);
                          if (value == true) {
                            _selectedDeviceIds.add(deviceId);
                          } else {
                            _selectedDeviceIds.remove(deviceId);
                            if (_selectedDeviceIds.isEmpty) {
                              _isSelectionMode = false;
                            }
                          }
                        });
                      },
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: statusColor.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(Icons.router,
                                color: statusColor, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DeviceInfoExtractor.getPPPoEUsername(device),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                    letterSpacing: 0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.cloud,
                                        size: 14,
                                        color: isDark
                                            ? Colors.blue.shade300
                                            : Colors.blue.shade700),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        DeviceInfoExtractor.getPPPoEIP(
                                                    device) !=
                                                '-'
                                            ? DeviceInfoExtractor.getPPPoEIP(
                                                device)
                                            : DeviceInfoExtractor.getModel(
                                                device),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black54,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon:
                                const Icon(Icons.password, color: Colors.blue),
                            onPressed: () => _showChangePasswordDialog(device),
                            tooltip: 'Ganti WiFi & Password',
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.blue.withOpacity(0.1),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.wifi_tethering,
                                  size: 14,
                                  color: isDark
                                      ? Colors.orange.shade300
                                      : Colors.orange.shade700,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'RX: ${DeviceInfoExtractor.getRXPower(device)} dBm',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.orange.shade300
                                        : Colors.orange.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color:
                                      isDark ? Colors.white54 : Colors.black54,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  DeviceInfoExtractor.getLastInform(device)
                                      .split(' ')
                                      .take(2)
                                      .join(' '),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (DeviceInfoExtractor.getTags(device).isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: DeviceInfoExtractor.getTags(device)
                              .take(4)
                              .map((tag) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: Colors.blue.withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      tag,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.blue.shade300
                                            : Colors.blue.shade700,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                    ],
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
