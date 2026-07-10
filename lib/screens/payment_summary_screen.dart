import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/gradient_container.dart';
import '../services/api_service.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/router_session_provider.dart';

class PaymentSummaryScreen extends StatefulWidget {
  const PaymentSummaryScreen({super.key});

  @override
  State<PaymentSummaryScreen> createState() => _PaymentSummaryScreenState();
}

class _PaymentSummaryScreenState extends State<PaymentSummaryScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<Map<String, dynamic>>> _summaryFuture;
  final currencyFormat = NumberFormat('#,##0', 'id_ID');
  bool showPrintPanel = false;
  bool isProcessing = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  void _showSnackBar(String message, {bool success = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _exportExcel(List<Map<String, dynamic>> summaryList) async {
    setState(() => isProcessing = true);
    try {
      // Simpan file ke direktori dokumen aplikasi (default, tanpa permission khusus)
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/ringkasan_pembayaran.xlsx');
      final excel = Excel.createExcel();
      final sheet = excel['Ringkasan'];
      // Header
      sheet.appendRow([
        TextCellValue('No'),
        TextCellValue('Bulan'),
        TextCellValue('Total Pembayaran'),
        TextCellValue('Jumlah Pembayaran')
      ]);
      // Data
      int totalCount = 0;
      double totalNominal = 0;
      for (var i = 0; i < summaryList.length; i++) {
        final item = summaryList[i];
        final month = item['month'] as int? ?? 0;
        final year = item['year'] as int? ?? 0;
        final total = (item['total'] ?? 0) is int
            ? (item['total'] ?? 0).toDouble()
            : (item['total'] ?? 0);
        final count = (item['count'] ?? 0) as int? ?? 0;
        totalNominal += total;
        totalCount += count;
        final monthName = _getMonthName(month, year);
        sheet.appendRow([
          IntCellValue(i + 1),
          TextCellValue(monthName),
          TextCellValue(_formatCurrency(total)),
          TextCellValue('$count pembayaran'),
        ]);
      }
      // Baris total
      sheet.appendRow([
        TextCellValue(''),
        TextCellValue('Total'),
        TextCellValue(_formatCurrency(totalNominal)),
        TextCellValue('$totalCount pembayaran'),
      ]);
      await file.writeAsBytes(excel.encode()!);
      _showSnackBar('Berhasil mengekspor ke ${file.path}');
      await OpenFile.open(file.path);
    } catch (e) {
      _showSnackBar('Gagal ekspor Excel: $e', success: false);
    } finally {
      setState(() => isProcessing = false);
    }
  }

  Future<void> _printSummary(List<Map<String, dynamic>> summaryList) async {
    final pdfDoc = await _buildPdfDocument(summaryList);
    await Printing.layoutPdf(
      onLayout: (format) => pdfDoc.save(),
    );
    _showSnackBar('Berhasil mengirim ke printer!');
  }

  Future<pw.Document> _buildPdfDocument(
      List<Map<String, dynamic>> summaryList) async {
    final pdf = pw.Document();
    final wmLogo = pw.MemoryImage(
        (await rootBundle.load('assets/Mikrotik-logo.png'))
            .buffer
            .asUint8List());
    pdf.addPage(pw.Page(
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          final now = DateTime.now();
          final dateStr = DateFormat('d MMMM yyyy HH:mm', 'id_ID').format(now);
          return pw.Stack(
            children: [
              // Watermark logo besar di tengah halaman
              pw.Positioned.fill(
                child: pw.Center(
                  child: pw.Opacity(
                    opacity: 0.07,
                    child: pw.Image(wmLogo, width: 350),
                  ),
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Text('Dicetak: $dateStr',
                          style: pw.TextStyle(
                              fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Center(
                    child: pw.Text('Ringkasan Pembayaran',
                        style: pw.TextStyle(
                            fontSize: 22, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.SizedBox(height: 24),
                  pw.Table(
                    border: pw.TableBorder.symmetric(
                        inside:
                            pw.BorderSide(width: 0.7, color: PdfColors.grey400),
                        outside:
                            pw.BorderSide(width: 1, color: PdfColors.grey400)),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(1),
                      1: const pw.FlexColumnWidth(2),
                      2: const pw.FlexColumnWidth(3),
                      3: const pw.FlexColumnWidth(2),
                    },
                    children: [
                      pw.TableRow(
                        decoration:
                            const pw.BoxDecoration(color: PdfColors.grey300),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('No',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Bulan',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Total Pembayaran',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Jumlah Pembayaran',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                        ],
                      ),
                      ...summaryList.asMap().entries.map((entry) {
                        final i = entry.key;
                        final item = entry.value;
                        final month = item['month'] as int? ?? 0;
                        final year = item['year'] as int? ?? 0;
                        final total = (item['total'] ?? 0) is int
                            ? (item['total'] ?? 0).toDouble()
                            : (item['total'] ?? 0);
                        final count = (item['count'] ?? 0) as int? ?? 0;
                        final monthName = _getMonthName(month, year);
                        final totalFormatted = _formatCurrency(total);
                        return pw.TableRow(
                          decoration: const pw.BoxDecoration(),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text('${i + 1}'),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(monthName),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(totalFormatted),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text('$count pembayaran'),
                            ),
                          ],
                        );
                      }), // Convert to list to avoid potential issues
                      // Baris total
                      (() {
                        final totalNominal =
                            summaryList.fold<double>(0.0, (sum, item) {
                          final total = (item['total'] ?? 0) is int
                              ? (item['total'] ?? 0).toDouble()
                              : (item['total'] ?? 0);
                          return sum + (total as num).toDouble();
                        });
                        final totalCount = summaryList.fold<int>(0,
                            (sum, item) => sum + ((item['count'] ?? 0) as int));
                        return pw.TableRow(
                          decoration:
                              const pw.BoxDecoration(color: PdfColors.grey200),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text('',
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text('Total',
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(_formatCurrency(totalNominal),
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text('$totalCount pembayaran',
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold)),
                            ),
                          ],
                        );
                      })(),
                    ],
                  ),
                  pw.SizedBox(height: 24),
                  pw.Divider(),
                  pw.Center(
                    child: pw.Text(
                        'Data diambil dari Aplikasi Mikrotik PPPoE Monitor',
                        style: pw.TextStyle(
                            fontSize: 11, color: PdfColors.grey700)),
                  ),
                ],
              ),
            ],
          );
        }));
    return pdf;
  }

  String _getMonthName(int month, int year) {
    if (month <= 0 || year <= 0) {
      return 'Invalid Date';
    }
    final date = DateTime(year, month);
    return DateFormat('MMMM yyyy', 'id_ID').format(date);
  }

  String _formatCurrency(dynamic value) {
    final formatter =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(value);
  }

  Future<void> openManageAllFilesAccess() async {
    final intent = AndroidIntent(
      action: 'android.settings.MANAGE_APP_ALL_FILES_ACCESS_PERMISSION',
      data: 'package:com.yahahahusein.mikrotikpppoemonitor',
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    await intent.launch();
  }

  void _initSummaryFuture() {
    final routerId =
        Provider.of<RouterSessionProvider>(context, listen: false).routerId;
    if (routerId == null) {
      setState(() {
        _summaryFuture = Future.error(
            'Silakan login router ulang (serial-number tidak ditemukan)');
      });
    } else {
      setState(() {
        _summaryFuture = ApiService.fetchPaymentSummary(routerId: routerId);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _initSummaryFuture(); // Ganti init/fetch dengan routerId dari Provider
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if dark mode is enabled
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return GradientContainer(
        child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Ringkasan Pembayaran'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Kembali',
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.white),
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Export Data',
            onPressed: () {
              setState(() {
                showPrintPanel = !showPrintPanel;
                if (showPrintPanel) {
                  _animationController.forward();
                } else {
                  _animationController.reverse();
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (showPrintPanel)
            SizeTransition(
              sizeFactor: _fadeAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black26
                              : Colors.grey.withOpacity(0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.file_download_outlined,
                              color: isDark
                                  ? Colors.blue.shade300
                                  : Colors.blue.shade700,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Export Data',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Pilih format ekspor untuk data ringkasan pembayaran',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.picture_as_pdf,
                                    color: Colors.white),
                                label: const Text('Export PDF'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD32F2F),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: isProcessing
                                    ? null
                                    : () async {
                                        try {
                                          final data = await _summaryFuture;
                                          await _printSummary(data);
                                        } catch (e) {
                                          _showSnackBar('Gagal export PDF: $e',
                                              success: false);
                                        }
                                      },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.table_chart,
                                    color: Colors.white),
                                label: const Text('Export Excel'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: isProcessing
                                    ? null
                                    : () async {
                                        try {
                                          final data = await _summaryFuture;
                                          await _exportExcel(data);
                                        } catch (e) {
                                          _showSnackBar(
                                              'Gagal export Excel: $e',
                                              success: false);
                                        }
                                      },
                              ),
                            ),
                          ],
                        ),
                        if (isProcessing)
                          const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: LinearProgressIndicator(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _summaryFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: isDark ? Colors.blue[200] : Colors.blue[600],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Memuat data ringkasan pembayaran...',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Mohon tunggu sebentar',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                } else if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.red.shade900
                                : Colors.red.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.error_outline,
                            color: isDark ? Colors.red.shade300 : Colors.red,
                            size: 50,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('Gagal memuat data',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.red.shade200 : Colors.red,
                            )),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            snapshot.error.toString(),
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: 150,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _initSummaryFuture();
                              });
                            },
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Coba Lagi'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isDark ? Colors.grey[700] : Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.grey.shade900
                                : Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.payment_outlined,
                            color: isDark ? Colors.grey.shade600 : Colors.grey,
                            size: 50,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('Tidak ada data pembayaran.',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black54,
                            )),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'Belum ada pembayaran yang dicatat.',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white54 : Colors.black38,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: 150,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _initSummaryFuture();
                              });
                            },
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Refresh'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isDark ? Colors.grey[700] : Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final summaryList = snapshot.data!;

                // Calculate totals for header
                final totalNominal = summaryList.fold<double>(0.0, (sum, item) {
                  final total = (item['total'] ?? 0) is int
                      ? (item['total'] ?? 0).toDouble()
                      : (item['total'] ?? 0);
                  return sum + (total as num).toDouble();
                });
                final totalCount = summaryList.fold<int>(
                    0, (sum, item) => sum + ((item['count'] ?? 0) as int));

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blueGrey.withOpacity(0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Icon(Icons.summarize,
                                color: isDark
                                    ? Colors.blue.shade300
                                    : const Color(0xFF1565C0)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Semua Pembayaran',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Rp ${currencyFormat.format(totalNominal)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.green.shade300
                                          : const Color(0xFF2E7D32),
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.blue.shade900
                                    : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$totalCount pembayaran',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.blue.shade300
                                      : Colors.blue.shade700,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // List of monthly summaries
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                        itemCount: summaryList.length,
                        separatorBuilder: (context, i) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final item = summaryList[i];
                          final month = item['month'] as int? ?? 0;
                          final year = item['year'] as int? ?? 0;
                          final monthName = _getMonthName(month, year);
                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      MonthlyPaymentDetailScreen(
                                    month: month,
                                    year: year,
                                    isDark: isDark,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blueGrey.withOpacity(0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                  width: 1,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.blue.shade900
                                          : Colors.blue.shade50,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.calendar_month,
                                        color: isDark
                                            ? Colors.blue.shade300
                                            : Colors.blue.shade700,
                                        size: 24),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(monthName,
                                            style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                                color: isDark
                                                    ? Colors.blue.shade200
                                                    : const Color(0xFF1565C0))),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 12,
                                          runSpacing: 6,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? Colors.green.shade900
                                                    : Colors.green.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.payments,
                                                      size: 14,
                                                      color: isDark
                                                          ? Colors
                                                              .green.shade300
                                                          : Colors
                                                              .green.shade700),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                      'Rp ${currencyFormat.format(item['total'] ?? 0)}',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: isDark
                                                              ? Colors.green
                                                                  .shade200
                                                              : const Color(
                                                                  0xFF388E3C),
                                                          fontSize: 14)),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? Colors.orange.shade900
                                                    : Colors.orange.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                      Icons.confirmation_number,
                                                      size: 14,
                                                      color: isDark
                                                          ? Colors
                                                              .orange.shade300
                                                          : Colors
                                                              .orange.shade700),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                      '${item['count'] ?? 0} pembayaran',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: isDark
                                                              ? Colors.orange
                                                                  .shade200
                                                              : const Color(
                                                                  0xFFF57C00),
                                                          fontSize: 14)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.arrow_forward_ios,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : const Color(0xFF90CAF9),
                                      size: 18),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ));
  }
}

class MonthlyPaymentDetailScreen extends StatefulWidget {
  final int month;
  final int year;
  final bool isDark;

  const MonthlyPaymentDetailScreen({
    super.key,
    required this.month,
    required this.year,
    this.isDark = false,
  });

  @override
  State<MonthlyPaymentDetailScreen> createState() =>
      _MonthlyPaymentDetailScreenState();
}

class _MonthlyPaymentDetailScreenState extends State<MonthlyPaymentDetailScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<Map<String, dynamic>>> _paymentsFuture;
  bool showPrintPanel = false;
  bool isProcessing = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final currencyFormat = NumberFormat('#,##0', 'id_ID');

  @override
  void initState() {
    super.initState();
    _initPaymentsFuture();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _initPaymentsFuture() {
    final routerId =
        Provider.of<RouterSessionProvider>(context, listen: false).routerId;
    if (routerId != null) {
      setState(() {
        _paymentsFuture = ApiService.fetchAllPaymentsForMonthYear(
            widget.month, widget.year,
            routerId: routerId);
      });
    }
  }

  void _showSnackBar(String message, {bool success = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _exportExcel(List<Map<String, dynamic>> payments) async {
    setState(() => isProcessing = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final monthName = DateFormat('MMMM_yyyy', 'id_ID')
          .format(DateTime(widget.year, widget.month));
      final file = File('${dir.path}/pembayaran_$monthName.xlsx');
      final excel = Excel.createExcel();
      final sheet = excel['Pembayaran'];

      // Header
      sheet.appendRow([
        TextCellValue('No'),
        TextCellValue('Tanggal'),
        TextCellValue('Username'),
        TextCellValue('Metode'),
        TextCellValue('Jumlah'),
        TextCellValue('Catatan'),
      ]);

      // Data
      double totalNominal = 0;
      for (var i = 0; i < payments.length; i++) {
        final p = payments[i];
        final username = (p['username'] ?? p['user_id'] ?? '-').toString();
        final amount = double.tryParse(p['amount'].toString()) ?? 0;
        final method = (p['method'] ?? '-').toString();
        final date = (p['payment_date'] ?? '-').toString();
        final note = (p['note'] ?? '').toString();

        totalNominal += amount;

        sheet.appendRow([
          IntCellValue(i + 1),
          TextCellValue(date),
          TextCellValue(username),
          TextCellValue(method),
          DoubleCellValue(amount),
          TextCellValue(note),
        ]);
      }

      // Footer Total
      sheet.appendRow([
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue('Total'),
        DoubleCellValue(totalNominal),
        TextCellValue(''),
      ]);

      await file.writeAsBytes(excel.encode()!);
      _showSnackBar('Berhasil mengekspor ke ${file.path}');
      await OpenFile.open(file.path);
    } catch (e) {
      _showSnackBar('Gagal ekspor Excel: $e', success: false);
    } finally {
      setState(() => isProcessing = false);
    }
  }

  Future<void> _printSummary(List<Map<String, dynamic>> payments) async {
    final pdfDoc = await _buildPdfDocument(payments);
    await Printing.layoutPdf(
      onLayout: (format) => pdfDoc.save(),
    );
  }

  Future<pw.Document> _buildPdfDocument(
      List<Map<String, dynamic>> payments) async {
    final pdf = pw.Document();
    final wmLogo = pw.MemoryImage(
        (await rootBundle.load('assets/Mikrotik-logo.png'))
            .buffer
            .asUint8List());

    final monthYearTitle = DateFormat('MMMM yyyy', 'id_ID')
        .format(DateTime(widget.year, widget.month));

    pdf.addPage(pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          buildBackground: (context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Center(
              child: pw.Opacity(
                opacity: 0.07,
                child: pw.Image(wmLogo, width: 350),
              ),
            ),
          ),
        ),
        build: (context) {
          return [
            pw.Center(
              child: pw.Text('Laporan Pembayaran - $monthYearTitle',
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 24),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(35), // No (Widened)
                1: const pw.FixedColumnWidth(80), // Tanggal
                2: const pw.FlexColumnWidth(1.5), // Username
                3: const pw.FixedColumnWidth(50), // Metode
                4: const pw.FlexColumnWidth(1), // Keterangan (Swapped)
                5: const pw.FixedColumnWidth(90), // Jumlah (Swapped)
              },
              children: [
                // Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _buildPdfCell('No', isHeader: true),
                    _buildPdfCell('Tanggal', isHeader: true),
                    _buildPdfCell('Username', isHeader: true),
                    _buildPdfCell('Metode', isHeader: true),
                    _buildPdfCell('Keterangan', isHeader: true), // Swapped
                    _buildPdfCell('Jumlah', isHeader: true), // Swapped
                  ],
                ),
                // Data
                ...payments.asMap().entries.map((entry) {
                  final i = entry.key;
                  final p = entry.value;
                  final username =
                      (p['username'] ?? p['user_id'] ?? '-').toString();
                  final amount = double.tryParse(p['amount'].toString()) ?? 0;
                  final method = (p['method'] ?? '-').toString();
                  final date = (p['payment_date'] ?? '-').toString();
                  final note = (p['note'] ?? '').toString();

                  return pw.TableRow(
                    children: [
                      _buildPdfCell('${i + 1}'),
                      _buildPdfCell(date),
                      _buildPdfCell(username),
                      _buildPdfCell(method),
                      _buildPdfCell(note), // Swapped
                      _buildPdfCell(
                          NumberFormat.currency(
                                  locale: 'id_ID',
                                  symbol: 'Rp ',
                                  decimalDigits: 0)
                              .format(amount),
                          alignRight: true), // Swapped
                    ],
                  );
                }),
                // Total
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildPdfCell(''),
                    _buildPdfCell(''),
                    _buildPdfCell(''),
                    _buildPdfCell(''),
                    _buildPdfCell('Total', isHeader: true, alignRight: true),
                    _buildPdfCell(
                        NumberFormat.currency(
                                locale: 'id_ID',
                                symbol: 'Rp ',
                                decimalDigits: 0)
                            .format(payments
                                  .where((p) => p['method']?.toString().toLowerCase() != 'titipan')
                                  .fold<double>(
                                      0,
                                      (sum, p) =>
                                          sum +
                                          (double.tryParse(p['amount']?.toString() ?? '0') ?? 0))),
                        alignRight: true,
                        isHeader: true),
                  ],
                ),
              ],
            )
          ];
        }));
    return pdf;
  }

  pw.Widget _buildPdfCell(String text,
      {bool isHeader = false, bool alignRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: 10,
        ),
      ),
    );
  }

  void _showPaymentDetailDialog(Map<String, dynamic> p) {
    final username = (p['username'] ?? p['user_id'] ?? '-').toString();
    final nominal = double.tryParse(p['amount'].toString()) ?? 0;
    final method = (p['method'] ?? '-').toString();
    final paymentDate = p['payment_date'] ?? '-';
    final note = (p['note'] ?? '-').toString();
    final admin = (p['admin_name'] ?? '-').toString();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Detail Pembayaran',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: widget.isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            _buildDetailRow(Icons.person, 'Username', username),
            _buildDetailRow(Icons.monetization_on, 'Jumlah',
                'Rp ${currencyFormat.format(nominal)}'),
            _buildDetailRow(Icons.calendar_today, 'Tanggal', paymentDate),
            _buildDetailRow(Icons.payment, 'Metode', method),
            _buildDetailRow(Icons.note, 'Catatan', note),
            _buildDetailRow(Icons.admin_panel_settings, 'Admin', admin),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Tutup'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? Colors.blue.withOpacity(0.1)
                  : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color:
                  widget.isDark ? Colors.blue.shade300 : Colors.blue.shade700,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.isDark
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: widget.isDark ? Colors.white : Colors.black87,
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
  Widget build(BuildContext context) {
    final String monthYearTitle = DateFormat('MMMM yyyy', 'id_ID')
        .format(DateTime(widget.year, widget.month));
    final routerId =
        Provider.of<RouterSessionProvider>(context, listen: false).routerId;

    if (routerId == null) {
      return Scaffold(
        appBar: AppBar(
            title: Text(monthYearTitle),
            backgroundColor: Theme.of(context).primaryColor),
        body: const Center(child: Text('Silakan login router ulang')),
      );
    }

    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(monthYearTitle),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme:
              IconThemeData(color: widget.isDark ? Colors.white : Colors.white),
          titleTextStyle: TextStyle(
            color: widget.isDark ? Colors.white : Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'Export Data',
              onPressed: () {
                setState(() {
                  showPrintPanel = !showPrintPanel;
                  if (showPrintPanel) {
                    _animationController.forward();
                  } else {
                    _animationController.reverse();
                  }
                });
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Export Panel
            if (showPrintPanel)
              SizeTransition(
                sizeFactor: _fadeAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: widget.isDark
                            ? const Color(0xFF2D2D2D)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: widget.isDark
                                ? Colors.black26
                                : Colors.grey.withOpacity(0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Export Data Bulan Ini',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color:
                                  widget.isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                height: 45,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.picture_as_pdf,
                                      color: Colors.white),
                                  label: const Text('Export PDF'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFD32F2F),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: isProcessing
                                      ? null
                                      : () async {
                                          try {
                                            final data = await _paymentsFuture;
                                            await _printSummary(data);
                                          } catch (e) {
                                            _showSnackBar(
                                                'Gagal export PDF: $e',
                                                success: false);
                                          }
                                        },
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 45,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.table_chart,
                                      color: Colors.white),
                                  label: const Text('Export Excel'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade700,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: isProcessing
                                      ? null
                                      : () async {
                                          try {
                                            final data = await _paymentsFuture;
                                            await _exportExcel(data);
                                          } catch (e) {
                                            _showSnackBar(
                                                'Gagal export Excel: $e',
                                                success: false);
                                          }
                                        },
                                ),
                              ),
                            ],
                          ),
                          if (isProcessing)
                            const Padding(
                              padding: EdgeInsets.only(top: 16),
                              child: LinearProgressIndicator(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _paymentsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color:
                            widget.isDark ? Colors.blue[200] : Colors.blue[600],
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('Tidak ada data'));
                  }

                  final payments = snapshot.data!;
                  final totalAmount = payments
                      .where((p) => p['method']?.toString().toLowerCase() != 'titipan')
                      .fold<double>(0.0, (sum, p) {
                    return sum +
                        (double.tryParse(p['amount']?.toString() ?? '0') ?? 0);
                  });

                  return Column(
                    children: [
                      // Total Summary Card
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blueGrey.withOpacity(0.06),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(Icons.analytics,
                                  color: widget.isDark
                                      ? Colors.blue.shade300
                                      : const Color(0xFF1565C0)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Total Bulan Ini',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: widget.isDark
                                            ? Colors.white
                                            : Colors.black87,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Rp ${currencyFormat.format(totalAmount)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: widget.isDark
                                            ? Colors.green.shade300
                                            : const Color(0xFF2E7D32),
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: widget.isDark
                                      ? Colors.blue.shade900
                                      : Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${payments.length} pembayaran',
                                  style: TextStyle(
                                    color: widget.isDark
                                        ? Colors.blue.shade300
                                        : Colors.blue.shade700,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // List Items
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 18),
                          itemCount: payments.length,
                          itemBuilder: (context, i) {
                            final p = payments[i];
                            final username =
                                (p['username'] ?? p['user_id'] ?? '-')
                                    .toString();
                            final nominal =
                                double.tryParse(p['amount'].toString()) ?? 0;
                            final method = (p['method'] ?? '-').toString();
                            final paymentDate = p['payment_date'] ?? '-';
                            final note = (p['note'] ?? '').toString();
                            final avatarColor = Colors
                                .primaries[
                                    username.hashCode % Colors.primaries.length]
                                .shade300;

                            return InkWell(
                              onTap: () => _showPaymentDetailDialog(p),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blueGrey.withOpacity(0.08),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: avatarColor,
                                            radius: 24,
                                            child: Text(
                                              username.isNotEmpty
                                                  ? username[0].toUpperCase()
                                                  : '-',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 20,
                                                  color: Colors.white),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  username,
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 16,
                                                      color: widget.isDark
                                                          ? Colors.blue.shade200
                                                          : const Color(
                                                              0xFF1565C0)),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Rp ${currencyFormat.format(nominal)}',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 18,
                                                      color: widget.isDark
                                                          ? Colors
                                                              .green.shade300
                                                          : const Color(
                                                              0xFF43A047)),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: method.toLowerCase() ==
                                                      'cash'
                                                  ? (widget.isDark
                                                      ? Colors.green.shade900
                                                      : Colors.green.shade100)
                                                  : (widget.isDark
                                                      ? Colors.blue.shade900
                                                      : Colors.blue.shade100),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              method,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: method.toLowerCase() ==
                                                        'cash'
                                                    ? (widget.isDark
                                                        ? Colors.green.shade300
                                                        : Colors.green.shade700)
                                                    : (widget.isDark
                                                        ? Colors.blue.shade300
                                                        : Colors.blue.shade700),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 0, 16, 16),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: widget.isDark
                                              ? const Color(0xFF2D2D2D)
                                              : Colors.grey.shade50,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(Icons.calendar_today,
                                                    size: 16,
                                                    color: widget.isDark
                                                        ? Colors.grey.shade400
                                                        : Colors
                                                            .blueGrey.shade300),
                                                const SizedBox(width: 8),
                                                Text(paymentDate,
                                                    style: TextStyle(
                                                        fontSize: 14,
                                                        color: widget.isDark
                                                            ? Colors.white70
                                                            : Colors.black87)),
                                                const Spacer(),
                                              ],
                                            ),
                                            if (note.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 10),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Icon(Icons.sticky_note_2,
                                                        size: 16,
                                                        color: widget.isDark
                                                            ? Colors
                                                                .orange.shade300
                                                            : Colors.orange
                                                                .shade400),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(note,
                                                          style: TextStyle(
                                                              fontSize: 13,
                                                              color: widget.isDark
                                                                  ? Colors
                                                                      .white70
                                                                  : Colors
                                                                      .black87)),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
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
}
