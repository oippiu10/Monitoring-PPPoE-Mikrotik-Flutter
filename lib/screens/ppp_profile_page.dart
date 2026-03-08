import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/mikrotik_provider.dart';
import '../providers/router_session_provider.dart';
import '../services/api_service.dart';
import '../widgets/gradient_container.dart'; // Add this import
import 'add_ppp_profile_screen.dart';
import 'edit_ppp_profile_screen.dart';

class PPPProfilePage extends StatefulWidget {
  const PPPProfilePage({super.key});

  @override
  State<PPPProfilePage> createState() => _PPPProfilePageState();
}

class _PPPProfilePageState extends State<PPPProfilePage> {
  // Fixed syntax errors
  String _searchQuery = '';
  // Additional comment to trigger refresh
  String _sortBy = 'Name (A-Z)';
  final TextEditingController _searchController = TextEditingController();
  Map<String, Map<String, dynamic>> _profilePricing =
      {}; // profile_name -> pricing data
  StateSetter? _modalStateSetter; // Callback untuk refresh modal detail
  bool _isRefreshing = false; // State untuk loading indicator saat refresh
  BuildContext?
      _profileDetailModalContext; // Context untuk detail modal agar bisa ditutup

  final List<String> _sortOptions = [
    'Name (A-Z)',
    'Name (Z-A)',
    'Rate Limit (Highest)',
    'Rate Limit (Lowest)',
  ];

  // Helper function to convert rate to bytes
  int _convertToBytes(String rate) {
    if (rate.isEmpty) return 0;

    // Handle k and M suffixes
    int multiplier = 1;
    if (rate.endsWith('k')) {
      multiplier = 1024;
      rate = rate.substring(0, rate.length - 1);
    } else if (rate.endsWith('M')) {
      multiplier = 1024 * 1024;
      rate = rate.substring(0, rate.length - 1);
    }

    return (int.tryParse(rate) ?? 0) * multiplier;
  }

  // Helper function to get rate limit value for sorting
  int _getRateLimitValue(String rateLimit) {
    if (rateLimit == '-') return 0;

    // Get the first part before the space (e.g., "2M/2M" from "2M/2M 0/0 0/0 10/10 8 1024k/1024k")
    final firstPart = rateLimit.split(' ').first;

    // Split by '/' and get the first rate (upload rate)
    final rates = firstPart.split('/');
    if (rates.isEmpty) return 0;

    // Convert the rate to bytes for comparison
    return _convertToBytes(rates[0]);
  }

  List<Map<String, dynamic>> _sortProfiles(
      List<Map<String, dynamic>> profiles) {
    switch (_sortBy) {
      case 'Name (A-Z)':
        return List.from(profiles)
          ..sort((a, b) => (a['name'] ?? '')
              .toString()
              .compareTo((b['name'] ?? '').toString()));
      case 'Name (Z-A)':
        return List.from(profiles)
          ..sort((a, b) => (b['name'] ?? '')
              .toString()
              .compareTo((a['name'] ?? '').toString()));
      case 'Rate Limit (Highest)':
        return List.from(profiles)
          ..sort((a, b) {
            final aLimit = (a['rate-limit'] ?? '-').toString();
            final bLimit = (b['rate-limit'] ?? '-').toString();
            // If either is '-', put it at the end
            if (aLimit == '-') return 1;
            if (bLimit == '-') return -1;
            return _getRateLimitValue(bLimit)
                .compareTo(_getRateLimitValue(aLimit));
          });
      case 'Rate Limit (Lowest)':
        return List.from(profiles)
          ..sort((a, b) {
            final aLimit = (a['rate-limit'] ?? '-').toString();
            final bLimit = (b['rate-limit'] ?? '-').toString();
            // If either is '-', put it at the end
            if (aLimit == '-') return 1;
            if (bLimit == '-') return -1;
            return _getRateLimitValue(aLimit)
                .compareTo(_getRateLimitValue(bLimit));
          });
      default:
        return profiles;
    }
  }

  List<Map<String, dynamic>> _filterProfiles(
      List<Map<String, dynamic>> profiles) {
    if (_searchQuery.isEmpty) return profiles;

    return profiles.where((profile) {
      final name = profile['name']?.toString().toLowerCase() ?? '';
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  void _showSortMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sort by',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                ...List.generate(
                  _sortOptions.length,
                  (index) => ListTile(
                    title: Text(
                      _sortOptions[index],
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    trailing: _sortBy == _sortOptions[index]
                        ? Icon(Icons.check,
                            color: isDark ? Colors.blue.shade300 : Colors.blue)
                        : null,
                    onTap: () {
                      setState(() => _sortBy = _sortOptions[index]);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfilePricing();
    });
  }

  Future<void> _loadProfilePricing() async {
    if (!mounted) return;

    final routerSession = context.read<RouterSessionProvider>();
    final routerId = routerSession.routerId;

    if (routerId == null || routerId.isEmpty) {
      debugPrint('[PPP Profile] Router ID is null or empty');
      return;
    }

    try {
      debugPrint('[PPP Profile] Loading pricing for router: $routerId');
      // Add timeout to prevent infinite loading
      final pricingList = await ApiService.getProfilePricing(routerId: routerId)
          .timeout(const Duration(seconds: 10), onTimeout: () {
        debugPrint('[PPP Profile] Timeout loading pricing');
        return <Map<String, dynamic>>[];
      });

      debugPrint(
          '[PPP Profile] Received ${pricingList.length} pricing entries from API');

      final pricingMap = <String, Map<String, dynamic>>{};

      for (var pricing in pricingList) {
        final profileName = pricing['profile_name']?.toString();
        if (profileName != null) {
          pricingMap[profileName] = pricing;
          debugPrint(
              '[PPP Profile] Mapped pricing for profile: $profileName, price: ${pricing['price']}');
        }
      }

      if (mounted) {
        setState(() {
          _profilePricing = pricingMap;
          _isRefreshing = false; // Stop loading indicator
        });
        debugPrint(
            '[PPP Profile] Loaded ${pricingMap.length} pricing entries into state');
      }
    } catch (e) {
      // Silent fail - tidak tampilkan error jika pricing tidak tersedia
      // Hanya log untuk debugging
      debugPrint('[PPP Profile] Error loading profile pricing: $e');
      debugPrint('[PPP Profile] Error type: ${e.runtimeType}');
      if (mounted) {
        setState(() {
          _profilePricing = {};
          _isRefreshing = false; // Stop loading indicator even on error
        });
      }
    }
  }

  String _formatPrice(double? price) {
    if (price == null || price == 0) return '-';
    // Format sesuai database: gunakan format Indonesia dengan titik sebagai separator ribuan
    // Contoh: 166500 -> Rp 166.500 (bukan Rp 16.650.000)
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(price);
  }

  // Helper function to safely convert price from various types to double
  double? _parsePrice(dynamic priceValue) {
    if (priceValue == null) return null;

    debugPrint(
        '[PPP Profile] _parsePrice input: $priceValue (type: ${priceValue.runtimeType})');

    if (priceValue is double) {
      debugPrint('[PPP Profile] _parsePrice: double value = $priceValue');
      return priceValue;
    }
    if (priceValue is int) {
      debugPrint(
          '[PPP Profile] _parsePrice: int value = $priceValue, converted to double = ${priceValue.toDouble()}');
      return priceValue.toDouble();
    }
    if (priceValue is String) {
      // Remove any formatting characters (dots, commas, etc)
      final cleaned = priceValue.replaceAll(RegExp(r'[^\d.]'), '');
      debugPrint(
          '[PPP Profile] _parsePrice: String value = $priceValue, cleaned = $cleaned');
      final parsed = double.tryParse(cleaned);
      debugPrint('[PPP Profile] _parsePrice: parsed = $parsed');
      return parsed;
    }

    // Try to convert to string first, then parse
    try {
      final str = priceValue.toString();
      final cleaned = str.replaceAll(RegExp(r'[^\d.]'), '');
      debugPrint(
          '[PPP Profile] _parsePrice: toString = $str, cleaned = $cleaned');
      final parsed = double.tryParse(cleaned);
      debugPrint('[PPP Profile] _parsePrice: final parsed = $parsed');
      return parsed;
    } catch (e) {
      debugPrint('[PPP Profile] Error parsing price: $e');
      return null;
    }
  }

  // Helper function to format number with thousand separator (dot)
  String _formatNumberWithDots(String value) {
    // Remove all non-digit characters
    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) return '';

    // Add dots every 3 digits from right to left
    final buffer = StringBuffer();
    for (int i = 0; i < digitsOnly.length; i++) {
      if (i > 0 && (digitsOnly.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digitsOnly[i]);
    }
    return buffer.toString();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GradientContainer(
      // Wrap the Scaffold with GradientContainer
      child: Scaffold(
        backgroundColor:
            Colors.transparent, // Make Scaffold background transparent
        appBar: AppBar(
          title: Text(
            'PPP Profiles',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.white),
          actions: [
            IconButton(
              icon: Icon(Icons.add_circle_outline,
                  color: isDark ? Colors.white : Colors.white),
              tooltip: 'Tambah Profile',
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddPPPProfileScreen(),
                  ),
                );
                // Refresh if profile was added
                if (result == true) {
                  final provider = context.read<MikrotikProvider>();
                  provider.refreshData();
                }
              },
            ),
            IconButton(
              icon: Icon(Icons.refresh,
                  color: isDark ? Colors.white : Colors.white),
              tooltip: 'Refresh',
              onPressed: () {
                final provider = context.read<MikrotikProvider>();
                provider.refreshData();
                _loadProfilePricing();
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Search and Filter Bar
            Padding(
              padding: const EdgeInsets.all(16),
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
                                controller: _searchController,
                                onChanged: (value) =>
                                    setState(() => _searchQuery = value),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Search profiles...',
                                  hintStyle: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 12),
                                ),
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
                                  setState(() => _searchQuery = '');
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
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                        onPressed: _showSortMenu,
                        iconSize: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // List View and Footer
            Expanded(
              child: Consumer<MikrotikProvider>(
                builder: (context, provider, child) {
                  // Show loading if provider is loading AND profiles list is empty, OR if refreshing after operation
                  if ((provider.isLoading && provider.pppProfiles.isEmpty) ||
                      _isRefreshing) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }

                  final profiles = provider.pppProfiles;

                  final filteredProfiles = _filterProfiles(profiles);
                  final sortedProfiles = _sortProfiles(filteredProfiles);
                  final profileCount = sortedProfiles.length;

                  if (sortedProfiles.isEmpty) {
                    return Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _searchQuery.isEmpty
                                      ? Icons.account_box_outlined
                                      : Icons.search_off,
                                  size: 64,
                                  color: isDark
                                      ? Colors.white.withOpacity(0.6)
                                      : Colors.white.withOpacity(0.6),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isEmpty
                                      ? 'No PPP Profiles found'
                                      : 'No matching profiles found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: isDark
                                        ? Colors.white.withOpacity(0.8)
                                        : Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Footer with total count
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                          decoration: BoxDecoration(
                            color:
                                isDark ? const Color(0xFF1E1E1E) : Colors.white,
                            borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(12)),
                            border: Border(
                              top: BorderSide(
                                color: isDark
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.account_box,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$profileCount total profiles',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: sortedProfiles.length,
                          itemBuilder: (context, index) {
                            final profile = sortedProfiles[index];
                            final isDefault = profile['default'] == 'true';
                            final isIsolir =
                                profile['name']?.toString().toUpperCase() ==
                                    'ISOLIR';
                            final rateLimit = profile['rate-limit']?.toString();
                            final profileName =
                                profile['name']?.toString() ?? '';
                            final pricing = _profilePricing[profileName];
                            final price = pricing != null
                                ? _parsePrice(pricing['price'])
                                : null;

                            // Debug: log nilai price yang di-parse
                            if (price != null) {
                              debugPrint(
                                  '[PPP Profile] Profile: $profileName, Raw price from DB: ${pricing?['price']}, Parsed price: $price');
                            }

                            return Card(
                              color: isDark
                                  ? const Color(0xFF1E1E1E)
                                  : Colors.white,
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: InkWell(
                                onTap: () =>
                                    _showProfileDetail(context, profile),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      left: BorderSide(
                                        color: isIsolir
                                            ? Colors.red
                                            : isDefault
                                                ? Colors.blue
                                                : Colors.orange,
                                        width: 4,
                                      ),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              isIsolir
                                                  ? Icons.block_outlined
                                                  : isDefault
                                                      ? Icons.verified_outlined
                                                      : Icons.wifi,
                                              size: 20,
                                              color: isIsolir
                                                  ? Colors.red
                                                  : isDefault
                                                      ? Colors.blue
                                                      : Colors.orange,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                profile['name']?.toString() ??
                                                    'Unnamed Profile',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w500,
                                                  color: isDark
                                                      ? Colors.white
                                                      : Colors.black87,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (rateLimit != null &&
                                            rateLimit != '-') ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? const Color(0xFF2D2D2D)
                                                  : Colors.grey.shade50,
                                              border: Border.all(
                                                color: isDark
                                                    ? Colors.grey.shade700
                                                    : Colors.grey.shade200,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.speed_rounded,
                                                  size: 14,
                                                  color: isDark
                                                      ? Colors.grey.shade400
                                                      : Colors.grey.shade700,
                                                ),
                                                const SizedBox(width: 6),
                                                Flexible(
                                                  child: Text(
                                                    rateLimit,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: isDark
                                                          ? Colors.grey.shade300
                                                          : Colors
                                                              .grey.shade700,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 2,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        if (price != null && price > 0) ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? Colors.green.shade900
                                                      .withOpacity(0.3)
                                                  : Colors.green.shade50,
                                              border: Border.all(
                                                color: isDark
                                                    ? Colors.green.shade700
                                                    : Colors.green.shade200,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.payments_rounded,
                                                  size: 14,
                                                  color: isDark
                                                      ? Colors.green.shade300
                                                      : Colors.green.shade700,
                                                ),
                                                const SizedBox(width: 6),
                                                Flexible(
                                                  child: Text(
                                                    _formatPrice(price),
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: isDark
                                                          ? Colors
                                                              .green.shade300
                                                          : Colors
                                                              .green.shade700,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // Footer with total count
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color:
                              isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(12)),
                          border: Border(
                            top: BorderSide(
                              color: isDark
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.account_box,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$profileCount total profiles',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProfileDetail(BuildContext context, Map<String, dynamic> profile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDefault = profile['default'] == 'true';
    final isIsolir = profile['name']?.toString().toUpperCase() == 'ISOLIR';
    final profileName = profile['name']?.toString() ?? '';

    // Save parent context that has access to providers
    final parentContext = context;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        // Save modal context for later use
        _profileDetailModalContext = context;
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            // Save setModalState callback for later use
            _modalStateSetter = setModalState;

            // Re-fetch pricing data when modal is built
            final currentPricing = _profilePricing[profileName];
            final currentPrice = currentPricing != null
                ? _parsePrice(currentPricing['price'])
                : null;
            final currentPricingId = currentPricing?['id'] as int?;

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (_, controller) => Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    // Handle bar
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.grey.shade700
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Content
                    Expanded(
                      child: ListView(
                        controller: controller,
                        padding: const EdgeInsets.all(20),
                        children: [
                          // Header
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isIsolir
                                      ? (isDark
                                          ? Colors.red.shade900
                                          : Colors.red.shade50)
                                      : isDefault
                                          ? (isDark
                                              ? Colors.blue.shade900
                                              : Colors.blue.shade50)
                                          : (isDark
                                              ? Colors.orange.shade900
                                              : Colors.orange.shade50),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isIsolir
                                      ? Icons.block_outlined
                                      : isDefault
                                          ? Icons.verified_outlined
                                          : Icons.wifi,
                                  size: 24,
                                  color: isIsolir
                                      ? (isDark
                                          ? Colors.red.shade300
                                          : Colors.red)
                                      : isDefault
                                          ? (isDark
                                              ? Colors.blue.shade300
                                              : Colors.blue)
                                          : (isDark
                                              ? Colors.orange.shade300
                                              : Colors.orange),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      profile['name']?.toString() ??
                                          'Unnamed Profile',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                    if (isDefault) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.blue.shade900
                                              : Colors.blue.shade50,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Default Profile',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.blue.shade300
                                                : Colors.blue,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Only show edit button if pricing exists
                              if (currentPrice != null && currentPrice > 0)
                                IconButton(
                                  icon: Icon(
                                    Icons.edit,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                  onPressed: () {
                                    _showEditPricingDialog(
                                        modalContext,
                                        profileName,
                                        currentPricingId,
                                        currentPrice,
                                        currentPricing?['description']
                                            ?.toString());
                                    // Note: Modal will refresh automatically after pricing is reloaded
                                  },
                                  tooltip: 'Edit Harga',
                                ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Pricing Section
                          if (currentPrice != null && currentPrice > 0) ...[
                            _buildDetailSection(
                              'Pricing',
                              [
                                _buildDetailRow(
                                  Icons.payments,
                                  'Harga per Bulan',
                                  value: _formatPrice(currentPrice),
                                  isHighlighted: true,
                                  isDark: isDark,
                                ),
                                if (currentPricing?['description'] != null &&
                                    currentPricing!['description']
                                        .toString()
                                        .isNotEmpty)
                                  _buildDetailRow(
                                    Icons.description,
                                    'Deskripsi',
                                    value: currentPricing['description']
                                            ?.toString() ??
                                        '-',
                                    isDark: isDark,
                                  ),
                              ],
                              isDark: isDark,
                            ),
                            const SizedBox(height: 24),
                          ] else ...[
                            // Show add pricing button if no pricing exists
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF2D2D2D)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.grey.shade700
                                      : Colors.grey.shade300,
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: TextButton.icon(
                                onPressed: () {
                                  _showEditPricingDialog(modalContext,
                                      profileName, null, null, null);
                                  // Note: Modal will refresh automatically after pricing is reloaded
                                },
                                icon: Icon(Icons.add,
                                    color: isDark
                                        ? Colors.green.shade300
                                        : Colors.green.shade700),
                                label: Text(
                                  'Tetapkan Harga',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.green.shade300
                                        : Colors.green.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Rate Limit Section
                          // Fixed syntax error
                          if (profile['rate-limit'] != null) ...[
                            // Additional comment
                            // More comments
                            _buildDetailSection(
                              'Rate Limit',
                              [
                                _buildDetailRow(
                                  Icons.speed,
                                  'Rate Limit',
                                  value:
                                      profile['rate-limit']?.toString() ?? '-',
                                  isHighlighted: true,
                                  isDark: isDark,
                                ),
                              ],
                              isDark: isDark,
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Network Settings Section
                          _buildDetailSection(
                            'Network Settings',
                            [
                              _buildDetailRow(
                                Icons.router,
                                'Local Address',
                                value:
                                    profile['local-address']?.toString() ?? '-',
                                isDark: isDark,
                              ),
                              _buildDetailRow(
                                Icons.public,
                                'Remote Address',
                                value: profile['remote-address']?.toString() ??
                                    '-',
                                isDark: isDark,
                              ),
                              _buildDetailRow(
                                Icons.dns,
                                'DNS Server',
                                value: profile['dns-server']?.toString() ?? '-',
                                isDark: isDark,
                              ),
                              _buildDetailRow(
                                Icons.dns_outlined,
                                'WINS Server',
                                value:
                                    profile['wins-server']?.toString() ?? '-',
                                isDark: isDark,
                              ),
                            ],
                            isDark: isDark,
                          ),
                          const SizedBox(height: 24),

                          // Additional Settings Section
                          _buildDetailSection(
                            'Additional Settings',
                            [
                              _buildDetailRow(
                                Icons.settings_ethernet,
                                'Bridge',
                                value: profile['bridge']?.toString() ?? '-',
                                isDark: isDark,
                              ),
                              _buildDetailRow(
                                Icons.sync_alt,
                                'Bridge Learning',
                                value: profile['bridge-learning']?.toString() ??
                                    '-',
                                isDark: isDark,
                              ),
                              _buildDetailRow(
                                Icons.speed,
                                'Change TCP MSS',
                                value: profile['change-tcp-mss']?.toString() ??
                                    '-',
                                isDark: isDark,
                              ),
                              _buildDetailRow(
                                Icons.language,
                                'Use IPv6',
                                value: profile['use-ipv6']?.toString() ?? '-',
                                isDark: isDark,
                              ),
                              _buildDetailRow(
                                Icons.person_outline,
                                'Only One',
                                value: profile['only-one']?.toString() ?? '-',
                                isDark: isDark,
                              ),
                            ],
                            isDark: isDark,
                          ),

                          // Action Buttons
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              // Edit Button
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    Navigator.pop(context); // Close modal
                                    final result = await Navigator.push(
                                      parentContext,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            EditPPPProfileScreen(
                                          profile: profile,
                                        ),
                                      ),
                                    );
                                    // Refresh if profile was updated
                                    if (result == true) {
                                      final provider = parentContext
                                          .read<MikrotikProvider>();
                                      provider.refreshData();
                                    }
                                  },
                                  icon: const Icon(Icons.edit),
                                  label: const Text('Edit'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange[700],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Delete Button
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: isDefault
                                      ? null
                                      : () async {
                                          // Show confirmation dialog
                                          final confirm =
                                              await showDialog<bool>(
                                            context: context,
                                            builder: (dialogContext) =>
                                                AlertDialog(
                                              title:
                                                  const Text('Hapus Profile'),
                                              content: Text(
                                                  'Apakah Anda yakin ingin menghapus profile "$profileName"?\n\nProfile yang sedang digunakan tidak dapat dihapus.'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          dialogContext, false),
                                                  child: const Text('Batal'),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          dialogContext, true),
                                                  style: TextButton.styleFrom(
                                                    foregroundColor: Colors.red,
                                                  ),
                                                  child: const Text('Hapus'),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (confirm == true) {
                                            try {
                                              // Use parentContext that has access to providers
                                              final provider = parentContext
                                                  .read<MikrotikProvider>();

                                              final routerSession =
                                                  parentContext.read<
                                                      RouterSessionProvider>();
                                              final service =
                                                  await routerSession
                                                      .getService();

                                              final profileId =
                                                  profile['.id']?.toString();
                                              if (profileId == null) {
                                                throw Exception(
                                                    'Profile ID tidak ditemukan');
                                              }

                                              await service
                                                  .deletePPPProfile(profileId);

                                              if (!context.mounted) return;

                                              // Close modal
                                              Navigator.pop(context);

                                              // Show success message using parentContext
                                              ScaffoldMessenger.of(
                                                      parentContext)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                      'Profile berhasil dihapus'),
                                                  backgroundColor: Colors.green,
                                                  duration:
                                                      Duration(seconds: 2),
                                                ),
                                              );

                                              // Refresh data using saved provider
                                              provider.refreshData();
                                            } catch (e) {
                                              if (!context.mounted) return;

                                              // Show error using parentContext
                                              ScaffoldMessenger.of(
                                                      parentContext)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      'Gagal menghapus profile: ${e.toString()}'),
                                                  backgroundColor: Colors.red,
                                                  duration: const Duration(
                                                      seconds: 3),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                  icon: const Icon(Icons.delete),
                                  label: const Text('Hapus'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDefault
                                        ? Colors.grey
                                        : Colors.red[700],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (isDefault)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Default profile tidak dapat dihapus',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
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
      },
    );
  }

// Fixed syntax errors
  Widget _buildDetailSection(String title, List<Widget> children,
      {required bool isDark}) {
    // Additional comment to trigger refresh
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label,
      {String? value, bool isHighlighted = false, required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isHighlighted
                  ? (isDark ? Colors.blue.shade900 : Colors.blue.shade50)
                  : (isDark ? const Color(0xFF2D2D2D) : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isHighlighted
                  ? (isDark ? Colors.blue.shade300 : Colors.blue)
                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: value == null
                ? Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isHighlighted
                          ? (isDark
                              ? Colors.blue.shade300
                              : Colors.blue.shade700)
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 3,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _showEditPricingDialog(BuildContext context, String profileName,
      int? pricingId, double? currentPrice, String? currentDescription) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Format current price with dots for display
    final initialPriceText = currentPrice != null
        ? _formatNumberWithDots(currentPrice.toStringAsFixed(0))
        : '';
    final priceController = TextEditingController(text: initialPriceText);
    final descriptionController =
        TextEditingController(text: currentDescription ?? '');
    bool isLoading = false;
    bool isDeleting = false; // State terpisah untuk tombol Hapus

    // Text input formatter untuk format angka dengan titik
    final priceFormatter =
        TextInputFormatter.withFunction((oldValue, newValue) {
      final newText = newValue.text;
      if (newText.isEmpty) return newValue;

      // Format dengan titik setiap 3 angka
      final formatted = _formatNumberWithDots(newText);
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    });

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                pricingId == null
                    ? Icons.add_circle_outline
                    : Icons.edit_outlined,
                color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pricingId == null ? 'Tambah Harga' : 'Edit Harga',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        isDark ? const Color(0xFF2D2D2D) : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          isDark ? Colors.blue.shade700 : Colors.blue.shade200,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.wifi,
                        size: 16,
                        color: isDark
                            ? Colors.blue.shade300
                            : Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Profile: $profileName',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? Colors.blue.shade300
                                : Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [priceFormatter],
                  decoration: InputDecoration(
                    labelText: 'Harga per Bulan (Rp)',
                    labelStyle: TextStyle(
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600),
                    hintText: 'Contoh: 150.000',
                    hintStyle: TextStyle(
                        color: isDark
                            ? Colors.grey.shade600
                            : Colors.grey.shade400),
                    prefixIcon: Icon(
                      Icons.payments_rounded,
                      color:
                          isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                    filled: true,
                    fillColor:
                        isDark ? const Color(0xFF2D2D2D) : Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: isDark
                              ? Colors.grey.shade700
                              : Colors.grey.shade300,
                          width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: isDark
                              ? Colors.grey.shade700
                              : Colors.grey.shade300,
                          width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: isDark ? Colors.blue.shade300 : Colors.blue,
                          width: 2),
                    ),
                  ),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Deskripsi (Opsional)',
                    labelStyle: TextStyle(
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600),
                    hintText: 'Contoh: Paket 10 Mbps',
                    hintStyle: TextStyle(
                        color: isDark
                            ? Colors.grey.shade600
                            : Colors.grey.shade400),
                    prefixIcon: Icon(
                      Icons.description_outlined,
                      color:
                          isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                    filled: true,
                    fillColor:
                        isDark ? const Color(0xFF2D2D2D) : Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: isDark
                              ? Colors.grey.shade700
                              : Colors.grey.shade300,
                          width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: isDark
                              ? Colors.grey.shade700
                              : Colors.grey.shade300,
                          width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: isDark ? Colors.blue.shade300 : Colors.blue,
                          width: 2),
                    ),
                  ),
                  style:
                      TextStyle(color: isDark ? Colors.white : Colors.black87),
                ),
              ],
            ),
          ),
          actions: [
            // Button Row - Hapus (if editing), Update/Save
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Delete Button (only if editing)
                  if (pricingId != null) ...[
                    Flexible(
                      child: TextButton(
                        onPressed: (isLoading || isDeleting)
                            ? null
                            : () async {
                                try {
                                  final routerSession =
                                      Provider.of<RouterSessionProvider>(
                                          dialogContext,
                                          listen: false);
                                  final routerId = routerSession.routerId;

                                  if (routerId == null || routerId.isEmpty) {
                                    if (dialogContext.mounted) {
                                      ScaffoldMessenger.of(dialogContext)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Router ID tidak ditemukan. Silakan login ulang.')),
                                      );
                                    }
                                    return;
                                  }

                                  setDialogState(() => isDeleting = true);

                                  try {
                                    await ApiService.deleteProfilePricing(
                                      routerId: routerId,
                                      id: pricingId,
                                      adminUsername: routerSession.username,
                                    );

                                    if (dialogContext.mounted) {
                                      // Close edit dialog first
                                      Navigator.pop(dialogContext);

                                      // Wait for next frame to ensure dialog is fully closed
                                      await Future.delayed(
                                          const Duration(milliseconds: 100));

                                      // Show success dialog immediately after closing edit dialog
                                      if (context.mounted) {
                                        debugPrint(
                                            '[PPP Profile] Showing success dialog for delete...');
                                        await showDialog(
                                          context: context,
                                          barrierDismissible: true,
                                          useRootNavigator: true,
                                          builder: (BuildContext
                                              successDialogContext) {
                                            final isDark =
                                                Theme.of(context).brightness ==
                                                    Brightness.dark;
                                            return AlertDialog(
                                              backgroundColor: isDark
                                                  ? const Color(0xFF1E1E1E)
                                                  : Colors.white,
                                              contentPadding: EdgeInsets.zero,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const SizedBox(height: 24),
                                                  // Icon with animated background
                                                  Container(
                                                    width: 64,
                                                    height: 64,
                                                    decoration: BoxDecoration(
                                                      color: isDark
                                                          ? Colors.green
                                                              .withOpacity(0.2)
                                                          : Colors
                                                              .green.shade50,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      Icons
                                                          .check_circle_rounded,
                                                      color: Colors.green,
                                                      size: 40,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 16),
                                                  // Title
                                                  Text(
                                                    'Berhasil!',
                                                    style: TextStyle(
                                                      fontSize: 20,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: isDark
                                                          ? Colors.white
                                                          : Colors.black87,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  // Message
                                                  Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 24),
                                                    child: Text(
                                                      'Harga berhasil dihapus',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: isDark
                                                            ? Colors.white70
                                                            : Colors.black54,
                                                      ),
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 24),
                                                  // OK Button
                                                  Padding(
                                                    padding: const EdgeInsets
                                                        .fromLTRB(
                                                        20, 0, 20, 20),
                                                    child: SizedBox(
                                                      width: double.infinity,
                                                      child:
                                                          ElevatedButton.icon(
                                                        onPressed: () {
                                                          Navigator.of(
                                                                  successDialogContext,
                                                                  rootNavigator:
                                                                      true)
                                                              .pop();
                                                        },
                                                        icon: const Icon(
                                                            Icons.done_rounded,
                                                            size: 18),
                                                        label: const Text(
                                                          'OK',
                                                          style: TextStyle(
                                                            fontSize: 15,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                        style: ElevatedButton
                                                            .styleFrom(
                                                          backgroundColor:
                                                              Colors.green,
                                                          foregroundColor:
                                                              Colors.white,
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  vertical: 14),
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12),
                                                          ),
                                                          elevation: 2,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ).then((_) {
                                          // Refresh setelah dialog ditutup dengan cara apapun (OK atau klik di luar)
                                          debugPrint(
                                              '[PPP Profile] Success dialog closed, refreshing...');
                                          // Close detail modal if it's still open
                                          if (_profileDetailModalContext !=
                                              null) {
                                            try {
                                              Navigator.of(
                                                      _profileDetailModalContext!,
                                                      rootNavigator: true)
                                                  .pop();
                                              _profileDetailModalContext = null;
                                              _modalStateSetter = null;
                                            } catch (e) {
                                              debugPrint(
                                                  '[PPP Profile] Error closing detail modal: $e');
                                            }
                                          }
                                          // Refresh data with loading indicator after dialog closes
                                          if (mounted) {
                                            this.setState(() {
                                              this._isRefreshing =
                                                  true; // Show loading indicator
                                            });
                                            this._loadProfilePricing();
                                            this.setState(() {});
                                          }
                                        });
                                        debugPrint(
                                            '[PPP Profile] Success dialog shown for delete');
                                      }
                                    }
                                  } catch (e) {
                                    setDialogState(() => isDeleting = false);
                                    if (dialogContext.mounted) {
                                      final errorMessage = e
                                          .toString()
                                          .replaceAll('Exception: ', '')
                                          .replaceAll('FlutterError: ', '');
                                      ScaffoldMessenger.of(dialogContext)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              Icon(
                                                Icons.error_outline,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  'Gagal menghapus harga: $errorMessage',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          backgroundColor: Colors.red,
                                          duration: const Duration(seconds: 4),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          margin: const EdgeInsets.all(16),
                                        ),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  setDialogState(() => isDeleting = false);
                                  if (dialogContext.mounted) {
                                    ScaffoldMessenger.of(dialogContext)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Terjadi kesalahan: ${e.toString().replaceAll('Exception: ', '').replaceAll('FlutterError: ', '')}'),
                                        backgroundColor: Colors.red,
                                        duration: const Duration(seconds: 4),
                                      ),
                                    );
                                  }
                                }
                              },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          backgroundColor: Colors.red.shade50,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: Colors.red.shade300,
                              width: 1.5,
                            ),
                          ),
                        ),
                        child: isDeleting
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.red.shade700),
                                ),
                              )
                            : Text(
                                'Hapus',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Save/Update Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (isLoading || isDeleting)
                          ? null
                          : () async {
                              try {
                                final priceText = priceController.text
                                    .trim()
                                    .replaceAll('.', '');
                                if (priceText.isEmpty) {
                                  if (dialogContext.mounted) {
                                    ScaffoldMessenger.of(dialogContext)
                                        .showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Harga tidak boleh kosong')),
                                    );
                                  }
                                  return;
                                }

                                final price = double.tryParse(priceText);
                                if (price == null || price <= 0) {
                                  if (dialogContext.mounted) {
                                    ScaffoldMessenger.of(dialogContext)
                                        .showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Harga harus berupa angka positif')),
                                    );
                                  }
                                  return;
                                }

                                final routerSession =
                                    Provider.of<RouterSessionProvider>(
                                        dialogContext,
                                        listen: false);
                                final routerId = routerSession.routerId;

                                if (routerId == null || routerId.isEmpty) {
                                  if (dialogContext.mounted) {
                                    ScaffoldMessenger.of(dialogContext)
                                        .showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Router ID tidak ditemukan. Silakan login ulang.')),
                                    );
                                  }
                                  return;
                                }

                                setDialogState(() => isLoading = true);

                                try {
                                  Map<String, dynamic> result;
                                  if (pricingId == null) {
                                    // Add new pricing
                                    debugPrint(
                                        '[PPP Profile] Calling addProfilePricing...');
                                    result = await ApiService.addProfilePricing(
                                      routerId: routerId,
                                      profileName: profileName,
                                      price: price,
                                      description: descriptionController.text
                                              .trim()
                                              .isEmpty
                                          ? null
                                          : descriptionController.text.trim(),
                                      adminUsername: routerSession.username,
                                    );
                                    debugPrint(
                                        '[PPP Profile] addProfilePricing result: $result');
                                  } else {
                                    // Update existing pricing
                                    debugPrint(
                                        '[PPP Profile] Calling updateProfilePricing...');
                                    result =
                                        await ApiService.updateProfilePricing(
                                      routerId: routerId,
                                      id: pricingId,
                                      price: price,
                                      description: descriptionController.text
                                              .trim()
                                              .isEmpty
                                          ? null
                                          : descriptionController.text.trim(),
                                      adminUsername: routerSession.username,
                                    );
                                    debugPrint(
                                        '[PPP Profile] updateProfilePricing result: $result');
                                  }

                                  // Check if operation was successful
                                  if (result['success'] != true) {
                                    final errorMsg =
                                        result['error'] ?? 'Operasi gagal';
                                    debugPrint(
                                        '[PPP Profile] API returned error: $errorMsg');
                                    throw Exception(errorMsg);
                                  }

                                  debugPrint(
                                      '[PPP Profile] Pricing saved successfully');
                                  if (dialogContext.mounted) {
                                    // Close edit dialog first
                                    Navigator.pop(dialogContext);

                                    // Wait for next frame to ensure dialog is fully closed
                                    await Future.delayed(
                                        const Duration(milliseconds: 100));

                                    // Show success dialog immediately after closing edit dialog
                                    if (context.mounted) {
                                      debugPrint(
                                          '[PPP Profile] Showing success dialog for save/update...');
                                      await showDialog(
                                        context: context,
                                        barrierDismissible: true,
                                        useRootNavigator: true,
                                        builder: (BuildContext
                                            successDialogContext) {
                                          final isDark =
                                              Theme.of(context).brightness ==
                                                  Brightness.dark;
                                          return AlertDialog(
                                            backgroundColor: isDark
                                                ? const Color(0xFF1E1E1E)
                                                : Colors.white,
                                            contentPadding: EdgeInsets.zero,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const SizedBox(height: 24),
                                                // Icon with animated background
                                                Container(
                                                  width: 64,
                                                  height: 64,
                                                  decoration: BoxDecoration(
                                                    color: isDark
                                                        ? Colors.green
                                                            .withOpacity(0.2)
                                                        : Colors.green.shade50,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    Icons.check_circle_rounded,
                                                    color: Colors.green,
                                                    size: 40,
                                                  ),
                                                ),
                                                const SizedBox(height: 16),
                                                // Title
                                                Text(
                                                  'Berhasil!',
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark
                                                        ? Colors.white
                                                        : Colors.black87,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                                const SizedBox(height: 8),
                                                // Message
                                                Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 24),
                                                  child: Text(
                                                    pricingId == null
                                                        ? 'Harga berhasil ditambahkan'
                                                        : 'Harga berhasil diupdate',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: isDark
                                                          ? Colors.white70
                                                          : Colors.black54,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                                const SizedBox(height: 24),
                                                // OK Button
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                          20, 0, 20, 20),
                                                  child: SizedBox(
                                                    width: double.infinity,
                                                    child: ElevatedButton.icon(
                                                      onPressed: () {
                                                        Navigator.of(
                                                                successDialogContext,
                                                                rootNavigator:
                                                                    true)
                                                            .pop();
                                                      },
                                                      icon: const Icon(
                                                          Icons.done_rounded,
                                                          size: 18),
                                                      label: const Text(
                                                        'OK',
                                                        style: TextStyle(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor:
                                                            Colors.green,
                                                        foregroundColor:
                                                            Colors.white,
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                vertical: 14),
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                        ),
                                                        elevation: 2,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ).then((_) {
                                        // Refresh setelah dialog ditutup dengan cara apapun (OK atau klik di luar)
                                        debugPrint(
                                            '[PPP Profile] Success dialog closed, refreshing...');
                                        // Close detail modal if it's still open
                                        if (_profileDetailModalContext !=
                                            null) {
                                          try {
                                            Navigator.of(
                                                    _profileDetailModalContext!,
                                                    rootNavigator: true)
                                                .pop();
                                            _profileDetailModalContext = null;
                                            _modalStateSetter = null;
                                          } catch (e) {
                                            debugPrint(
                                                '[PPP Profile] Error closing detail modal: $e');
                                          }
                                        }
                                        // Refresh data with loading indicator after dialog closes
                                        if (mounted) {
                                          this.setState(() {
                                            this._isRefreshing =
                                                true; // Show loading indicator
                                          });
                                          this._loadProfilePricing();
                                          this.setState(() {});
                                        }
                                      });
                                      debugPrint(
                                          '[PPP Profile] Success dialog shown for save/update');
                                    }
                                  }
                                } catch (e) {
                                  debugPrint(
                                      '[PPP Profile] Error saving pricing: $e');
                                  debugPrint(
                                      '[PPP Profile] Error type: ${e.runtimeType}');
                                  setDialogState(() => isLoading = false);
                                  if (dialogContext.mounted) {
                                    final errorMessage = e
                                        .toString()
                                        .replaceAll('Exception: ', '')
                                        .replaceAll('FlutterError: ', '');
                                    ScaffoldMessenger.of(dialogContext)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            Icon(
                                              Icons.error_outline,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                'Gagal menyimpan harga: $errorMessage',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        backgroundColor: Colors.red,
                                        duration: const Duration(seconds: 4),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        margin: const EdgeInsets.all(16),
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                setDialogState(() => isLoading = false);
                                if (dialogContext.mounted) {
                                  final errorMessage = e
                                      .toString()
                                      .replaceAll('Exception: ', '')
                                      .replaceAll('FlutterError: ', '');
                                  ScaffoldMessenger.of(dialogContext)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          Icon(
                                            Icons.error_outline,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'Terjadi kesalahan: $errorMessage',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: Colors.red,
                                      duration: const Duration(seconds: 4),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      margin: const EdgeInsets.all(16),
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isDark ? Colors.blue.shade700 : Colors.blue,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                      child: isLoading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              pricingId == null ? 'Simpan' : 'Update',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
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
  }
}
