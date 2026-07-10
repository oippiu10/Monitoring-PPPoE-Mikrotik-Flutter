import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/update_service.dart';
import '../services/notification_service.dart';

class ForceUpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;
  final bool isRequired;
  final VoidCallback? onUpdate;

  const ForceUpdateDialog({
    Key? key,
    required this.updateInfo,
    this.isRequired = false,
    this.onUpdate,
  }) : super(key: key);

  @override
  State<ForceUpdateDialog> createState() => _ForceUpdateDialogState();
}

class _ForceUpdateDialogState extends State<ForceUpdateDialog> {
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
    Color headerColor = widget.isRequired 
        ? Colors.orange.shade800 
        : Colors.blue.shade600;
        
    IconData headerIcon = widget.isRequired 
        ? Icons.warning_rounded 
        : Icons.system_update_rounded;
        
    String titleText = widget.isRequired 
        ? 'Pembaruan Versi Diperlukan' 
        : 'Update Tersedia';
        
    final cleanVersion = widget.updateInfo.latestVersion.split('+')[0];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2), 
              blurRadius: 15, 
              spreadRadius: 5
            )
          ]
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Color Block
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: headerColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20))
              ),
              child: Column(
                children: [
                  Icon(headerIcon, color: Colors.white, size: 48),
                  const SizedBox(height: 10),
                  Text(
                    titleText, 
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white, 
                      fontSize: 18, 
                      fontWeight: FontWeight.bold
                    )
                  ),
                ]
              )
            ),
            
            // Content Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Version info
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.blue.shade700.withOpacity(0.5) : Colors.blue.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Versi Terbaru:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.blue.shade200 : Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'v$cleanVersion',
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.blue.shade100 : Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Deskripsi wajib / opsional
                    Text(
                      widget.isRequired
                          ? 'Aplikasi ini memerlukan pembaruan agar dapat terus berfungsi.\n\nVersi yang Anda gunakan saat ini sudah tidak memenuhi standar kompatibilitas sistem kami. Untuk memastikan keamanan data dan performa yang optimal, silakan perbarui aplikasi Anda ke versi terbaru atau hubungi Administrator.'
                          : 'Pembaruan opsional tersedia untuk aplikasi Anda. Silakan unduh versi terbaru untuk menikmati perbaikan sistem dan fitur yang lebih baik.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[300] : Colors.grey[800],
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                  ],
                ),
              ),
            ),
            
            // Actions / Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  if (widget.updateInfo.updateType == 'minor')
                    ElevatedButton.icon(
                      onPressed: () {
                        _handleDownload();
                      },
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text(
                        'UNDUH APLIKASI',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 45),
                        backgroundColor: isDark ? Colors.blue.shade700 : Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
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
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 45),
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  if (!widget.isRequired)
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(double.infinity, 45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'LEWATI',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
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
