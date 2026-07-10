class ExpenseModel {
  final int id;
  final String routerId;
  final String category;
  final double amount;
  final String note;
  final DateTime spentAt;
  final String? createdBy;
  final String? receiptImage;

  ExpenseModel({
    required this.id,
    required this.routerId,
    required this.category,
    required this.amount,
    required this.note,
    required this.spentAt,
    this.createdBy,
    this.receiptImage,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: int.parse(json['id'].toString()),
      routerId: json['router_id']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      note: json['note']?.toString() ?? '',
      spentAt: json['spent_at'] != null 
          ? DateTime.parse(json['spent_at'].toString()) 
          : DateTime.now(),
      createdBy: json['created_by']?.toString(),
      receiptImage: json['receipt_image']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'router_id': routerId,
      'category': category,
      'amount': amount,
      'note': note,
      'spent_at': spentAt.toIso8601String(),
      'created_by': createdBy,
      'receipt_image': receiptImage,
    };
  }
}
