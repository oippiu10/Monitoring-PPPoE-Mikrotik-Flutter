import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/update_service.dart';
import '../services/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;
  final bool isRequired;
  final VoidCallback? onUpdate;

  const UpdateDialog({
    Key? key,
    required this.updateInfo,
    this.isRequired = false,
    this.onUpdate,
  }) : super(key: key);

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  bool _isInstalling = false;
  double _downloadProgress = 0.0;

  Future<void> _handleDownload() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final String apkPath = await UpdateService.downloadApk(
        widget.updateInfo.apkUrl,
        (downloaded, total) {
          if (mounted) {
            final progress = total > 0 ? downloaded / total : 0.0;
            setState(() {
              _downloadProgress = progress;
            });
            // Tampilkan notifikasi persistent dengan progress bar
            NotificationService().showDownloadProgress(
               (progress * 100).toInt(),
               version: widget.updateInfo.latestVersion.split('+')[0],
            );
          }
        },
      );

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isInstalling = true;
        });
      }

      // Hapus notifikasi saat masuk ke tahapan instalasi native
      await NotificationService().cancelDownloadNotification();
      await UpdateService.installApk(apkPath);
      
      if (mounted) {
        setState(() {
          _isInstalling = false;
        });
      }
    } catch (e) {
      await NotificationService().cancelDownloadNotification();
      
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isInstalling = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengunduh update: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    Widget dialogContent;
    if (_isDownloading || _isInstalling) {
      dialogContent = _buildInstallingDialog(context, isDark);
    } else {
      dialogContent = _buildUpdateInfoDialog(context, isDark);
    }

    // Kunci layar dialog (tidak bisa ditutup paksa / tombol back) saat download/install
    return PopScope(
      canPop: !_isDownloading && !_isInstalling,
      child: dialogContent,
    );
  }

  Widget _buildInstallingDialog(BuildContext context, bool isDark) {
    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      content: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isDownloading) ...[
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      value: _downloadProgress,
                      strokeWidth: 8,
                      backgroundColor: isDark ? Colors.blue.shade900 : Colors.blue.shade50,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDark ? Colors.blue.shade300 : Colors.blue.shade600,
                      ),
                    ),
                  ),
                  Text(
                    '${(_downloadProgress * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Mengunduh Update...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Mohon tunggu sebentar',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ] else ...[
              const SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(strokeWidth: 4),
              ),
              const SizedBox(height: 24),
              Text(
                'Membuka Installer...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateInfoDialog(BuildContext context, bool isDark) {
    final cleanVersion = widget.updateInfo.latestVersion.split('+')[0];
    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: widget.isRequired
                  ? (isDark ? Colors.orange.shade900 : Colors.orange.shade50)
                  : (isDark ? Colors.blue.shade900 : Colors.blue.shade50),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.isRequired
                  ? Icons.warning_rounded
                  : Icons.system_update_rounded,
              color: widget.isRequired ? Colors.orange : Colors.blue,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.isRequired ? 'Update Diperlukan' : 'Update Tersedia',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
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
            // Version info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.blue.shade900 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.blue.shade700 : Colors.blue.shade200,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Versi Terbaru:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color:
                          isDark ? Colors.blue.shade200 : Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'v$cleanVersion (Build ${widget.updateInfo.latestBuild})',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color:
                            isDark ? Colors.blue.shade100 : Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // File size removed as requested
            const SizedBox(height: 16),

            // Release notes
            if (widget.updateInfo.releaseNotes.isNotEmpty) ...[
              Text(
                'Perubahan:',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      isDark ? const Color(0xFF2D2D2D) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.updateInfo.releaseNotes.map((note) {
                    final version = note['version'] ?? '';
                    final date = note['date'] ?? '';
                    final notes = List<String>.from(note['notes'] ?? []);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.circle,
                              size: 8,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'v$version - $date',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        if (notes.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          ...notes.map((item) => Padding(
                                padding:
                                    const EdgeInsets.only(left: 16, top: 2),
                                child: Text(
                                  '• $item',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                ),
                              )),
                        ],
                        const SizedBox(height: 8),
                      ],
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Warning if required
            if (widget.isRequired)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Update ini wajib untuk melanjutkan penggunaan aplikasi.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'LEWATI',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (widget.updateInfo.updateType == 'minor')
          ElevatedButton.icon(
            onPressed: () {
              if (widget.onUpdate != null) {
                Navigator.of(context).pop();
                widget.onUpdate!();
              } else {
                _handleDownload();
              }
            },
            icon: const Icon(Icons.download, size: 18),
            label: const Text(
              'UNDUH APLIKASI',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.blue.shade700 : Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          )
        else
          ElevatedButton.icon(
            onPressed: () async {
              final url = Uri.parse("https://wa.me/6285931564236");
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.chat_bubble, size: 18),
            label: const Text(
              'HUBUNGI ADMIN',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
      ],
    );
  }
}
