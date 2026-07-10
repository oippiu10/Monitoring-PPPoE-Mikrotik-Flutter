import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/expense_model.dart';
import '../services/expense_service.dart';
import '../services/config_service.dart';
import '../providers/router_session_provider.dart';
import '../widgets/gradient_container.dart';
import 'expense_summary_screen.dart';

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

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({Key? key}) : super(key: key);

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  List<ExpenseModel> _expenses = [];
  bool _isLoading = false;
  
  // Filter variables
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  String _searchQuery = '';
  String _filterCategory = 'Semua Kategori';
  String _baseUrl = '';
  
  final TextEditingController _searchController = TextEditingController();
  
  final List<String> _categories = [
    'Operasional', 
    'Peralatan/Kabel', 
    'Bensin/Transport', 
    'Gaji/Upah', 
    'ISP/Bandwidth', 
    'Lainnya'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExpenses();
      _loadBaseUrl();
    });
  }

  Future<void> _loadBaseUrl() async {
    final url = await ConfigService.getBaseUrl();
    if (mounted) {
      setState(() {
        _baseUrl = url;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExpenses() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final routerId = Provider.of<RouterSessionProvider>(context, listen: false).routerId;
      if (routerId == null) throw Exception("Router belum login");

      final data = await ExpenseService.getExpenses(routerId, _selectedMonth, _selectedYear);
      
      // Sort newest date first, then newest ID (latest input) first
      data.sort((a, b) {
        int cmp = b.spentAt.compareTo(a.spentAt);
        if (cmp == 0) return b.id.compareTo(a.id);
        return cmp;
      });

      setState(() {
        _expenses = data;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<ExpenseModel> get _filteredExpenses {
    return _expenses.where((expense) {
      final matchCategory = _filterCategory == 'Semua Kategori' || expense.category == _filterCategory;
      final matchSearch = _searchQuery.isEmpty || 
          expense.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          expense.note.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchCategory && matchSearch;
    }).toList();
  }

  void _showFilterModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Filter Data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 20),
                  
                  // Bulan Filter
                  Text('Bulan & Tahun', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.chevron_left, color: isDark ? Colors.white : Colors.black87),
                        onPressed: () {
                          setModalState(() {
                            if (_selectedMonth == 1) {
                              _selectedMonth = 12;
                              _selectedYear--;
                            } else {
                              _selectedMonth--;
                            }
                          });
                        },
                      ),
                      Text(
                        '${DateFormat('MMMM').format(DateTime(0, _selectedMonth))} $_selectedYear',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
                      ),
                      IconButton(
                        icon: Icon(Icons.chevron_right, color: isDark ? Colors.white : Colors.black87),
                        onPressed: () {
                          setModalState(() {
                            if (_selectedMonth == 12) {
                              _selectedMonth = 1;
                              _selectedYear++;
                            } else {
                              _selectedMonth++;
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Kategori Filter
                  Text('Kategori', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _filterCategory,
                        dropdownColor: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                        items: ['Semua Kategori', ..._categories].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => _filterCategory = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Terapkan Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {}); // Trigger rebuild
                        _loadExpenses(); // Reload data with new month/year
                      },
                      child: const Text('Terapkan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      }
    );
  }

  Future<void> _showExpenseDialog({ExpenseModel? expense}) async {
    final isEditing = expense != null;
    String selectedCategory = expense?.category ?? 'Operasional';
    if (!_categories.contains(selectedCategory)) {
      selectedCategory = 'Lainnya';
    }
    
    final initialAmount = expense != null ? NumberFormat("#,##0", "id_ID").format(expense.amount) : '';
    final amountController = TextEditingController(text: initialAmount);
    final noteController = TextEditingController(text: expense?.note ?? '');
    DateTime selectedDate = expense?.spentAt ?? DateTime.now();
    File? selectedImage;
    final ImagePicker _picker = ImagePicker();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(isEditing ? 'Ubah Pengeluaran' : 'Tambah Pengeluaran', 
                  style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      dropdownColor: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                      value: selectedCategory,
                      items: _categories.map((c) => DropdownMenuItem(
                        value: c, 
                        child: Text(c, style: TextStyle(color: isDark ? Colors.white : Colors.black87))
                      )).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedCategory = val);
                      },
                      decoration: InputDecoration(
                        labelText: 'Kategori',
                        labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? Colors.blue.shade300 : Colors.blue),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: amountController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        CurrencyInputFormatter(),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Nominal',
                        labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                        prefixText: 'Rp ',
                        prefixStyle: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? Colors.blue.shade300 : Colors.blue),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: noteController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Keterangan',
                        labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? Colors.blue.shade300 : Colors.blue),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (date != null) setDialogState(() => selectedDate = date);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat('dd MMM yyyy').format(selectedDate),
                                style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                            Icon(Icons.calendar_today, size: 18, color: isDark ? Colors.white70 : Colors.black54),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Image Picker Section
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300, style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(12),
                        color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bukti Pembayaran / Struk (Opsional)', style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54)),
                          const SizedBox(height: 12),
                          if (selectedImage != null)
                            Stack(
                              alignment: Alignment.topRight,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(selectedImage!, height: 120, width: double.infinity, fit: BoxFit.cover),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.cancel, color: Colors.red),
                                  onPressed: () => setDialogState(() => selectedImage = null),
                                )
                              ],
                            )
                          else if (isEditing && expense!.receiptImage != null)
                            Stack(
                              alignment: Alignment.topRight,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: '$_baseUrl/${expense.receiptImage}',
                                    height: 120,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                                    errorWidget: (context, url, error) => const Icon(Icons.error),
                                  ),
                                ),
                              ],
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final XFile? image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                                      if (image != null) setDialogState(() => selectedImage = File(image.path));
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: isDark ? Colors.blue.shade700 : Colors.blue.shade300, width: 1.5),
                                        borderRadius: BorderRadius.circular(10),
                                        color: isDark ? Colors.blue.withOpacity(0.1) : Colors.blue.shade50,
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(Icons.camera_alt, color: isDark ? Colors.blue.shade300 : Colors.blue.shade700, size: 28),
                                          const SizedBox(height: 6),
                                          Text('Kamera', style: TextStyle(color: isDark ? Colors.blue.shade300 : Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                                      if (image != null) setDialogState(() => selectedImage = File(image.path));
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: isDark ? Colors.purple.shade700 : Colors.purple.shade300, width: 1.5),
                                        borderRadius: BorderRadius.circular(10),
                                        color: isDark ? Colors.purple.withOpacity(0.1) : Colors.purple.shade50,
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(Icons.photo_library, color: isDark ? Colors.purple.shade300 : Colors.purple.shade700, size: 28),
                                          const SizedBox(height: 6),
                                          Text('Galeri', style: TextStyle(color: isDark ? Colors.purple.shade300 : Colors.purple.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('Batal', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final routerId = Provider.of<RouterSessionProvider>(context, listen: false).routerId;
                    final username = Provider.of<RouterSessionProvider>(context, listen: false).username;
                    if (routerId == null) return;
                    
                    final amountRaw = amountController.text.replaceAll('.', '').replaceAll(',', '');
                    final amount = double.tryParse(amountRaw) ?? 0;
                    final note = noteController.text;

                    if (amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nominal harus lebih dari Rp 0')));
                      return;
                    }

                    Navigator.pop(dialogContext);
                    setState(() => _isLoading = true);

                    bool success;
                    if (isEditing) {
                      success = await ExpenseService.editExpense(routerId, expense.id, selectedCategory, amount, note, selectedDate, receiptImage: selectedImage);
                    } else {
                      success = await ExpenseService.addExpense(routerId, selectedCategory, amount, note, selectedDate, createdBy: username, receiptImage: selectedImage);
                    }

                    if (success) {
                      _loadExpenses();
                    } else {
                      setState(() => _isLoading = false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menyimpan pengeluaran')));
                      }
                    }
                  },
                  child: const Text('Simpan', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _deleteExpense(ExpenseModel expense) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus Pengeluaran', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        content: Text('Hapus catatan pengeluaran "${expense.note.isNotEmpty ? expense.note : expense.category}"?',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: Text('Batal', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Hapus', style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );

    if (confirm == true) {
      final routerId = Provider.of<RouterSessionProvider>(context, listen: false).routerId;
      if (routerId == null) return;
      
      setState(() => _isLoading = true);
      final success = await ExpenseService.deleteExpense(routerId, expense.id);
      if (success) {
        _loadExpenses();
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menghapus pengeluaran')));
        }
      }
    }
  }

  void _showExpenseActionModal(ExpenseModel expense, NumberFormat formatCurrency, bool isDark) {
    final currentUsername = Provider.of<RouterSessionProvider>(context, listen: false).username ?? '';
    final canEditDelete = currentUsername.toLowerCase() == 'admin' || 
                          expense.createdBy == null || 
                          expense.createdBy!.isEmpty || 
                          expense.createdBy == currentUsername;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.45,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (_, controller) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
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
                    // Header Category
                    Row(
                      children: [
                        Icon(_getCategoryIcon(expense.category), color: isDark ? Colors.red.shade300 : Colors.red, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(expense.category, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                              if (expense.createdBy != null && expense.createdBy!.isNotEmpty)
                                Text('Oleh: ${expense.createdBy}', style: TextStyle(color: isDark ? Colors.blue.shade300 : Colors.blue.shade700, fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Icon(Icons.receipt_long, color: isDark ? Colors.green.shade400 : Colors.green.shade700),
                        const SizedBox(width: 8),
                        Text('Detail Pengeluaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // The Card
                    Card(
                      margin: EdgeInsets.zero,
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(color: isDark ? Colors.red.shade700 : Colors.red.shade400, width: 2),
                      ),
                      color: isDark ? Colors.red.shade900.withOpacity(0.3) : Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    formatCurrency.format(expense.amount),
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : Colors.black87),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.red.shade900 : Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('Pengeluaran', style: TextStyle(color: isDark ? Colors.red.shade300 : Colors.red, fontWeight: FontWeight.bold, fontSize: 11)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.calendar_today, size: 16, color: isDark ? Colors.grey.shade400 : Colors.blueGrey.shade300),
                                const SizedBox(width: 6),
                                Text(
                                  'Tanggal: ${DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(expense.spentAt)}',
                                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
                                ),
                              ],
                            ),
                            if (expense.note.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.notes, size: 16, color: isDark ? Colors.grey.shade400 : Colors.blueGrey.shade300),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Keterangan: ${expense.note}',
                                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (expense.receiptImage != null && expense.receiptImage!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text('Bukti Pembayaran / Struk:', style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54)),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => Dialog(
                                      backgroundColor: Colors.transparent,
                                      child: Stack(
                                        alignment: Alignment.topRight,
                                        children: [
                                          InteractiveViewer(
                                            child: CachedNetworkImage(
                                              imageUrl: '$_baseUrl/${expense.receiptImage}',
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.close, color: Colors.white, size: 30),
                                            onPressed: () => Navigator.pop(context),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: CachedNetworkImage(
                                    imageUrl: '$_baseUrl/${expense.receiptImage}',
                                    height: 150,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      height: 150,
                                      color: isDark ? Colors.black12 : Colors.grey.shade200,
                                      child: const Center(child: CircularProgressIndicator()),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      height: 100,
                                      color: isDark ? Colors.black12 : Colors.grey.shade200,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.broken_image, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400, size: 40),
                                          const SizedBox(height: 8),
                                          Text('Gambar tidak ditemukan', style: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade600, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            if (canEditDelete)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _showExpenseDialog(expense: expense);
                                    },
                                    icon: Icon(Icons.edit, size: 18, color: isDark ? Colors.blue.shade300 : Colors.blue.shade800),
                                    label: Text('Edit', style: TextStyle(color: isDark ? Colors.blue.shade300 : Colors.blue.shade800)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade50,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _deleteExpense(expense);
                                    },
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.white),
                                    label: const Text('Hapus', style: TextStyle(color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ],
                              )
                            else
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.grey.shade800.withOpacity(0.5) : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.lock_outline, size: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Hanya pembuat atau admin yang dapat mengubah.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                        ),
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
                  ],
                ),
              ),
            ),
          ),
        );
      }
    );
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

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    double totalExpense = _filteredExpenses.fold(0, (sum, item) => sum + item.amount);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Pengeluaran', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.summarize),
              tooltip: 'Ringkasan Pengeluaran',
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ExpenseSummaryScreen()),
                );
                if (result != null && result is Map<String, int>) {
                  setState(() {
                    _selectedMonth = result['month']!;
                    _selectedYear = result['year']!;
                    _filterCategory = 'Semua Kategori';
                    _searchQuery = '';
                    _searchController.clear();
                  });
                  _loadExpenses();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadExpenses,
            ),
          ],
        ),
        body: Column(
          children: [
            // Search Bar area (Identical to Tagihan/Billing)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? Colors.black26 : Colors.grey.withOpacity(0.1),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          hintText: 'Cari...',
                          hintStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade500),
                          prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, size: 20),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                  // Filter Button
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? Colors.black26 : Colors.grey.withOpacity(0.1),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(Icons.filter_alt, color: isDark ? Colors.blue.shade300 : Colors.blue.shade700, size: 24),
                      tooltip: 'Filter',
                      onPressed: _showFilterModal,
                    ),
                  ),
                ],
              ),
            ),
            
            // Current Filter indicator (Bulan)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    'Data: ${DateFormat('MMM yyyy').format(DateTime(_selectedYear, _selectedMonth))} | $_filterCategory',
                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            // Main Content Area
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _filteredExpenses.isEmpty
                  ? Center(child: Text('Tidak ada pengeluaran', style: TextStyle(color: isDark ? Colors.white70 : Colors.white54)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: _filteredExpenses.length,
                      itemBuilder: (context, index) {
                        final expense = _filteredExpenses[index];
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
                              onTap: () => _showExpenseActionModal(expense, formatCurrency, isDark),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                child: Row(
                                  children: [
                                    // Icon Box
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
                                      child: Icon(_getCategoryIcon(expense.category), color: isDark ? Colors.red.shade300 : Colors.red.shade600, size: 24),
                                    ),
                                    const SizedBox(width: 14),
                                    // Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            expense.category,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: isDark ? Colors.white : Colors.black87,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            expense.note.isNotEmpty ? expense.note : DateFormat('dd MMM yyyy').format(expense.spentAt),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? Colors.grey.shade400 : Colors.blueGrey.shade400,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (expense.createdBy != null && expense.createdBy!.isNotEmpty) ...[
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
                                                    expense.createdBy!,
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
                                          formatCurrency.format(expense.amount),
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
            
            // Footer Identical to Billing
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, -2),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long, color: isDark ? Colors.white70 : Colors.black54, size: 18),
                    const SizedBox(width: 4),
                    Text('${_filteredExpenses.length} transaksi', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14)),
                    const Text('  |  ', style: TextStyle(fontSize: 14, color: Colors.grey)),
                    Icon(Icons.money_off, color: isDark ? Colors.red.shade300 : Colors.red, size: 18),
                    const SizedBox(width: 4),
                    Text(formatCurrency.format(totalExpense),
                        style: TextStyle(color: isDark ? Colors.red.shade300 : Colors.red, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 60), // Angkat FAB agar tidak tertutup footer
          child: FloatingActionButton.extended(
            onPressed: () => _showExpenseDialog(),
            backgroundColor: isDark ? Colors.blue.shade700 : Colors.blue,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Tambah Pengeluaran', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}
