import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/log_sync_service.dart';
import '../widgets/gradient_container.dart';
import '../widgets/custom_snackbar.dart';
import 'package:intl/intl.dart';

import 'package:flutter/services.dart';
import 'payment_summary_screen.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import 'package:provider/provider.dart';
import '../providers/router_session_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    double value = 0;
    try {
      value = double.parse(newValue.text.replaceAll('.', ''));
    } catch (e) {
      return newValue;
    }

    final formatter = NumberFormat("#,##0", "id_ID");
    String newText = formatter.format(value);

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

class BillingScreen extends StatefulWidget {
  const BillingScreen({Key? key}) : super(key: key);

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  late Future<List<Map<String, dynamic>>> _usersFuture;
  List<Map<String, dynamic>> _users = [];
  String? _error;
  final currencyFormat = NumberFormat('#,##0', 'id_ID');
  String _searchQuery = '';
  final TextEditingController _searchUserController = TextEditingController();

  // Filter bulan untuk pembayaran
  DateTime _selectedMonth = DateTime.now();
  bool _showAllPayments =
      false; // false = filter per bulan (default ke bulan saat ini)
  bool _showFilterPanel = false; // Tambahkan state untuk panel filter
  // Tambahkan state sementara untuk filter manual
  DateTime? _tempSelectedMonth;

  // Sort Option
  String _sortOption = 'nameAsc'; // nameAsc, nameDesc, statusPaid, statusUnpaid

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now();
    _tempSelectedMonth = null;
    // Set default to show current month payments only
    _showAllPayments = false;
    _loadUsers();
  }

  void _loadUsers() {
    setState(() {
      _error = null;
      // Clear cache when manually refreshing
      ApiService.clearCache();
      final routerSession =
          Provider.of<RouterSessionProvider>(context, listen: false);
      final routerId = routerSession.routerId;
      if (routerId == null) {
        setState(() {
          _error = 'Silakan login router ulang (serial-number tidak ditemukan)';
          _usersFuture = Future.value(<Map<String, dynamic>>[]);
        });
        return;
      }

      // Sinkronisasi sekarang dilakukan di background saat dashboard dibuka
      // Langsung ambil data dari database
      _usersFuture =
          ApiService.fetchAllUsersWithPayments(routerId: routerId).then((data) {
        _users = data;
        return data;
      }).catchError((e) {
        // Error loading users: $e
        _error = e.toString();
        // Show a more user-friendly error message
        if (e.toString().contains('Timeout')) {
          _error = 'Koneksi timeout. Silakan coba lagi.';
        } else if (e.toString().contains('Failed host lookup')) {
          _error =
              'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';
        } else if (e.toString().contains('500')) {
          _error = 'Server error. Silakan coba lagi nanti.';
        }
        return <Map<String, dynamic>>[];
      });
    });
  }

  String _formatDate(String? dateStr, {String format = 'd MMMM yyyy'}) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final date = DateTime.tryParse(dateStr);
      return date != null ? DateFormat(format, 'id_ID').format(date) : dateStr;
    } catch (_) {
      return dateStr;
    }
  }

  void _showBillingDetailSheet(Map<String, dynamic> user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark
          ? const Color(0xFF1E1E1E)
          : Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        Future<void> showAddPaymentSheet() async {
          final formKey = GlobalKey<FormState>();
          final amountController = TextEditingController();
          final noteController = TextEditingController();
          final installmentAmountController = TextEditingController();
          final installmentNoteController = TextEditingController();
          String selectedMethod = 'cash';
          DateTime paymentDate = DateTime.now();
          bool isSubmitting = false;
          bool isInstallmentMode = false;

          // Cek apakah ada pembayaran di bulan yang sama sebelumnya
          final currentMonth = _selectedMonth;
          final payments = (user['payments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          final existingPayment = payments.firstWhere(
            (p) {
               final dt = DateTime.tryParse(p['payment_date']?.toString() ?? '');
               return dt != null && dt.year == currentMonth.year && dt.month == currentMonth.month;
            },
            orElse: () => <String, dynamic>{},
          );

          final hasInstallment = existingPayment.isNotEmpty;
          final prevAmount = double.tryParse(existingPayment['amount']?.toString() ?? '0') ?? 0.0;
          final prevNote = existingPayment['note']?.toString() ?? '';

          if (hasInstallment) {
            amountController.text = currencyFormat.format(prevAmount);
            noteController.text = prevNote;
          } else {
             // Coba ambil target tagihan jika tidak ada inputan
             final harga = double.tryParse(user['harga']?.toString() ?? '0') ?? 0.0;
             if (harga > 0) {
                 amountController.text = currencyFormat.format(harga);
             }
          }

          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            builder: (sheetContext) {
              return StatefulBuilder(
                builder: (context, setSheetState) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                      left: 24,
                      right: 24,
                      top: 16,
                    ),
                    child: SingleChildScrollView(
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                margin: const EdgeInsets.only(bottom: 24),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.grey.shade700 : Colors.grey[300],
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            Text(
                              hasInstallment ? 'Edit Pembayaran / Angsuran' : 'Tambah Pembayaran',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user['username'] ?? '-',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                            if (hasInstallment) ...[
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => setSheetState(() => isInstallmentMode = false),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          decoration: BoxDecoration(
                                            color: !isInstallmentMode ? (isDark ? Colors.grey.shade700 : Colors.white) : Colors.transparent,
                                            borderRadius: BorderRadius.circular(8),
                                            boxShadow: !isInstallmentMode ? [
                                              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                                            ] : [],
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            'Koreksi Total',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: !isInstallmentMode ? (isDark ? Colors.white : Colors.black87) : Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => setSheetState(() => isInstallmentMode = true),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          decoration: BoxDecoration(
                                            color: isInstallmentMode ? (isDark ? Colors.grey.shade700 : Colors.white) : Colors.transparent,
                                            borderRadius: BorderRadius.circular(8),
                                            boxShadow: isInstallmentMode ? [
                                              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                                            ] : [],
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            'Tambah Angsuran',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: isInstallmentMode ? (isDark ? Colors.white : Colors.black87) : Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            if (isInstallmentMode && hasInstallment) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: isDark ? Colors.blue.shade800 : Colors.blue.shade200),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Terbayar Sebelumnya:', style: TextStyle(fontSize: 12, color: isDark ? Colors.blue.shade200 : Colors.blue.shade800)),
                                    Text('Rp ${currencyFormat.format(prevAmount)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.blue.shade300 : Colors.blue.shade700)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: installmentAmountController,
                                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                keyboardType: TextInputType.number,
                                inputFormatters: [CurrencyInputFormatter()],
                                decoration: InputDecoration(
                                  labelText: 'Nominal Tambahan (Rp)',
                                  labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                                  prefixText: 'Rp ',
                                  prefixStyle: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.blue.shade300 : Colors.blue)),
                                ),
                                validator: (v) => v == null || v.isEmpty ? 'Nominal tambahan wajib diisi' : null,
                              ),
                            ] else ...[
                              TextFormField(
                                controller: amountController,
                                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                keyboardType: TextInputType.number,
                                inputFormatters: [CurrencyInputFormatter()],
                                decoration: InputDecoration(
                                  labelText: 'Nominal Total (Rp)',
                                  labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                                  prefixText: 'Rp ',
                                  prefixStyle: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.blue.shade300 : Colors.blue)),
                                ),
                                validator: (v) => v == null || v.isEmpty ? 'Nominal wajib diisi' : null,
                              ),
                            ],

                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              dropdownColor: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                              value: selectedMethod,
                              items: const [
                                DropdownMenuItem(value: 'cash', child: Text('Cash (Tunai)')),
                                DropdownMenuItem(value: 'transfer', child: Text('Transfer Bank')),
                                DropdownMenuItem(value: 'qris', child: Text('QRIS')),
                                DropdownMenuItem(value: 'e-wallet', child: Text('E-Wallet')),
                                DropdownMenuItem(value: 'titipan', child: Text('Titipan / Deposit')),
                              ],
                              onChanged: (v) {
                                setSheetState(() {
                                  selectedMethod = v!;
                                });
                              },
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16),
                              decoration: InputDecoration(
                                labelText: 'Metode Pembayaran',
                                labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.blue.shade300 : Colors.blue)),
                              ),
                            ),

                            const SizedBox(height: 16),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: paymentDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (picked != null) {
                                  setSheetState(() {
                                    paymentDate = picked;
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: isInstallmentMode ? 'Tanggal Setor Tambahan' : 'Tanggal Pembayaran',
                                  labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.blue.shade300 : Colors.blue)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today, size: 18, color: isDark ? Colors.grey.shade400 : Colors.blueGrey),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(paymentDate),
                                      style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: isInstallmentMode ? installmentNoteController : noteController,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                labelText: isInstallmentMode ? 'Catatan Setoran (opsional)' : 'Catatan (opsional)',
                                labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.blue.shade300 : Colors.blue)),
                              ),
                              minLines: 1,
                              maxLines: 3,
                            ),
                            
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () => Navigator.of(sheetContext).pop(),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: Text(
                                      'BATAL',
                                      style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton(
                                    onPressed: isSubmitting ? null : () async {
                                      if (!formKey.currentState!.validate()) return;
                                      
                                      setSheetState(() {
                                        isSubmitting = true;
                                      });

                                      try {
                                        final userId = user['id']?.toString();
                                        if (userId == null) throw Exception('User ID tidak ditemukan');

                                        final routerId = Provider.of<RouterSessionProvider>(context, listen: false).routerId;
                                        if (routerId == null || routerId.isEmpty) throw Exception('Router belum login.');

                                        double finalAmount = 0.0;
                                        String finalNote = '';

                                        if (isInstallmentMode && hasInstallment) {
                                          final instAmtRaw = installmentAmountController.text.replaceAll('.', '').replaceAll(',', '');
                                          final instAmt = double.tryParse(instAmtRaw) ?? 0;
                                          finalAmount = prevAmount + instAmt;

                                          final dateStr = DateFormat('yyyy-MM-dd').format(paymentDate);
                                          final instDesc = '[Angsuran: +Rp${currencyFormat.format(instAmt)} tgl $dateStr (${selectedMethod.toUpperCase()})${installmentNoteController.text.isNotEmpty ? ' - ' + installmentNoteController.text : ''}]';
                                          
                                          if (prevNote.contains('[Angsuran:')) {
                                            finalNote = '$prevNote\n$instDesc';
                                          } else {
                                            final prevDateStr = existingPayment['payment_date'] ?? dateStr;
                                            final prevMethod = (existingPayment['method'] ?? 'CASH').toString().toUpperCase();
                                            final firstDesc = '[Awal: Rp${currencyFormat.format(prevAmount)} tgl $prevDateStr ($prevMethod)${prevNote.isNotEmpty ? ' - ' + prevNote : ''}]';
                                            finalNote = '$firstDesc\n$instDesc';
                                          }
                                        } else {
                                          final amtRaw = amountController.text.replaceAll('.', '').replaceAll(',', '');
                                          finalAmount = double.tryParse(amtRaw) ?? 0;
                                          finalNote = noteController.text;
                                          
                                          // Reset note behavior if total matched initial
                                          if (prevNote.contains('[Angsuran:')) {
                                             final match = RegExp(r'\[Awal:\s*Rp\s*([\d.]+)', caseSensitive: false).firstMatch(prevNote);
                                             if (match != null) {
                                                final awalAmt = double.tryParse(match.group(1)!.replaceAll('.', '')) ?? 0;
                                                if (finalAmount == awalAmt) {
                                                   final lines = prevNote.split('\n');
                                                   final awalLine = lines.where((l) => l.startsWith('[Awal:')).firstOrNull;
                                                   if (awalLine != null) finalNote = awalLine;
                                                }
                                             }
                                          }
                                        }

                                        // Ambil username sebelum proses async dimulai untuk mencegah error context
                                        final adminUsername = Provider.of<RouterSessionProvider>(context, listen: false).username;

                                        final respData = await ApiService.addPayment(
                                          routerId: routerId,
                                          userId: userId,
                                          amount: finalAmount,
                                          paymentDate: DateFormat('yyyy-MM-dd').format(paymentDate),
                                          method: selectedMethod,
                                          note: finalNote,
                                          adminUsername: adminUsername,
                                          customerName: user['username'],
                                        );

                                        if (respData['success'] == true) {
                                          Navigator.of(sheetContext).pop();
                                          if (context.mounted) {
                                            // Send Notification
                                            try {
                                              final notifBody = "Nama : ${user['username']}\n"
                                                  "Nominal : Rp ${currencyFormat.format(finalAmount)}\n"
                                                  "Metode : $selectedMethod\n"
                                                  "Tanggal : ${DateFormat('dd MMM yyyy').format(paymentDate)}\n"
                                                  "Catatan : $finalNote\n"
                                                  "Oleh : $adminUsername";
                                              
                                              await LogSyncService(this.context).testNotification(
                                                title: "Pembayaran Berhasil",
                                                body: notifBody,
                                              );
                                            } catch (e) {
                                              debugPrint("Error notif: $e");
                                            }

                                            await showSuccessDialog(this.context, 'Pembayaran berhasil ditambahkan!');
                                            if (mounted) {
                                              // Tutup Billing Detail Sheet utama agar user kembali ke list yang ter-refresh
                                              Navigator.of(this.context).pop();
                                              _loadUsers();
                                            }
                                          }
                                        } else {
                                          throw Exception(respData['error'] ?? 'Unknown error');
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          CustomSnackbar.show(context: context, message: 'Gagal', additionalInfo: e.toString(), isSuccess: false);
                                        }
                                      } finally {
                                        if (sheetContext.mounted) {
                                          setSheetState(() => isSubmitting = false);
                                        }
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade600,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      elevation: 0,
                                    ),
                                    child: isSubmitting 
                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : const Text('SIMPAN PEMBAYARAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        }

        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color:
                              isDark ? Colors.grey.shade700 : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10, top: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['username'] ?? '-',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: isDark
                                  ? Colors.blue.shade300
                                  : const Color(0xFF1565C0),
                            ),
                          ),
                          if (user['profile'] != null)
                            Text(
                              'Profile: ${user['profile']}',
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.grey[600],
                                  fontSize: 13),
                            ),
                          if (user['tanggal_tagihan'] != null &&
                              user['tanggal_tagihan']
                                  .toString()
                                  .isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.calendar_today,
                                    size: 14,
                                    color: isDark
                                        ? Colors.orange.shade300
                                        : Colors.orange.shade800),
                                const SizedBox(width: 6),
                                Text(
                                  'Jatuh Tempo: ${_formatDate(user['tanggal_tagihan'])}',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.orange.shade300
                                        : Colors.orange.shade800,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.payments,
                            color: isDark
                                ? Colors.green.shade300
                                : Colors.green.shade700,
                            size: 22),
                        const SizedBox(width: 10),
                        Text('History Pembayaran',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: isDark ? Colors.white : Colors.black87,
                            )),
                        const Spacer(),
                      ],
                    ),
                    Divider(
                      color: isDark ? Colors.grey.shade700 : null,
                    ),
                    // Payment summary
                    if (_filteredPayments(user).isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.blue.shade900
                              : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: isDark
                                  ? Colors.blue.shade700
                                  : Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.analytics,
                                color: isDark
                                    ? Colors.blue.shade300
                                    : Colors.blue.shade700,
                                size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _showAllPayments
                                        ? 'Total Semua Pembayaran'
                                        : 'Total Pembayaran ${DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.blue.shade300
                                          : Colors.blue.shade700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Rp ${currencyFormat.format(_filteredPayments(user).where((p) => p['method']?.toString().toLowerCase() != 'titipan').fold<double>(0, (sum, p) => sum + (double.tryParse(p['amount']?.toString() ?? '0') ?? 0)))}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.blue.shade200
                                          : Colors.blue.shade800,
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
                                    : Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_filteredPayments(user).length} pembayaran',
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
                      const SizedBox(height: 12),
                    ],
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      child: _filteredPayments(user).isEmpty
                          ? Column(
                              key: const ValueKey('empty'),
                              children: [
                                const SizedBox(height: 32),
                                Icon(Icons.receipt_long,
                                    color: isDark
                                        ? Colors.grey.shade600
                                        : Colors.grey,
                                    size: 54),
                                const SizedBox(height: 12),
                                Text(
                                  !_showAllPayments
                                      ? 'Tidak ada pembayaran di ${DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth)}.'
                                      : 'Belum ada pembayaran.',
                                  style: TextStyle(
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                      fontSize: 15),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  !_showAllPayments
                                      ? 'Coba pilih bulan lain atau tekan tombol "Semua" untuk melihat semua pembayaran.'
                                      : 'Tekan tombol di bawah untuk menambah pembayaran baru.',
                                  style: TextStyle(
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.black38,
                                      fontSize: 13),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            )
                          : Column(
                              key: const ValueKey('list'),
                              children:
                                  _filteredPayments(user).map<Widget>((p) {
                                final amount = p['amount']?.toString() ?? '-';
                                final method = p['method']?.toString() ?? '-';
                                final paymentDate =
                                    p['payment_date']?.toString() ?? '-';
                                final createdBy =
                                    p['created_by']?.toString() ?? '';
                                final note = p['note']?.toString() ?? '';
                                final isCurrentMonth = () {
                                  final dt = DateTime.tryParse(paymentDate);
                                  return dt != null &&
                                      dt.year == _selectedMonth.year &&
                                      dt.month == _selectedMonth.month;
                                }();
                                return Center(
                                  child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 380),
                                    child: Card(
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 12, horizontal: 0),
                                      elevation: 3,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                        side: isCurrentMonth
                                            ? BorderSide(
                                                color: isDark
                                                    ? Colors.blue.shade700
                                                    : Colors.blue.shade400,
                                                width: 2)
                                            : BorderSide(
                                                color: isDark
                                                    ? Colors.grey.shade700
                                                    : Colors.grey.shade200,
                                                width: 1),
                                      ),
                                      color: isCurrentMonth
                                          ? (isDark
                                              ? Colors.blue.shade900
                                              : Colors.blue.shade50)
                                          : (isDark
                                              ? const Color(0xFF2D2D2D)
                                              : Colors.white),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16, horizontal: 18),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(Icons.check_circle,
                                                    color: Colors.green,
                                                    size: 22),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                      'Rp ${currencyFormat.format(double.tryParse(amount) ?? 0)}',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 18,
                                                        color: isDark
                                                            ? Colors.white
                                                            : Colors.black87,
                                                      )),
                                                ),
                                                _buildMethodChip(method),
                                                if (isCurrentMonth) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: isDark
                                                          ? Colors.blue.shade900
                                                          : Colors
                                                              .blue.shade100,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: Text('Bulan Ini',
                                                        style: TextStyle(
                                                            color: isDark
                                                                ? Colors.blue
                                                                    .shade300
                                                                : Colors.blue,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 11)),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            if (!_showAllPayments) ...[
                                              const SizedBox(height: 4),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? Colors.blue.shade900
                                                      : Colors.blue.shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  'Filter: ${DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth)}',
                                                  style: TextStyle(
                                                    color: isDark
                                                        ? Colors.blue.shade300
                                                        : Colors.blue.shade700,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Icon(Icons.calendar_today,
                                                    size: 16,
                                                    color: isDark
                                                        ? Colors.grey.shade400
                                                        : Colors
                                                            .blueGrey.shade300),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Tanggal: ${DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(DateTime.parse(paymentDate))}',
                                                  style: TextStyle(
                                                      fontSize: 13,
                                                      color: isDark
                                                          ? Colors.white70
                                                          : Colors.black54),
                                                ),
                                              ],
                                            ),
                                            if (createdBy.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 2),
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.person,
                                                        size: 15,
                                                        color: isDark
                                                            ? Colors
                                                                .grey.shade400
                                                            : Colors.blueGrey
                                                                .shade300),
                                                    const SizedBox(width: 6),
                                                    Text('Oleh: $createdBy',
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color: isDark
                                                                ? Colors.white70
                                                                : Colors
                                                                    .black45)),
                                                  ],
                                                ),
                                              ),
                                            if (note.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 2),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                        Icons.info_outline,
                                                        size: 15,
                                                        color: Colors.orange),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                        child: Text(note,
                                                            style: TextStyle(
                                                                fontSize: 12,
                                                                color: isDark
                                                                    ? Colors
                                                                        .white70
                                                                    : Colors
                                                                        .black54))),
                                                  ],
                                                ),
                                              ),
                                            const SizedBox(height: 12),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                Tooltip(
                                                  message: 'Edit pembayaran',
                                                  child: ElevatedButton.icon(
                                                    onPressed: () =>
                                                        _showEditPaymentDialog(
                                                            p, user, onSuccess: () => Navigator.of(context).pop()),
                                                    icon: Icon(
                                                      Icons.edit,
                                                      size: 18,
                                                      color: isDark
                                                          ? Colors.blue.shade300
                                                          : Colors
                                                              .blue.shade800,
                                                    ),
                                                    label: Text(
                                                      'Edit',
                                                      style: TextStyle(
                                                        color: isDark
                                                            ? Colors
                                                                .blue.shade300
                                                            : Colors
                                                                .blue.shade800,
                                                      ),
                                                    ),
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor: isDark
                                                          ? Colors.blue.shade900
                                                          : Colors.blue.shade50,
                                                      foregroundColor: isDark
                                                          ? Colors.blue.shade300
                                                          : Colors
                                                              .blue.shade800,
                                                      elevation: 0,
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 16,
                                                          vertical: 8),
                                                      textStyle:
                                                          const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold),
                                                      shape:
                                                          RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8)),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Tooltip(
                                                  message: 'Hapus pembayaran',
                                                  child: ElevatedButton.icon(
                                                    onPressed: () =>
                                                        _confirmDeletePayment(
                                                            p, user, onSuccess: () => Navigator.of(context).pop()),
                                                    icon: Icon(
                                                      Icons.delete,
                                                      size: 18,
                                                      color: isDark
                                                          ? Colors.red.shade300
                                                          : Colors.red.shade800,
                                                    ),
                                                    label: Text(
                                                      'Hapus',
                                                      style: TextStyle(
                                                        color: isDark
                                                            ? Colors
                                                                .red.shade300
                                                            : Colors
                                                                .red.shade800,
                                                      ),
                                                    ),
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor: isDark
                                                          ? Colors.red.shade900
                                                          : Colors.red.shade50,
                                                      foregroundColor: isDark
                                                          ? Colors.red.shade300
                                                          : Colors.red.shade800,
                                                      elevation: 0,
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 16,
                                                          vertical: 8),
                                                      textStyle:
                                                          const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold),
                                                      shape:
                                                          RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8)),
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
                                );
                              }).toList(),
                            ),
                    ),
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: showAddPaymentSheet,
                          icon:
                              const Icon(Icons.add_circle, color: Colors.white),
                          label: const Text('Tambah Pembayaran',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white,
                              )),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark
                                ? Colors.green.shade700
                                : Colors.green.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ),
                    // Send Message Button
                    Padding(
                      padding: const EdgeInsets.only(top: 0, bottom: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _showSendMessageDialog(user);
                          },
                          icon: const Icon(Icons.message, color: Colors.white),
                          label: const Text('Kirim Pesan WhatsApp',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white,
                              )),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark
                                ? Colors.blue.shade700
                                : Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 2,
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

  Future<void> _showSendMessageDialog(Map<String, dynamic> user) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Check if user has phone number (using 'wa' field)
    final phoneNumber = user['wa']?.toString() ?? '';
    if (phoneNumber.isEmpty) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              contentPadding: const EdgeInsets.all(24),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.orange.shade900.withOpacity(0.3)
                          : Colors.orange.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.phone_disabled,
                      color: Colors.orange,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Nomor WhatsApp Tidak Tersedia',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'User ${user['username']} belum memiliki nomor WhatsApp.',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Silakan tambahkan nomor WhatsApp terlebih dahulu di halaman Semua User.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.black45,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                isDark ? Colors.white70 : Colors.grey[700],
                            side: BorderSide(
                              color: isDark
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade400,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'TUTUP',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            // Navigate to All Users screen
                            Navigator.pushNamed(context, '/all-users');
                          },
                          icon: const Icon(Icons.people, size: 18),
                          label: const Text(
                            'BUKA',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      }
      return;
    }

    // Calculate payment status ONLY for selected month (ignore _showAllPayments for message)
    // This ensures accurate status per month
    final paymentsForSelectedMonth = (user['payments'] as List)
        .where((p) {
          final paymentDate = DateTime.tryParse(p['payment_date'] ?? '');
          return paymentDate != null &&
              paymentDate.year == _selectedMonth.year &&
              paymentDate.month == _selectedMonth.month;
        })
        .cast<Map<String, dynamic>>()
        .toList();

    final totalPayments = paymentsForSelectedMonth.fold<double>(
      0,
      (sum, p) => sum + (double.tryParse(p['amount']?.toString() ?? '0') ?? 0),
    );

    // Status LUNAS hanya jika ada pembayaran di bulan yang dipilih
    final isLunas = totalPayments > 0;

    // Determine period text for message (always show selected month for individual message)
    final periodText =
        'Pembayaran ${DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth)}';

    // Set automatic message based on payment status
    // Load custom templates
    final prefs = await SharedPreferences.getInstance();
    final templateLunas = prefs.getString('template_lunas') ??
        '''Halo [nama],

Terima kasih atas pembayaran Anda. Status pembayaran Anda sudah *LUNAS*.

*[periode]*
Total Pembayaran: [total]

Terima kasih telah menjadi pelanggan setia kami! 🙏''';

    final templateTagihan = prefs.getString('template_tagihan') ??
        '''Assalamu'alaikum Pelanggan Yth,

Kami sampaikan bahwa tagihan anda sudah maksimal.
Segera lakukan pembayaran agar tidak otomatis terisolir.

*[periode]*

Pembayaran bisa melalui transfer ke:

*Rekening*
*BCA : ...*
*BRI : *
*BSI : ...*
*Dana : 085931564236*
Atas nama *Hasan Mahfudh*

Terimakasih''';

    // Prepare replacements
    final replacements = {
      '[nama]': user['username'] ?? '',
      '[total]': 'Rp ${currencyFormat.format(totalPayments)}',
      '[bulan]': DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth),
      '[periode]': periodText,
      '[admin]':
          Provider.of<RouterSessionProvider>(context, listen: false).username ??
              'Admin',
    };

    // Select template and replace placeholders
    String message = isLunas ? templateLunas : templateTagihan;
    replacements.forEach((key, value) {
      message = message.replaceAll(key, value);
    });

    // Show confirmation dialog
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                Icons.message,
                color: isDark ? Colors.green.shade300 : Colors.green.shade700,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Kirim Pesan WhatsApp',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 18,
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
                // User info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person,
                              size: 16,
                              color: isDark ? Colors.white70 : Colors.black54),
                          const SizedBox(width: 6),
                          Text(
                            user['username'] ?? '-',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.phone,
                              size: 16,
                              color: isDark ? Colors.white70 : Colors.black54),
                          const SizedBox(width: 6),
                          Text(
                            phoneNumber,
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            isLunas ? Icons.check_circle : Icons.warning,
                            size: 16,
                            color: isLunas ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isLunas ? 'LUNAS' : 'BELUM LUNAS',
                            style: TextStyle(
                              color: isLunas ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Pesan yang akan dikirim:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(
                    maxHeight: 300, // Batasi tinggi maksimal
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      message,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontSize: 13,
                        height: 1.5, // Line height untuk readability
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'BATAL',
                style: TextStyle(
                  color: isDark ? Colors.blue.shade300 : Colors.blue,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(dialogContext).pop();

                try {
                  // Send Text Only (Direct Link)
                  // Format phone number
                  String formattedPhone =
                      phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
                  if (formattedPhone.startsWith('0')) {
                    formattedPhone = '62${formattedPhone.substring(1)}';
                  } else if (!formattedPhone.startsWith('62')) {
                    formattedPhone = '62$formattedPhone';
                  }

                  final whatsappUrl = Uri.parse(
                    'https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}',
                  );

                  if (await canLaunchUrl(whatsappUrl)) {
                    await launchUrl(whatsappUrl,
                        mode: LaunchMode.externalApplication);
                    if (mounted) {
                      CustomSnackbar.show(
                        context: context,
                        message: 'Membuka WhatsApp...',
                        isSuccess: true,
                      );
                    }
                  } else {
                    throw Exception('Tidak dapat membuka WhatsApp');
                  }
                } catch (e) {
                  if (mounted) {
                    CustomSnackbar.show(
                      context: context,
                      message: 'Gagal mengirim pesan',
                      additionalInfo: e.toString(),
                      isSuccess: false,
                    );
                  }
                }
              },
              icon: const Icon(Icons.send, color: Colors.white),
              label: const Text(
                'KIRIM',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Tagihan/Billing',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadUsers,
            ),
            IconButton(
              icon: const Icon(Icons.bar_chart, color: Colors.white),
              tooltip: 'Ringkasan Pembayaran',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const PaymentSummaryScreen()),
                );
              },
            ),
          ],
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _usersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (_error != null) {
              final errorMsg = _error!;
              final isTimeout = errorMsg.toLowerCase().contains('timeout');
              final isServerError =
                  errorMsg.toLowerCase().contains('server error');

              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isServerError ? Icons.error_outline : Icons.wifi_off,
                        size: 64,
                        color: isDark ? Colors.white70 : Colors.grey[600],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isTimeout
                            ? 'Timeout: Server tidak merespons dalam 10 detik.\nSilakan cek koneksi atau coba lagi.'
                            : isServerError
                                ? 'Server Error: API tidak tersedia saat ini.\nSilakan coba lagi nanti.'
                                : 'Error: $errorMsg',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _loadUsers,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Coba Lagi'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isDark ? Colors.blue.shade700 : Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 64,
                      color: isDark ? Colors.white70 : Colors.grey[600],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tidak ada user ditemukan.',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black54,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _loadUsers,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isDark ? Colors.blue.shade700 : Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              );
            }
            final users = _filteredSortedUsers();
            return Column(
              children: [
                // Search Bar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color:
                                isDark ? const Color(0xFF2D2D2D) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                    ? Colors.black26
                                    : Colors.grey.withOpacity(0.1),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchUserController,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Cari...',
                              hintStyle: TextStyle(
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade500,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                                size: 20,
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(
                                        Icons.clear,
                                        color: isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        _searchUserController.clear();
                                        setState(() {
                                          _searchQuery = '';
                                        });
                                      },
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              border: InputBorder.none,
                            ),
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Sort Button
                      Container(
                        decoration: BoxDecoration(
                          color:
                              isDark ? const Color(0xFF2D2D2D) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: PopupMenuButton<String>(
                          tooltip: 'Urutkan',
                          icon: Icon(
                            Icons.sort,
                            color: isDark
                                ? Colors.blue.shade300
                                : Colors.blue.shade700,
                            size: 24,
                          ),
                          color:
                              isDark ? const Color(0xFF2D2D2D) : Colors.white,
                          onSelected: (String value) {
                            setState(() {
                              _sortOption = value;
                            });
                          },
                          itemBuilder: (BuildContext context) =>
                              <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(
                              value: 'nameAsc',
                              child: Row(
                                children: [
                                  Icon(Icons.sort_by_alpha,
                                      size: 20,
                                      color: _sortOption == 'nameAsc'
                                          ? (isDark
                                              ? Colors.blue.shade300
                                              : Colors.blue)
                                          : (isDark
                                              ? Colors.white70
                                              : Colors.black54)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Nama - Default (A-Z)',
                                    style: TextStyle(
                                      color: _sortOption == 'nameAsc'
                                          ? (isDark
                                              ? Colors.blue.shade300
                                              : Colors.blue)
                                          : (isDark
                                              ? Colors.white
                                              : Colors.black87),
                                      fontWeight: _sortOption == 'nameAsc'
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'nameDesc',
                              child: Row(
                                children: [
                                  Icon(Icons.sort_by_alpha,
                                      size: 20,
                                      color: _sortOption == 'nameDesc'
                                          ? (isDark
                                              ? Colors.blue.shade300
                                              : Colors.blue)
                                          : (isDark
                                              ? Colors.white70
                                              : Colors.black54)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Nama (Z-A)',
                                    style: TextStyle(
                                      color: _sortOption == 'nameDesc'
                                          ? (isDark
                                              ? Colors.blue.shade300
                                              : Colors.blue)
                                          : (isDark
                                              ? Colors.white
                                              : Colors.black87),
                                      fontWeight: _sortOption == 'nameDesc'
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const PopupMenuDivider(),
                            PopupMenuItem<String>(
                              value: 'statusPaid',
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle_outline,
                                      size: 20,
                                      color: _sortOption == 'statusPaid'
                                          ? (isDark
                                              ? Colors.blue.shade300
                                              : Colors.blue)
                                          : (isDark
                                              ? Colors.white70
                                              : Colors.black54)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Lunas',
                                    style: TextStyle(
                                      color: _sortOption == 'statusPaid'
                                          ? (isDark
                                              ? Colors.blue.shade300
                                              : Colors.blue)
                                          : (isDark
                                              ? Colors.white
                                              : Colors.black87),
                                      fontWeight: _sortOption == 'statusPaid'
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'statusUnpaid',
                              child: Row(
                                children: [
                                  Icon(Icons.cancel_outlined,
                                      size: 20,
                                      color: _sortOption == 'statusUnpaid'
                                          ? (isDark
                                              ? Colors.blue.shade300
                                              : Colors.blue)
                                          : (isDark
                                              ? Colors.white70
                                              : Colors.black54)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Belum Lunas',
                                    style: TextStyle(
                                      color: _sortOption == 'statusUnpaid'
                                          ? (isDark
                                              ? Colors.blue.shade300
                                              : Colors.blue)
                                          : (isDark
                                              ? Colors.white
                                              : Colors.black87),
                                      fontWeight: _sortOption == 'statusUnpaid'
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'statusTitipan',
                              child: Row(
                                children: [
                                  Icon(Icons.inventory_2_outlined,
                                      size: 20,
                                      color: _sortOption == 'statusTitipan'
                                          ? (isDark
                                              ? Colors.blue.shade300
                                              : Colors.blue)
                                          : (isDark
                                              ? Colors.white70
                                              : Colors.black54)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Titipan',
                                    style: TextStyle(
                                      color: _sortOption == 'statusTitipan'
                                          ? (isDark
                                              ? Colors.blue.shade300
                                              : Colors.blue)
                                          : (isDark
                                              ? Colors.white
                                              : Colors.black87),
                                      fontWeight: _sortOption == 'statusTitipan'
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color:
                              isDark ? const Color(0xFF2D2D2D) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Tooltip(
                          message: _showFilterPanel
                              ? 'Sembunyikan filter'
                              : 'Tampilkan filter',
                          child: IconButton(
                            icon: Icon(
                                _showFilterPanel
                                    ? Icons.filter_alt_off
                                    : Icons.filter_alt,
                                color: isDark
                                    ? Colors.blue.shade300
                                    : Colors.blue.shade700,
                                size: 24),
                            onPressed: () {
                              setState(() {
                                _showFilterPanel = !_showFilterPanel;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // FILTER GLOBAL
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tombol filter satu baris

                      const SizedBox(height: 8),
                      // Panel filter (expand/collapse)
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 250),
                        crossFadeState: _showFilterPanel
                            ? CrossFadeState.showFirst
                            : CrossFadeState.showSecond,
                        firstChild: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 2, bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color:
                                isDark ? const Color(0xFF2D2D2D) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                    ? Colors.black45
                                    : Colors.blue.shade50,
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Tombol kiri
                              SizedBox(
                                width: 28,
                                height: 28,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    shape: const CircleBorder(),
                                    side: BorderSide(
                                        color: isDark
                                            ? Colors.blue.shade700
                                            : Colors.blue.shade200),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      final current =
                                          _tempSelectedMonth ?? _selectedMonth;
                                      // Kurangi 1 bulan dengan benar
                                      final newMonth = current.month == 1
                                          ? 12
                                          : current.month - 1;
                                      final newYear = current.month == 1
                                          ? current.year - 1
                                          : current.year;
                                      _tempSelectedMonth =
                                          DateTime(newYear, newMonth, 1);
                                    });
                                  },
                                  child: Icon(Icons.chevron_left,
                                      size: 16,
                                      color: isDark
                                          ? Colors.blue.shade300
                                          : const Color(0xFF1976D2)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Picker bulan
                              InkWell(
                                onTap: () async {
                                  final now = DateTime.now();
                                  final picked = await showMonthPicker(
                                    context: context,
                                    initialDate:
                                        _tempSelectedMonth ?? _selectedMonth,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(now.year + 1, 12, 31),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _tempSelectedMonth = DateTime(
                                          picked.year, picked.month, 1);
                                    });
                                  }
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.blue.shade900
                                        : Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: isDark
                                            ? Colors.blue.shade700
                                            : Colors.blue.shade200),
                                  ),
                                  child: Text(
                                    DateFormat('MMM yyyy', 'id_ID').format(
                                        (_tempSelectedMonth ?? _selectedMonth)),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.blue.shade300
                                          : const Color(0xFF1976D2),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Tombol kanan
                              SizedBox(
                                width: 28,
                                height: 28,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    shape: const CircleBorder(),
                                    side: BorderSide(
                                        color: isDark
                                            ? Colors.blue.shade700
                                            : Colors.blue.shade200),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      final current =
                                          _tempSelectedMonth ?? _selectedMonth;
                                      // Tambah 1 bulan dengan benar
                                      final newMonth = current.month == 12
                                          ? 1
                                          : current.month + 1;
                                      final newYear = current.month == 12
                                          ? current.year + 1
                                          : current.year;
                                      _tempSelectedMonth =
                                          DateTime(newYear, newMonth, 1);
                                    });
                                  },
                                  child: Icon(Icons.chevron_right,
                                      size: 16,
                                      color: isDark
                                          ? Colors.blue.shade300
                                          : const Color(0xFF1976D2)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Tombol Apply
                              SizedBox(
                                height: 28,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark
                                        ? Colors.blue.shade700
                                        : Colors.blue.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 0),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6)),
                                    textStyle: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      if (_tempSelectedMonth != null) {
                                        _selectedMonth = _tempSelectedMonth!;
                                      }
                                      _showAllPayments =
                                          true; // Selalu tampilkan semua pembayaran di popup
                                      _showFilterPanel =
                                          false; // Close the filter panel after applying
                                    });
                                  },
                                  child: const Text('Apply'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        secondChild: const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                // END FILTER GLOBAL
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () async => _loadUsers(),
                          child: users.isEmpty
                              ? ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    SizedBox(
                                      height: MediaQuery.of(context).size.height * 0.5,
                                      child: const Center(
                                        child: Text('Tidak ada data tagihan ditemukan',
                                            style: TextStyle(color: Colors.grey, fontSize: 16)),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                  itemCount: users.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, i) {
                              final user = users[i];
                              final payStatus = _getUserPaymentStatusForSelectedMonth(user);
                              
                              Color statusColor;
                              Color statusBgColor;
                              Color statusIconColor;
                              IconData statusIcon;
                              String statusText;

                              if (payStatus == 'lunas') {
                                statusColor = isDark ? Colors.green.shade700 : Colors.green;
                                statusBgColor = isDark ? Colors.green.shade900 : Colors.green.shade50;
                                statusIconColor = isDark ? Colors.green.shade300 : Colors.green;
                                statusIcon = Icons.check;
                                statusText = 'Lunas';
                              } else if (payStatus == 'titipan') {
                                statusColor = isDark ? Colors.orange.shade700 : Colors.orange;
                                statusBgColor = isDark ? Colors.orange.shade900 : Colors.orange.shade50;
                                statusIconColor = isDark ? Colors.orange.shade300 : Colors.orange;
                                statusIcon = Icons.inventory_2;
                                statusText = 'Titipan';
                              } else {
                                statusColor = isDark ? Colors.red.shade700 : Colors.red;
                                statusBgColor = isDark ? Colors.red.shade900 : Colors.red.shade50;
                                statusIconColor = isDark ? Colors.red.shade300 : Colors.red;
                                statusIcon = Icons.close;
                                statusText = 'Belum';
                              }

                              return GestureDetector(
                                onTap: () => _showBillingDetailSheet(user),
                                child: Card(
                                  elevation: 2,
                                  margin: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                        color: statusColor.withOpacity(0.5),
                                        width: 1.2),
                                  ),
                                  color: isDark
                                      ? const Color(0xFF1E1E1E)
                                      : Colors.white,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 22,
                                          backgroundColor: statusBgColor,
                                          child: Icon(Icons.payments,
                                              color: statusIconColor,
                                              size: 26),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                user['username'] ?? '-',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: isDark
                                                      ? Colors.white
                                                      : Colors.black87,
                                                ),
                                              ),
                                              if (user['profile'] != null)
                                                Text(
                                                    'Profile: ${user['profile']}',
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        color: isDark
                                                            ? Colors.white70
                                                            : Colors.black54)),
                                              if (user['tanggal_tagihan'] !=
                                                      null &&
                                                  user['tanggal_tagihan']
                                                      .toString()
                                                      .isNotEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 4),
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.calendar_today,
                                                          size: 12,
                                                          color: isDark
                                                              ? Colors.orange
                                                                  .shade300
                                                              : Colors.orange
                                                                  .shade800),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Jatuh Tempo: ${(() {
                                                          try {
                                                            final date = DateTime
                                                                .tryParse(user[
                                                                    'tanggal_tagihan']);
                                                            return date != null
                                                                ? DateFormat(
                                                                        'd MMM',
                                                                        'id_ID')
                                                                    .format(
                                                                        date)
                                                                : user[
                                                                    'tanggal_tagihan'];
                                                          } catch (_) {
                                                            return user[
                                                                'tanggal_tagihan'];
                                                          }
                                                        })()}',
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: isDark
                                                                ? Colors.orange
                                                                    .shade300
                                                                : Colors.orange
                                                                    .shade800),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              if (user['nominal'] != null)
                                                Text(
                                                    'Tagihan: Rp ${currencyFormat.format(double.tryParse(user['nominal']) ?? 0)}',
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        color: isDark
                                                            ? Colors
                                                                .orange.shade300
                                                            : Colors.deepOrange,
                                                        fontWeight:
                                                            FontWeight.w600)),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor: statusColor,
                                              child: Icon(
                                                statusIcon,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: statusBgColor,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                statusText,
                                                style: TextStyle(
                                                  color: statusIconColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
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
                      // Footer: jumlah user dan total pembayaran
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people,
                                color: isDark ? Colors.white70 : Colors.black54,
                                size: 18),
                            const SizedBox(width: 4),
                            Text('${users.length} total',
                                style: TextStyle(
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                    fontSize: 14)),
                            const Text(' | ', style: TextStyle(fontSize: 14)),
                            Icon(Icons.check_circle,
                                color: isDark
                                    ? Colors.green.shade300
                                    : Colors.green,
                                size: 18),
                            const SizedBox(width: 4),
                            Text('${users.length - _countUnpaidUsers()} paid',
                                style: TextStyle(
                                    color: isDark
                                        ? Colors.green.shade300
                                        : Colors.green,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold)),
                            const Text(' | ', style: TextStyle(fontSize: 14)),
                            Icon(Icons.cancel,
                                color:
                                    isDark ? Colors.red.shade300 : Colors.red,
                                size: 18),
                            const SizedBox(width: 4),
                            Text('${_countUnpaidUsers()} unpaid',
                                style: TextStyle(
                                    color: isDark
                                        ? Colors.red.shade300
                                        : Colors.red,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold)),
                          ],
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
    );
  }

  // Fixed syntax errors
  Widget _buildMethodChip(String method) {
    // Additional comment
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // More comments
    Color color = method.toLowerCase() == 'cash' ? Colors.green : Colors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? color.withOpacity(0.1) : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? color.withOpacity(0.3) : color.withOpacity(0.3)),
      ),
      child: Text(
        method,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> showSuccessDialog(BuildContext context, String message) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          contentPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
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
                      ? Colors.green.withOpacity(0.2)
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
                  color: isDark ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // Message
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              // OK Button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.done_rounded, size: 18),
                    label: const Text(
                      'OK',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
    );
  }

  void _showEditPaymentDialog(
      Map<String, dynamic> payment, Map<String, dynamic> user, {VoidCallback? onSuccess}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formKey = GlobalKey<FormState>();
    final amountController =
        TextEditingController(text: payment['amount']?.toString() ?? '');
    String dbMethod = payment['method']?.toString().toLowerCase() ?? 'cash';
    List<String> allowedMethods = ['cash', 'transfer', 'qris', 'e-wallet', 'titipan'];
    if (!allowedMethods.contains(dbMethod)) dbMethod = 'cash';
    String selectedMethod = dbMethod;
    DateTime paymentDate =
        DateTime.tryParse(payment['payment_date']?.toString() ?? '') ??
            DateTime.now();
    final noteController =
        TextEditingController(text: payment['note']?.toString() ?? '');
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text('Edit Pembayaran',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  )),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: amountController,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [CurrencyInputFormatter()],
                        decoration: InputDecoration(
                          labelText: 'Nominal (Rp)',
                          labelStyle: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                          prefixText: 'Rp ',
                          prefixStyle: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade300,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade300,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color:
                                  isDark ? Colors.blue.shade300 : Colors.blue,
                            ),
                          ),
                        ),
                        validator: (v) => v == null || v.isEmpty
                            ? 'Nominal wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        dropdownColor:
                            isDark ? const Color(0xFF2D2D2D) : Colors.white,
                        value: selectedMethod,
                        items: const [
                          DropdownMenuItem(value: 'cash', child: Text('Cash (Tunai)')),
                          DropdownMenuItem(value: 'transfer', child: Text('Transfer Bank')),
                          DropdownMenuItem(value: 'qris', child: Text('QRIS')),
                          DropdownMenuItem(value: 'e-wallet', child: Text('E-Wallet')),
                          DropdownMenuItem(value: 'titipan', child: Text('Titipan / Deposit')),
                        ],
                        onChanged: (v) {
                          setDialogState(() {
                            selectedMethod = v!;
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'Metode',
                          labelStyle: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade300,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade300,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color:
                                  isDark ? Colors.blue.shade300 : Colors.blue,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: paymentDate,
                            firstDate: DateTime(2020),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              paymentDate = picked;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Tanggal Pembayaran',
                            labelStyle: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color:
                                    isDark ? Colors.blue.shade300 : Colors.blue,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today,
                                  size: 18,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.blueGrey),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('EEEE, dd MMMM yyyy', 'id_ID')
                                    .format(paymentDate),
                                style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: noteController,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Catatan (opsional)',
                          labelStyle: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade300,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade300,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color:
                                  isDark ? Colors.blue.shade300 : Colors.blue,
                            ),
                          ),
                        ),
                        minLines: 1,
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text(
                    'BATAL',
                    style: TextStyle(
                      color: isDark ? Colors.blue.shade300 : Colors.blue,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          setDialogState(() {
                            isSubmitting = true;
                          });

                          try {
                            // Get router_id from RouterSessionProvider
                            final routerId = Provider.of<RouterSessionProvider>(
                                    context,
                                    listen: false)
                                .routerId;
                            if (routerId == null || routerId.isEmpty) {
                              throw Exception(
                                  'Router belum login. Silakan login dulu.');
                            }

                            final paymentId = payment['id'];
                            final userId = user['id'];
                            final amountRaw = amountController.text
                                .replaceAll('.', '')
                                .replaceAll(',', '');
                            final amount = double.tryParse(amountRaw) ?? 0;
                            final adminUsername =
                                Provider.of<RouterSessionProvider>(context,
                                        listen: false)
                                    .username;

                            final respData = await ApiService.updatePayment(
                              routerId: routerId,
                              id: int.parse(paymentId.toString()),
                              userId: userId.toString(),
                              amount: amount,
                              paymentDate:
                                  DateFormat('yyyy-MM-dd').format(paymentDate),
                              method: selectedMethod,
                              note: noteController.text,
                              adminUsername: adminUsername,
                              customerName: user['username'],
                            );

                            if (respData['success'] == true) {
                              Navigator.of(dialogContext).pop();
                              if (mounted) {
                                // Trigger Notification
                                try {
                                  final amountFixed = amount
                                      .toStringAsFixed(0)
                                      .replaceAllMapped(
                                          RegExp(
                                              r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                          (Match m) => '${m[1]}.');
                                  final dateStr = DateFormat('dd MMM yyyy')
                                      .format(paymentDate);

                                  final notifBody =
                                      "Nama : ${user['username']}\n"
                                      "Nominal : Rp. $amountFixed\n"
                                      "Metode : $selectedMethod\n"
                                      "Tanggal : $dateStr\n"
                                      "Catatan : ${noteController.text}\n"
                                      "Oleh : $adminUsername";

                                  await LogSyncService(this.context)
                                      .testNotification(
                                    title: "Pembayaran Diperbarui",
                                    body: notifBody,
                                  );
                                } catch (e) {
                                  debugPrint("Error showing notification: $e");
                                }

                                await showSuccessDialog(this.context,
                                    'Pembayaran berhasil diupdate!');
                                if (mounted) {
                                  // Update local object
                                  payment['amount'] = amount;
                                  payment['method'] = selectedMethod;
                                  payment['payment_date'] = DateFormat('yyyy-MM-dd').format(paymentDate);
                                  payment['note'] = noteController.text;
                                  if (onSuccess != null) onSuccess();
                                  
                                  // Refresh data setelah berhasil mengupdate pembayaran
                                  _loadUsers();
                                }
                              }
                            } else {
                              Navigator.of(dialogContext).pop();
                              if (context.mounted) {
                                CustomSnackbar.show(
                                  context: context,
                                  message: 'Gagal mengupdate pembayaran',
                                  additionalInfo:
                                      respData['error'] ?? 'Unknown error',
                                  isSuccess: false,
                                );
                              }
                            }
                          } catch (e) {
                            Navigator.of(dialogContext).pop();
                            if (context.mounted) {
                              CustomSnackbar.show(
                                context: context,
                                message: 'Error',
                                additionalInfo: e.toString(),
                                isSuccess: false,
                              );
                            }
                          } finally {
                            // Ensure the loading state is reset even if an error occurs
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                isSubmitting = false;
                              });
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('SIMPAN'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeletePayment(
      Map<String, dynamic> payment, Map<String, dynamic> user, {VoidCallback? onSuccess}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warning, color: Colors.red),
              const SizedBox(width: 10),
              Text('Konfirmasi Hapus',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  )),
            ],
          ),
          content: Text(
            'Apakah Anda yakin ingin menghapus pembayaran ini?',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'BATAL',
                style: TextStyle(
                  color: isDark ? Colors.blue.shade300 : Colors.blue,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.red.shade700 : Colors.red,
                  foregroundColor: Colors.white,
              ),
              onPressed: () async {
                try {
                  // Get router_id from RouterSessionProvider
                  final routerId =
                      Provider.of<RouterSessionProvider>(context, listen: false)
                          .routerId;
                  if (routerId == null || routerId.isEmpty) {
                    throw Exception('Router belum login. Silakan login dulu.');
                  }

                  final paymentId = payment['id'];
                  final adminUsername =
                      Provider.of<RouterSessionProvider>(context, listen: false)
                          .username;

                  final respData = await ApiService.deletePayment(
                    routerId: routerId,
                    id: int.parse(paymentId.toString()),
                    adminUsername: adminUsername,
                    customerName: user['username'],
                  );

                  if (respData['success'] == true) {
                    Navigator.of(dialogContext).pop();
                    if (mounted) {
                      // Trigger Notification
                      try {
                        final amountVal = double.tryParse(
                                payment['amount']?.toString() ?? '0') ??
                            0;
                        final amountFixed = amountVal
                            .toStringAsFixed(0)
                            .replaceAllMapped(
                                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                (Match m) => '${m[1]}.');
                        final method = payment['method']?.toString() ?? '-';
                        final pDateStr =
                            payment['payment_date']?.toString() ?? '-';
                        String dateDisplay = pDateStr;
                        try {
                          final pDate = DateTime.parse(pDateStr);
                          dateDisplay = DateFormat('dd MMM yyyy').format(pDate);
                        } catch (_) {}

                        final note = payment['note']?.toString() ?? '-';
                        final notifBody = "Nama : ${user['username']}\n"
                            "Nominal : Rp. $amountFixed\n"
                            "Metode : $method\n"
                            "Tanggal : $dateDisplay\n"
                            "Catatan : $note\n"
                            "Oleh : $adminUsername";

                        await LogSyncService(this.context).testNotification(
                          title: "Pembayaran Dihapus",
                          body: notifBody,
                        );
                      } catch (e) {
                        debugPrint("Error showing notification: $e");
                      }

                      await showSuccessDialog(
                          context, 'Pembayaran berhasil dihapus!');
                      if (mounted) {
                        // Remove from local list
                        if (user['payments'] is List) {
                          (user['payments'] as List).removeWhere((item) => item['id'] == payment['id']);
                        }
                        if (onSuccess != null) onSuccess();
                        
                        // Refresh data setelah berhasil menghapus pembayaran
                        _loadUsers();
                      }
                    }
                  } else {
                    Navigator.of(dialogContext).pop();
                    if (context.mounted) {
                      CustomSnackbar.show(
                        context: context,
                        message: 'Gagal menghapus pembayaran',
                        additionalInfo: respData['error'] ?? 'Unknown error',
                        isSuccess: false,
                      );
                    }
                  }
                } catch (e) {
                  Navigator.of(dialogContext).pop();
                  if (context.mounted) {
                    CustomSnackbar.show(
                      context: context,
                      message: 'Error',
                      additionalInfo: e.toString(),
                      isSuccess: false,
                    );
                  }
                }
              },
              child: const Text('HAPUS'),
            ),
          ],
        );
      },
    );
  }

  List<Map<String, dynamic>> _filteredPayments(Map<String, dynamic> user) {
    final payments = user['payments'] as List;
    if (_showAllPayments) {
      // Tampilkan semua pembayaran dengan urutan terbaru dulu
      final sortedPayments = payments.cast<Map<String, dynamic>>().toList();
      sortedPayments.sort((a, b) {
        final dateA =
            DateTime.tryParse(a['payment_date'] ?? '') ?? DateTime(2000);
        final dateB =
            DateTime.tryParse(b['payment_date'] ?? '') ?? DateTime(2000);
        return dateB.compareTo(dateA); // Terbaru dulu
      });
      return sortedPayments;
    }

    // Filter berdasarkan bulan yang dipilih
    final filtered = payments
        .where((p) {
          final paymentDate = DateTime.tryParse(p['payment_date'] ?? '');
          return paymentDate != null &&
              paymentDate.year == _selectedMonth.year &&
              paymentDate.month == _selectedMonth.month;
        })
        .cast<Map<String, dynamic>>()
        .toList();

    // Urutkan berdasarkan tanggal terbaru dulu
    filtered.sort((a, b) {
      final dateA =
          DateTime.tryParse(a['payment_date'] ?? '') ?? DateTime(2000);
      final dateB =
          DateTime.tryParse(b['payment_date'] ?? '') ?? DateTime(2000);
      return dateB.compareTo(dateA); // Terbaru dulu
    });

    return filtered;
  }

  List<Map<String, dynamic>> _filteredSortedUsers() {
    List<Map<String, dynamic>> filtered = _users;

    // Filter berdasarkan pencarian
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((u) {
        // Cek di username, profile, atau nominal
        return (u['username'] ?? '').toLowerCase().contains(q) ||
            (u['profile'] ?? '').toLowerCase().contains(q) ||
            (u['nominal'] ?? '').toString().toLowerCase().contains(q) ||
            // Cek juga di pembayaran
            (u['payments'] as List).any((p) {
              return (p['amount'] ?? '').toString().contains(q) ||
                  (p['method'] ?? '').toString().toLowerCase().contains(q) ||
                  (p['note'] ?? '').toString().toLowerCase().contains(q);
            });
      }).toList();
    }

    // Urutkan berdasarkan opsi yang dipilih
    switch (_sortOption) {
      case 'nameDesc':
        filtered.sort(
            (a, b) => (b['username'] ?? '').compareTo(a['username'] ?? ''));
        break;
      case 'statusPaid':
        filtered.sort((a, b) {
          final paidA = _hasUserPaidForSelectedMonth(a);
          final paidB = _hasUserPaidForSelectedMonth(b);
          if (paidA == paidB) {
            return (a['username'] ?? '').compareTo(b['username'] ?? '');
          }
          return paidB ? 1 : -1; // Paid first
        });
        break;
      case 'statusUnpaid':
        filtered.sort((a, b) {
          final paidA = _hasUserPaidForSelectedMonth(a);
          final paidB = _hasUserPaidForSelectedMonth(b);
          if (paidA == paidB) {
            return (a['username'] ?? '').compareTo(b['username'] ?? '');
          }
          return paidA ? 1 : -1; // Unpaid first
        });
        break;
      case 'statusTitipan':
        filtered.sort((a, b) {
          bool isTitipanA = (a['payments'] as List).any((p) {
             final dt = DateTime.tryParse(p['payment_date'] ?? '');
             return dt != null && dt.year == _selectedMonth.year && dt.month == _selectedMonth.month && (p['method']?.toString().toLowerCase() == 'titipan');
          });
          bool isTitipanB = (b['payments'] as List).any((p) {
             final dt = DateTime.tryParse(p['payment_date'] ?? '');
             return dt != null && dt.year == _selectedMonth.year && dt.month == _selectedMonth.month && (p['method']?.toString().toLowerCase() == 'titipan');
          });
          if (isTitipanA == isTitipanB) {
            return (a['username'] ?? '').compareTo(b['username'] ?? '');
          }
          return isTitipanA ? -1 : 1; // Titipan first
        });
        break;
      case 'nameAsc':
      default:
        filtered.sort(
            (a, b) => (a['username'] ?? '').compareTo(b['username'] ?? ''));
        break;
    }

    return filtered;
  }

  String _getUserPaymentStatusForSelectedMonth(Map<String, dynamic> user) {
    for (var p in (user['payments'] as List)) {
      final paymentDate = DateTime.tryParse(p['payment_date'] ?? '');
      if (paymentDate != null &&
          paymentDate.year == _selectedMonth.year &&
          paymentDate.month == _selectedMonth.month) {
        if (p['method']?.toString().toLowerCase() == 'titipan') {
          return 'titipan';
        }
        return 'lunas';
      }
    }
    return 'belum';
  }

  // Method to check if user has paid for the selected month
  bool _hasUserPaidForSelectedMonth(Map<String, dynamic> user) {
    return _getUserPaymentStatusForSelectedMonth(user) != 'belum';
  }

  String formatLastLogout(String? lastLogout) {
    if (lastLogout == null || lastLogout.isEmpty) {
      return '-';
    }

    try {
      final dateTime = DateTime.parse(lastLogout);
      return DateFormat('dd/MM/yyyy HH:mm', 'id_ID').format(dateTime);
    } catch (e) {
      return lastLogout;
    }
  }

  int _countUnpaidUsers() {
    int count = 0;
    for (var user in _filteredSortedUsers()) {
      if (!_hasUserPaidForSelectedMonth(user)) {
        count++;
      }
    }
    return count;
  }

  @override
  void dispose() {
    _searchUserController.dispose();
    super.dispose();
  }
}
