import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/mikrotik_provider.dart';
import '../widgets/gradient_container.dart';

import '../main.dart';
import 'dart:convert';
import 'dart:async';

class LogScreen extends StatefulWidget {
  const LogScreen({Key? key}) : super(key: key);

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _logs = [];
  bool _isRefreshing = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _fetchLogs(silent: true);
    });
  }

  Future<void> _fetchLogs({bool silent = false}) async {
    if (_isRefreshing) return;

    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    _isRefreshing = true;

    try {
      final provider = context.read<MikrotikProvider>();
      if (!mounted) return;

      final logs = await provider.service.getLog();
      if (!mounted) return;

      setState(() {
        _logs = logs;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _logs = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  void _showLogDetails(Map<String, dynamic> log) {
    try {
      final parsed = _parseLog(log);
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) {
          final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? Colors.white10 : Colors.grey[200]!,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: parsed['color'].withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          parsed['icon'],
                          color: parsed['color'],
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Log Details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Combined Info Section
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black12 : Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    isDark ? Colors.white10 : Colors.grey[200]!,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                // Time Section
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: _buildInfoRow(
                                    'Time',
                                    log['time'] ?? '-',
                                    Icons.access_time,
                                    isDark,
                                    parsed['color'],
                                  ),
                                ),
                                Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: isDark
                                      ? Colors.white10
                                      : Colors.grey[200]!,
                                ),
                                // Topics Section
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: _buildInfoRow(
                                    'Topics',
                                    log['topics'] ?? '-',
                                    Icons.label_outline,
                                    isDark,
                                    parsed['color'],
                                  ),
                                ),
                                Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: isDark
                                      ? Colors.white10
                                      : Colors.grey[200]!,
                                ),
                                // Message Section
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: _buildInfoRow(
                                    'Message',
                                    log['message'] ?? '-',
                                    Icons.message_outlined,
                                    isDark,
                                    parsed['color'],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Raw Data Section
                          Text(
                            'Raw Data',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black : Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    isDark ? Colors.white10 : Colors.grey[200]!,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              _formatJson(log),
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                color: isDark ? Colors.white70 : Colors.black87,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ).catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error showing log details: $error'),
            backgroundColor: Colors.red,
          ),
        );
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatJson(Map<String, dynamic> json) {
    try {
      return const JsonEncoder.withIndent('  ').convert(json);
    } catch (e) {
      return json.toString();
    }
  }

  Widget _buildInfoRow(String label, String value, IconData icon, bool isDark,
      Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: accentColor,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 15.5,
            height: 1.3,
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _parseLog(Map<String, dynamic> log) {
    try {
      final msg = log['message']?.toString() ?? '';
      final topics = log['topics']?.toString().toLowerCase() ?? '';
      IconData icon = Icons.info_outline;
      Color color = Colors.grey;

      // PPPoE events
      if (topics.contains('pppoe') || topics.contains('ppp')) {
        if (msg.contains('connected') && !msg.contains('disconnected')) {
          icon = Icons.check_circle_outline;
          color = const Color(0xFF00C853); // Material Green A700
        } else if (msg.contains('peer is not')) {
          icon = Icons.warning_amber_rounded;
          color = const Color(0xFFFF3D00); // Material Deep Orange A700
        } else if (msg.contains('disconnected')) {
          icon = Icons.highlight_off;
          color = const Color(0xFFD50000); // Material Red A700
        } else if (msg.contains('authenticated')) {
          icon = Icons.verified_user;
          color = const Color(0xFF2962FF); // Material Blue A700
        } else {
          icon = Icons.settings_ethernet;
          color = const Color(0xFFFF6D00); // Material Orange A700
        }
      }
      // Login/Logout events
      else if (msg.contains('logged in')) {
        icon = Icons.login_rounded;
        color = Colors.green;
      } else if (msg.contains('logged out')) {
        icon = Icons.logout_rounded;
        color = Colors.red;
      }
      // System events
      else if (topics.contains('system')) {
        if (msg.contains('error') || msg.contains('failed')) {
          icon = Icons.error_outline;
          color = Colors.red;
        } else if (msg.contains('warning')) {
          icon = Icons.warning_amber_rounded;
          color = Colors.orange;
        } else if (msg.contains('info')) {
          icon = Icons.info_outline;
          color = Colors.blue;
        } else if (msg.contains('success')) {
          icon = Icons.check_circle_outline;
          color = Colors.green;
        }
      }
      // Account/User events
      else if (topics.contains('account')) {
        if (msg.contains('created') || msg.contains('added')) {
          icon = Icons.person_add;
          color = Colors.green;
        } else if (msg.contains('removed') || msg.contains('deleted')) {
          icon = Icons.person_remove;
          color = Colors.red;
        } else if (msg.contains('modified') || msg.contains('changed')) {
          icon = Icons.manage_accounts;
          color = Colors.blue;
        } else {
          icon = Icons.person_outline;
          color = Colors.grey;
        }
      }
      // Interface events
      else if (topics.contains('interface')) {
        if (msg.contains('up') || msg.contains('enabled')) {
          icon = Icons.settings_ethernet;
          color = Colors.green;
        } else if (msg.contains('down') || msg.contains('disabled')) {
          icon = Icons.settings_ethernet;
          color = Colors.red;
        } else {
          icon = Icons.settings_ethernet;
          color = Colors.grey;
        }
      }
      // IP/DHCP events
      else if (topics.contains('ip') || topics.contains('dhcp')) {
        if (msg.contains('assigned') || msg.contains('leased')) {
          icon = Icons.wifi;
          color = Colors.green;
        } else if (msg.contains('released') || msg.contains('expired')) {
          icon = Icons.wifi_off;
          color = Colors.red;
        } else {
          icon = Icons.router;
          color = Colors.blue;
        }
      }
      // Firewall events
      else if (topics.contains('firewall')) {
        icon = Icons.security;
        color = msg.contains('blocked') || msg.contains('dropped')
            ? Colors.red
            : Colors.orange;
      }
      // DNS events
      else if (topics.contains('dns')) {
        icon = Icons.dns;
        color = Colors.blue;
      }
      // Default for unknown events
      else {
        icon = Icons.info_outline;
        color = Colors.grey;
      }

      return {
        'message': msg,
        'icon': icon,
        'color': color,
        'raw': log,
      };
    } catch (e) {
      return {
        'message': 'Unknown message',
        'icon': Icons.error_outline,
        'color': Colors.grey,
        'raw': log,
      };
    }
  }

  Future<void> _handleRefresh() async {
    try {
      await _fetchLogs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getBorderColor(Map<String, dynamic> parsed, bool isDark) {
    final msg = parsed['message']?.toString().toLowerCase() ?? '';
    if (msg.contains('connected') && !msg.contains('disconnected')) {
      return const Color(0xFF00C853).withOpacity(0.3); // Material Green A700
    } else if (msg.contains('peer is not')) {
      return const Color(0xFFFF3D00)
          .withOpacity(0.3); // Material Deep Orange A700
    } else if (msg.contains('disconnected')) {
      return const Color(0xFFD50000).withOpacity(0.3); // Material Red A700
    }
    return isDark ? Colors.white10 : Colors.grey[200]!;
  }

  Color _getTextColor(Map<String, dynamic> parsed, bool isDark) {
    final msg = parsed['message']?.toString().toLowerCase() ?? '';
    if (msg.contains('connected') && !msg.contains('disconnected')) {
      return const Color(0xFF00C853); // Material Green A700
    } else if (msg.contains('peer is not')) {
      return const Color(0xFFFF3D00); // Material Deep Orange A700
    } else if (msg.contains('disconnected')) {
      return const Color(0xFFD50000); // Material Red A700
    }
    return isDark ? Colors.white : Colors.black87;
  }

  bool _isConnectionEvent(Map<String, dynamic> parsed) {
    final msg = parsed['message']?.toString().toLowerCase() ?? '';
    return msg.contains('connected') ||
        msg.contains('disconnected') ||
        msg.contains('terminating');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Log',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _handleRefresh,
            ),
          ],
        ),
        body: _isLoading && _logs.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _handleRefresh,
                child: _error != null
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.7,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: Colors.red[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Error: $_error',
                                  style: TextStyle(
                                    color: Colors.red[300],
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _handleRefresh,
                                  child: const Text('Try Again'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : _logs.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(height: 64),
                                  Icon(
                                    Icons.search_off,
                                    size: 48,
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black38,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No logs found',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.black38,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: _logs.length,
                          itemBuilder: (context, index) {
                            final log = _logs[_logs.length - 1 - index];
                            final parsed = _parseLog(log);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.black12 : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _getBorderColor(parsed, isDark),
                                  width: 1,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _showLogDetails(log),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: parsed['color']
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            parsed['icon'],
                                            color: parsed['color'],
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                parsed['message'],
                                                style: TextStyle(
                                                  color: _getTextColor(
                                                      parsed, isDark),
                                                  fontSize: 14,
                                                  fontWeight:
                                                      _isConnectionEvent(parsed)
                                                          ? FontWeight.w500
                                                          : null,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 2,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                log['time'] ?? '-',
                                                style: TextStyle(
                                                  color: isDark
                                                      ? Colors.white60
                                                      : Colors.black54,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right,
                                          color: isDark
                                              ? Colors.white38
                                              : Colors.black38,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ),
    );
  }
}
