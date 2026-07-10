import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../widgets/gradient_container.dart';
import '../services/expense_service.dart';
import '../providers/router_session_provider.dart';
import '../main.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';
import '../models/expense_model.dart';

class ExpenseSummaryScreen extends StatefulWidget {
  const ExpenseSummaryScreen({Key? key}) : super(key: key);

  @override
  State<ExpenseSummaryScreen> createState() => _ExpenseSummaryScreenState();
}

class _ExpenseSummaryScreenState extends State<ExpenseSummaryScreen> with SingleTickerProviderStateMixin {
  late Future<List<Map<String, dynamic>>> _summaryFuture;
  final currencyFormat = NumberFormat('#,##0', 'id_ID');
  
  bool showPrintPanel = false;
  bool isProcessing = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initSummaryFuture();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool success = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  void _initSummaryFuture() {
    final routerId = Provider.of<RouterSessionProvider>(context, listen: false).routerId;
    if (routerId == null) {
      setState(() {
        _summaryFuture = Future.error('Silakan login router ulang');
      });
    } else {
      setState(() {
        _summaryFuture = ExpenseService.fetchExpenseSummary(routerId);
      });
    }
  }

  String _getMonthName(int month, int year) {
    if (month <= 0 || year <= 0) return 'Invalid Date';
    final date = DateTime(year, month);
    return DateFormat('MMMM yyyy', 'id_ID').format(date);
  }

  String _formatCurrency(dynamic value) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(value);
  }

  Future<void> _exportExcel(List<Map<String, dynamic>> summaryList) async {
    setState(() => isProcessing = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/ringkasan_pengeluaran.xlsx');
      final excel = Excel.createExcel();
      final sheet = excel['Ringkasan'];
      
      sheet.appendRow([
        TextCellValue('No'),
        TextCellValue('Bulan'),
        TextCellValue('Total Pengeluaran'),
        TextCellValue('Jumlah Pengeluaran')
      ]);
      
      int totalCount = 0;
      double totalNominal = 0;
      for (var i = 0; i < summaryList.length; i++) {
        final item = summaryList[i];
        final month = item['month'] as int? ?? 0;
        final year = item['year'] as int? ?? 0;
        final total = (item['total'] ?? 0) is int ? (item['total'] ?? 0).toDouble() : (item['total'] ?? 0);
        final count = (item['count'] ?? 0) as int? ?? 0;
        totalNominal += total;
        totalCount += count;
        final monthName = _getMonthName(month, year);
        sheet.appendRow([
          IntCellValue(i + 1),
          TextCellValue(monthName),
          TextCellValue(_formatCurrency(total)),
          TextCellValue('$count pengeluaran'),
        ]);
      }
      
      sheet.appendRow([
        TextCellValue(''),
        TextCellValue('Total'),
        TextCellValue(_formatCurrency(totalNominal)),
        TextCellValue('$totalCount pengeluaran'),
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
    setState(() => isProcessing = true);
    try {
      final pdfDoc = await _buildPdfDocument(summaryList);
      await Printing.layoutPdf(onLayout: (format) => pdfDoc.save());
      _showSnackBar('Berhasil mengirim ke printer!');
    } catch (e) {
      _showSnackBar('Gagal mencetak: $e', success: false);
    } finally {
      setState(() => isProcessing = false);
    }
  }

  Future<pw.Document> _buildPdfDocument(List<Map<String, dynamic>> summaryList) async {
    final pdf = pw.Document();
    final wmLogo = pw.MemoryImage((await rootBundle.load('assets/Mikrotik-logo.png')).buffer.asUint8List());
    
    pdf.addPage(pw.Page(
      margin: const pw.EdgeInsets.all(32),
      build: (context) {
        final now = DateTime.now();
        final dateStr = DateFormat('d MMMM yyyy HH:mm', 'id_ID').format(now);
        return pw.Stack(
          children: [
            pw.Positioned.fill(
              child: pw.Center(
                child: pw.Opacity(opacity: 0.07, child: pw.Image(wmLogo, width: 350)),
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [pw.Text('Dicetak: $dateStr', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700))],
                ),
                pw.SizedBox(height: 8),
                pw.Center(child: pw.Text('Ringkasan Pengeluaran', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold))),
                pw.SizedBox(height: 24),
                pw.Table(
                  border: pw.TableBorder.symmetric(
                    inside: pw.BorderSide(width: 0.7, color: PdfColors.grey400),
                    outside: pw.BorderSide(width: 1, color: PdfColors.grey400)
                  ),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(3),
                    3: const pw.FlexColumnWidth(2),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('No', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Bulan', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Total Pengeluaran', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Jumlah Pengeluaran', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      ],
                    ),
                    ...summaryList.asMap().entries.map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      final month = item['month'] as int? ?? 0;
                      final year = item['year'] as int? ?? 0;
                      final total = (item['total'] ?? 0) is int ? (item['total'] ?? 0).toDouble() : (item['total'] ?? 0);
                      final count = (item['count'] ?? 0) as int? ?? 0;
                      return pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${i + 1}')),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(_getMonthName(month, year))),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(_formatCurrency(total))),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('$count pengeluaran')),
                        ],
                      );
                    }),
                    (() {
                      final totalNominal = summaryList.fold<double>(0.0, (sum, item) {
                        final total = (item['total'] ?? 0) is int ? (item['total'] ?? 0).toDouble() : (item['total'] ?? 0);
                        return sum + (total as num).toDouble();
                      });
                      final totalCount = summaryList.fold<int>(0, (sum, item) => sum + ((item['count'] ?? 0) as int));
                      return pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(_formatCurrency(totalNominal), style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('$totalCount pengeluaran', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        ],
                      );
                    })(),
                  ],
                ),
                pw.SizedBox(height: 24),
                pw.Divider(),
                pw.Center(child: pw.Text('Data diambil dari Aplikasi Mikrotik PPPoE Monitor', style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700))),
              ],
            ),
          ],
        );
      }
    ));
    return pdf;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Ringkasan Pengeluaran'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          titleTextStyle: const TextStyle(
            color: Colors.white,
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? Colors.black26 : Colors.grey.withOpacity(0.1),
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
                              Icon(Icons.file_download_outlined, color: isDark ? Colors.blue.shade300 : Colors.blue.shade700, size: 24),
                              const SizedBox(width: 12),
                              Text('Export Data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text('Pilih format ekspor untuk data ringkasan pengeluaran', style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54)),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                                  label: const Text('Export PDF'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFD32F2F),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: isProcessing ? null : () async {
                                    try {
                                      final data = await _summaryFuture;
                                      await _printSummary(data);
                                    } catch (e) {
                                      _showSnackBar('Gagal export PDF: $e', success: false);
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
                                  icon: const Icon(Icons.table_chart, color: Colors.white),
                                  label: const Text('Export Excel'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: isProcessing ? null : () async {
                                    try {
                                      final data = await _summaryFuture;
                                      await _exportExcel(data);
                                    } catch (e) {
                                      _showSnackBar('Gagal export Excel: $e', success: false);
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
                    return Center(child: CircularProgressIndicator(color: isDark ? Colors.blue[200] : Colors.blue[600]));
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade300, size: 50),
                          const SizedBox(height: 16),
                          Text('Gagal memuat data', style: TextStyle(color: Colors.red.shade300, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(snapshot.error.toString(), style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _initSummaryFuture,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.money_off, color: isDark ? Colors.grey.shade600 : Colors.grey, size: 50),
                          const SizedBox(height: 16),
                          Text('Belum ada data pengeluaran.', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 16)),
                        ],
                      ),
                    );
                  }

                  final summaryList = snapshot.data!;
                  final totalNominal = summaryList.fold<double>(0.0, (sum, item) {
                    final t = (item['total'] ?? 0) is int ? (item['total'] ?? 0).toDouble() : (item['total'] ?? 0);
                    return sum + (t as num).toDouble();
                  });
                  final totalCount = summaryList.fold<int>(0, (sum, item) => sum + ((item['count'] ?? 0) as int));

                  return Column(
                    children: [
                      // Top Total Card
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(color: isDark ? Colors.black26 : Colors.blueGrey.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                            border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, width: 1),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(Icons.shopping_cart_checkout, color: isDark ? Colors.red.shade300 : const Color(0xFFD32F2F)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Total Semua Pengeluaran', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87, fontSize: 13)),
                                    const SizedBox(height: 4),
                                    Text(_formatCurrency(totalNominal), style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.red.shade300 : const Color(0xFFD32F2F), fontSize: 16)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: isDark ? Colors.red.shade900 : Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                                child: Text('$totalCount catatan', style: TextStyle(color: isDark ? Colors.red.shade300 : Colors.red.shade700, fontWeight: FontWeight.w600, fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Monthly List
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                          itemCount: summaryList.length,
                          separatorBuilder: (context, i) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final item = summaryList[i];
                            final month = item['month'] as int? ?? 0;
                            final year = item['year'] as int? ?? 0;
                            final monthName = _getMonthName(month, year);
                            final total = (item['total'] ?? 0) is int ? (item['total'] ?? 0).toDouble() : (item['total'] ?? 0);
                            final count = (item['count'] ?? 0) as int? ?? 0;

                            return Container(
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(color: isDark ? Colors.black26 : Colors.blueGrey.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4)),
                                ],
                                border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, width: 1),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => MonthlyExpenseDetailScreen(
                                          month: month,
                                          year: year,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(color: isDark ? Colors.red.shade900.withOpacity(0.3) : Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                                          child: Icon(Icons.calendar_month, color: isDark ? Colors.red.shade200 : Colors.red.shade400, size: 24),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(monthName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : const Color(0xFF1E3A8A))),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Icon(Icons.money_off, size: 14, color: isDark ? Colors.red.shade300 : const Color(0xFFD32F2F)),
                                                  const SizedBox(width: 4),
                                                  Text(_formatCurrency(total), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.red.shade300 : const Color(0xFFC62828))),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(Icons.receipt_long, size: 14, color: isDark ? Colors.orange.shade300 : Colors.orange.shade700),
                                                  const SizedBox(width: 4),
                                                  Text('$count pengeluaran', style: TextStyle(fontSize: 12, color: isDark ? Colors.orange.shade300 : Colors.orange.shade800, fontWeight: FontWeight.w500)),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(Icons.chevron_right, color: isDark ? Colors.grey.shade400 : Colors.grey.shade400),
                                      ],
                                    ),
                                  ),
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

class MonthlyExpenseDetailScreen extends StatefulWidget {
  final int month;
  final int year;

  const MonthlyExpenseDetailScreen({
    Key? key,
    required this.month,
    required this.year,
  }) : super(key: key);

  @override
  State<MonthlyExpenseDetailScreen> createState() => _MonthlyExpenseDetailScreenState();
}

class _MonthlyExpenseDetailScreenState extends State<MonthlyExpenseDetailScreen> with SingleTickerProviderStateMixin {
  late Future<List<ExpenseModel>> _expensesFuture;
  final currencyFormat = NumberFormat('#,##0', 'id_ID');
  
  bool showPrintPanel = false;
  bool isProcessing = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initExpensesFuture();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool success = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: success ? Colors.green : Colors.red),
    );
  }

  void _initExpensesFuture() {
    final routerId = Provider.of<RouterSessionProvider>(context, listen: false).routerId;
    if (routerId == null) {
      setState(() {
        _expensesFuture = Future.error('Silakan login router ulang');
      });
    } else {
      setState(() {
        _expensesFuture = ExpenseService.getExpenses(routerId, widget.month, widget.year).then((data) {
          // Sort newest first
          data.sort((a, b) {
            int cmp = b.spentAt.compareTo(a.spentAt);
            if (cmp == 0) return b.id.compareTo(a.id);
            return cmp;
          });
          return data;
        });
      });
    }
  }

  IconData _getCategoryIcon(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('bensin') || lower.contains('transport')) return Icons.local_gas_station;
    if (lower.contains('operasional') || lower.contains('teknis')) return Icons.handyman;
    if (lower.contains('alat') || lower.contains('barang')) return Icons.inventory_2;
    if (lower.contains('gaji') || lower.contains('upah')) return Icons.payments;
    if (lower.contains('makan') || lower.contains('konsumsi')) return Icons.restaurant;
    if (lower.contains('listrik') || lower.contains('internet')) return Icons.bolt;
    return Icons.receipt_long;
  }

  Future<void> _exportExcel(List<ExpenseModel> expenses) async {
    setState(() => isProcessing = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/detail_pengeluaran_${widget.month}_${widget.year}.xlsx');
      final excel = Excel.createExcel();
      final sheet = excel['Detail'];
      
      sheet.appendRow([
        TextCellValue('No'),
        TextCellValue('Tanggal'),
        TextCellValue('Kategori'),
        TextCellValue('Nominal'),
        TextCellValue('Keterangan')
      ]);
      
      double totalNominal = 0;
      for (var i = 0; i < expenses.length; i++) {
        final item = expenses[i];
        totalNominal += item.amount;
        final date = DateFormat('yyyy-MM-dd HH:mm:ss').format(item.spentAt);
        sheet.appendRow([
          IntCellValue(i + 1),
          TextCellValue(date),
          TextCellValue(item.category),
          TextCellValue('Rp ${currencyFormat.format(item.amount)}'),
          TextCellValue(item.note),
        ]);
      }
      
      sheet.appendRow([
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue('Total'),
        TextCellValue('Rp ${currencyFormat.format(totalNominal)}'),
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

  Future<void> _printSummary(List<ExpenseModel> expenses) async {
    setState(() => isProcessing = true);
    try {
      final pdfDoc = await _buildPdfDocument(expenses);
      await Printing.layoutPdf(onLayout: (format) => pdfDoc.save());
      _showSnackBar('Berhasil mengirim ke printer!');
    } catch (e) {
      _showSnackBar('Gagal mencetak: $e', success: false);
    } finally {
      setState(() => isProcessing = false);
    }
  }

  pw.Widget _buildPdfCell(String text, {bool isHeader = false, bool alignRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: 10),
      ),
    );
  }

  Future<pw.Document> _buildPdfDocument(List<ExpenseModel> expenses) async {
    final pdf = pw.Document();
    final wmLogo = pw.MemoryImage((await rootBundle.load('assets/Mikrotik-logo.png')).buffer.asUint8List());
    
    pdf.addPage(pw.Page(
      margin: const pw.EdgeInsets.all(32),
      build: (context) {
        final now = DateTime.now();
        final dateStr = DateFormat('d MMMM yyyy HH:mm', 'id_ID').format(now);
        final monthStr = DateFormat('MMMM yyyy', 'id_ID').format(DateTime(widget.year, widget.month));
        return pw.Stack(
          children: [
            pw.Positioned.fill(
              child: pw.Center(
                child: pw.Opacity(opacity: 0.07, child: pw.Image(wmLogo, width: 350)),
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [pw.Text('Dicetak: $dateStr', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700))],
                ),
                pw.SizedBox(height: 8),
                pw.Center(child: pw.Text('Detail Pengeluaran ($monthStr)', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold))),
                pw.SizedBox(height: 24),
                pw.Table(
                  border: pw.TableBorder.symmetric(
                    inside: pw.BorderSide(width: 0.7, color: PdfColors.grey400),
                    outside: pw.BorderSide(width: 1, color: PdfColors.grey400)
                  ),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(35),
                    1: const pw.FixedColumnWidth(80),
                    2: const pw.FlexColumnWidth(1),
                    3: const pw.FlexColumnWidth(1.5),
                    4: const pw.FixedColumnWidth(90),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        _buildPdfCell('No', isHeader: true),
                        _buildPdfCell('Tanggal', isHeader: true),
                        _buildPdfCell('Kategori', isHeader: true),
                        _buildPdfCell('Keterangan', isHeader: true),
                        _buildPdfCell('Nominal', isHeader: true, alignRight: true),
                      ],
                    ),
                    ...expenses.asMap().entries.map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      final date = DateFormat('yyyy-MM-dd').format(item.spentAt);
                      return pw.TableRow(
                        children: [
                          _buildPdfCell('${i + 1}'),
                          _buildPdfCell(date),
                          _buildPdfCell(item.category),
                          _buildPdfCell(item.note),
                          _buildPdfCell('Rp ${currencyFormat.format(item.amount)}', alignRight: true),
                        ],
                      );
                    }),
                    (() {
                      final totalNominal = expenses.fold<double>(0.0, (sum, item) => sum + item.amount);
                      return pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          _buildPdfCell(''),
                          _buildPdfCell(''),
                          _buildPdfCell(''),
                          _buildPdfCell('Total', isHeader: true, alignRight: true),
                          _buildPdfCell('Rp ${currencyFormat.format(totalNominal)}', isHeader: true, alignRight: true),
                        ],
                      );
                    })(),
                  ],
                ),
                pw.SizedBox(height: 24),
                pw.Divider(),
                pw.Center(child: pw.Text('Data diambil dari Aplikasi Mikrotik PPPoE Monitor', style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700))),
              ],
            ),
          ],
        );
      }
    ));
    return pdf;
  }

  void _showExpenseDetailDialog(ExpenseModel expense) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            Text('Detail Pengeluaran', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 24),
            _buildDetailRow(Icons.category, 'Kategori', expense.category, isDark),
            _buildDetailRow(Icons.monetization_on, 'Nominal', 'Rp ${currencyFormat.format(expense.amount)}', isDark),
            _buildDetailRow(Icons.calendar_today, 'Tanggal', DateFormat('yyyy-MM-dd HH:mm:ss').format(expense.spentAt), isDark),
            _buildDetailRow(Icons.note, 'Keterangan', expense.note.isEmpty ? '-' : expense.note, isDark),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Tutup'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.red.withOpacity(0.1) : Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: isDark ? Colors.red.shade300 : Colors.red.shade700),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String monthYearTitle = DateFormat('MMMM yyyy', 'id_ID').format(DateTime(widget.year, widget.month));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(monthYearTitle),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: isDark ? Colors.black26 : Colors.grey.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.file_download_outlined, color: isDark ? Colors.blue.shade300 : Colors.blue.shade700, size: 24),
                              const SizedBox(width: 12),
                              Text('Export Data Bulan Ini', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                                  label: const Text('Export PDF'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFD32F2F),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: isProcessing ? null : () async {
                                    try {
                                      final data = await _expensesFuture;
                                      await _printSummary(data);
                                    } catch (e) {
                                      _showSnackBar('Gagal export PDF: $e', success: false);
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
                                  icon: const Icon(Icons.table_chart, color: Colors.white),
                                  label: const Text('Export Excel'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: isProcessing ? null : () async {
                                    try {
                                      final data = await _expensesFuture;
                                      await _exportExcel(data);
                                    } catch (e) {
                                      _showSnackBar('Gagal export Excel: $e', success: false);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          if (isProcessing)
                            const Padding(padding: EdgeInsets.only(top: 16), child: LinearProgressIndicator()),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: FutureBuilder<List<ExpenseModel>>(
                future: _expensesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: isDark ? Colors.blue[200] : Colors.blue[600]));
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(child: Text('Tidak ada data', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)));
                  }

                  final expenses = snapshot.data!;
                  final totalAmount = expenses.fold<double>(0.0, (sum, p) => sum + p.amount);

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(color: isDark ? Colors.black26 : Colors.blueGrey.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(Icons.analytics, color: isDark ? Colors.red.shade300 : const Color(0xFFD32F2F)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Total Bulan Ini', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87, fontSize: 13)),
                                    const SizedBox(height: 4),
                                    Text('Rp ${currencyFormat.format(totalAmount)}', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.red.shade300 : const Color(0xFFC62828), fontSize: 16)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: isDark ? Colors.red.shade900 : Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                                child: Text('${expenses.length} pengeluaran', style: TextStyle(color: isDark ? Colors.red.shade300 : Colors.red.shade700, fontWeight: FontWeight.w600, fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          itemCount: expenses.length,
                          itemBuilder: (context, i) {
                            final item = expenses[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark ? Colors.black.withOpacity(0.3) : Colors.blueGrey.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => _showExpenseDetailDialog(item),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                    child: Row(
                                      children: [
                                        // Minimalist Icon Box
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: isDark 
                                                ? [Colors.red.shade900.withOpacity(0.4), Colors.red.shade800.withOpacity(0.2)]
                                                : [Colors.red.shade50, Colors.red.shade100.withOpacity(0.5)],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: isDark ? Colors.red.withOpacity(0.2) : Colors.red.shade100, width: 1),
                                          ),
                                          child: Icon(_getCategoryIcon(item.category), color: isDark ? Colors.red.shade300 : Colors.red.shade600, size: 24),
                                        ),
                                        const SizedBox(width: 14),
                                        // Details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.category,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                  color: isDark ? Colors.white : Colors.black87,
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                item.note.isNotEmpty ? item.note : DateFormat('dd MMM yyyy').format(item.spentAt),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isDark ? Colors.grey.shade400 : Colors.blueGrey.shade400,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (item.createdBy != null && item.createdBy!.isNotEmpty) ...[
                                                const SizedBox(height: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: isDark ? Colors.blue.withOpacity(0.15) : Colors.blue.shade50,
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: isDark ? Colors.blue.withOpacity(0.3) : Colors.blue.shade100),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.person, size: 10, color: isDark ? Colors.blue.shade300 : Colors.blue.shade600),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        item.createdBy!,
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                          color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Amount and Arrow
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Rp ${currencyFormat.format(item.amount)}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                                color: isDark ? Colors.red.shade300 : Colors.red.shade600,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Icon(
                                              Icons.chevron_right_rounded,
                                              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                                              size: 18,
                                            ),
                                          ],
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
