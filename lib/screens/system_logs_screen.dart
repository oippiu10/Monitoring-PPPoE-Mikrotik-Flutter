import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/router_session_provider.dart';
import '../services/log_service.dart';
import '../widgets/gradient_container.dart';

class SystemLogsScreen extends StatefulWidget {
  const SystemLogsScreen({super.key});

  @override
  State<SystemLogsScreen> createState() => _SystemLogsScreenState();
}

class _SystemLogsScreenState extends State<SystemLogsScreen> {
  final List<Map<String, dynamic>> _logs = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 20;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _loadLogs();
    }
  }

  Future<void> _loadLogs({bool refresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (refresh) {
        _logs.clear();
        _offset = 0;
        _hasMore = true;
      }
    });

    try {
      final session = context.read<RouterSessionProvider>();
      final routerId = session.routerId;

      if (routerId == null) {
        throw Exception('Router ID not found');
      }

      final newLogs = await LogService.getSystemLogs(
        routerId: routerId,
        limit: _limit,
        offset: _offset,
      );

      setState(() {
        _logs.addAll(newLogs);
        _offset += newLogs.length;
        if (newLogs.length < _limit) {
          _hasMore = false;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat log: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Color _getActionColor(String action, String details) {
    final lowerAction = action.toLowerCase();
    final lowerDetails = details.toLowerCase();

    if (lowerAction.contains('delete')) return Colors.redAccent;
    if (lowerAction.contains('add')) return Colors.green;
    if (lowerAction.contains('edit') || lowerAction.contains('update')) {
      return Colors.orange;
    }
    if (lowerAction.contains('login')) return Colors.blueAccent;
    if (lowerAction.contains('logout')) return Colors.grey;

    // PPPoE specific coloring
    if (lowerAction.contains('pppoe')) {
      if (lowerDetails.contains('connected') &&
          !lowerDetails.contains('disconnected')) {
        return Colors.green;
      }
      if (lowerDetails.contains('disconnected') ||
          lowerDetails.contains('terminating')) {
        return Colors.red;
      }
      return Colors.blue;
    }

    // Error/Warning specific coloring
    if (lowerAction.contains('error') || lowerAction.contains('failure')) {
      return Colors.red;
    }
    if (lowerAction.contains('warning')) return Colors.orange;

    return Colors.grey;
  }

  IconData _getActionIcon(String action) {
    if (action.contains('DELETE')) return Icons.delete_rounded;
    if (action.contains('ADD')) {
      if (action.contains('PAYMENT')) return Icons.payments_rounded;
      return Icons.add_circle_rounded;
    }
    if (action.contains('EDIT') || action.contains('UPDATE'))
      return Icons.edit_rounded;
    if (action.contains('LOGIN')) return Icons.login_rounded;
    if (action.contains('LOGOUT')) return Icons.logout_rounded;
    if (action.contains('PPPoE')) return Icons.router_rounded;
    if (action.contains('ERROR')) return Icons.error_outline_rounded;
    return Icons.info_rounded;
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM HH:mm').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _formatLogDetails(String details) {
    String displayMsg = details;

    // 1. Remove "->:"
    if (displayMsg.contains('->:')) {
      displayMsg = displayMsg.replaceAll('->:', '').trim();
    }

    // 2. Format PPPoE tags <pppoe-username>: status
    final pppoeRegex = RegExp(r'<pppoe-(.+?)>: (.+)');
    final match = pppoeRegex.firstMatch(displayMsg);

    if (match != null) {
      final username = match.group(1);
      final status = match.group(2)?.trim() ?? "";

      if (status.toLowerCase() == "connected") {
        displayMsg = "User $username terhubung.";
      } else if (status.toLowerCase() == "disconnected") {
        displayMsg = "User $username terputus.";
      } else {
        displayMsg = "User $username: $status";
      }
    } else {
      // Fallback cleanup
      if (displayMsg.contains('<') && displayMsg.contains('>')) {
        displayMsg = displayMsg.replaceAll('<', '').replaceAll('>', '');
      }
      if (displayMsg.contains('pppoe-')) {
        displayMsg = displayMsg.replaceAll('pppoe-', 'User ');
      }
    }

    // 3. Format Payment Logs
    // Pattern: "added payment: 1000000.0 (Cash) for user: username"
    if (displayMsg.toLowerCase().contains('added payment')) {
      final paymentRegex =
          RegExp(r'added payment: ([\d\.]+) \((.+?)\) for user: (.+)');
      final payMatch = paymentRegex.firstMatch(displayMsg);
      if (payMatch != null) {
        final amountStr = payMatch.group(1) ?? '0';
        final method = payMatch.group(2) ?? '-';
        final user = payMatch.group(3) ?? '-';

        try {
          final amount = double.parse(amountStr);
          final formattedAmount = NumberFormat.currency(
                  locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)
              .format(amount);

          displayMsg =
              "Pembayaran diterima $formattedAmount ($method) dari user $user";
        } catch (e) {
          // Fallback if parsing fails
          displayMsg = displayMsg
              .replaceAll('added payment:', 'Pembayaran:')
              .replaceAll('for user:', 'dari user:');
        }
      }
    }

    // Capitalize first letter
    if (displayMsg.isNotEmpty) {
      displayMsg = displayMsg[0].toUpperCase() + displayMsg.substring(1);
    }

    return displayMsg;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        const GradientContainer(child: SizedBox.expand()),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('System Logs'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            titleTextStyle: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          body: RefreshIndicator(
            onRefresh: () => _loadLogs(refresh: true),
            child: _logs.isEmpty && !_isLoading
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.7,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history,
                                  size: 64,
                                  color: isDark ? Colors.white24 : Colors.white54),
                              const SizedBox(height: 16),
                              Text(
                                'Belum ada aktivitas tercatat',
                                style: TextStyle(
                                  color: isDark ? Colors.white54 : Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _logs.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _logs.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child:
                                CircularProgressIndicator(color: Colors.white),
                          ),
                        );
                      }

                      final log = _logs[index];
                      final action = log['action'] ?? 'UNKNOWN';
                      final username = log['username'] ?? 'System';
                      final details = log['details'] ?? '';
                      final timestamp = log['timestamp'] ?? log['created_at'];
                      final actionColor = _getActionColor(action, details);
                      final formattedDetails = _formatLogDetails(details);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color:
                              isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Colored Indicator Strip
                                Container(
                                  width: 6,
                                  color: actionColor,
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: actionColor
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Icon(
                                                _getActionIcon(action),
                                                color: actionColor,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    action,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: actionColor,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.access_time,
                                                        size: 12,
                                                        color: isDark
                                                            ? Colors.white54
                                                            : Colors.grey[600],
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        _formatDate(timestamp),
                                                        style: TextStyle(
                                                          color: isDark
                                                              ? Colors.white54
                                                              : Colors
                                                                  .grey[600],
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        if (formattedDetails.isNotEmpty) ...[
                                          Text(
                                            formattedDetails,
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black87,
                                              fontSize: 14,
                                              height: 1.4,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                        ],
                                        Divider(
                                          height: 1,
                                          color: isDark
                                              ? Colors.grey[800]
                                              : Colors.grey[200],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.person_outline,
                                              size: 14,
                                              color: isDark
                                                  ? Colors.white54
                                                  : Colors.grey[600],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              username == 'System'
                                                  ? 'Mikrotik'
                                                  : 'Aplikasi ($username)',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark
                                                    ? Colors.white54
                                                    : Colors.grey[600],
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
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
          ),
        ),
      ],
    );
  }
}
