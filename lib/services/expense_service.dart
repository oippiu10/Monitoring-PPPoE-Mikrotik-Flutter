import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/expense_model.dart';
import 'config_service.dart';

class ExpenseService {
  static Future<List<ExpenseModel>> getExpenses(String routerId, int month, int year) async {
    final baseUrl = await ConfigService.getBaseUrl();
    final url = Uri.parse('$baseUrl/expense_operations.php').replace(
      queryParameters: {
        'action': 'list',
        'router_id': routerId,
        'month': month.toString(),
        'year': year.toString(),
      }
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> list = data['data'];
          return list.map((e) => ExpenseModel.fromJson(e)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error getting expenses: $e');
      return [];
    }
  }

  static Future<bool> addExpense(String routerId, String category, double amount, String note, DateTime spentAt, {String? createdBy, File? receiptImage}) async {
    final baseUrl = await ConfigService.getBaseUrl();
    final url = Uri.parse('$baseUrl/expense_operations.php').replace(
      queryParameters: {
        'action': 'add',
        'router_id': routerId,
      }
    );

    try {
      if (receiptImage == null) {
        final response = await http.post(
          url,
          body: jsonEncode({
            'category': category,
            'amount': amount,
            'note': note,
            'spent_at': spentAt.toIso8601String(),
            'created_by': createdBy,
          }),
          headers: {'Content-Type': 'application/json'},
        );
        final data = jsonDecode(response.body);
        return data['success'] == true;
      } else {
        var request = http.MultipartRequest('POST', url);
        request.fields['category'] = category;
        request.fields['amount'] = amount.toString();
        request.fields['note'] = note;
        request.fields['spent_at'] = spentAt.toIso8601String();
        if (createdBy != null) request.fields['created_by'] = createdBy;
        
        request.files.add(await http.MultipartFile.fromPath('receipt_image', receiptImage.path));
        
        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
    } catch (e) {
      print('Error adding expense: $e');
      return false;
    }
  }

  static Future<bool> editExpense(String routerId, int id, String category, double amount, String note, DateTime spentAt, {File? receiptImage}) async {
    final baseUrl = await ConfigService.getBaseUrl();
    final url = Uri.parse('$baseUrl/expense_operations.php').replace(
      queryParameters: {
        'action': 'edit',
        'router_id': routerId,
      }
    );

    try {
      if (receiptImage == null) {
        final response = await http.post(
          url,
          body: jsonEncode({
            'id': id,
            'category': category,
            'amount': amount,
            'note': note,
            'spent_at': spentAt.toIso8601String(),
          }),
          headers: {'Content-Type': 'application/json'},
        );
        final data = jsonDecode(response.body);
        return data['success'] == true;
      } else {
        var request = http.MultipartRequest('POST', url);
        request.fields['id'] = id.toString();
        request.fields['category'] = category;
        request.fields['amount'] = amount.toString();
        request.fields['note'] = note;
        request.fields['spent_at'] = spentAt.toIso8601String();
        
        request.files.add(await http.MultipartFile.fromPath('receipt_image', receiptImage.path));
        
        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
    } catch (e) {
      print('Error editing expense: $e');
      return false;
    }
  }

  static Future<bool> deleteExpense(String routerId, int id) async {
    final baseUrl = await ConfigService.getBaseUrl();
    final url = Uri.parse('$baseUrl/expense_operations.php').replace(
      queryParameters: {
        'action': 'delete',
        'router_id': routerId,
        'id': id.toString(),
      }
    );

    try {
      final response = await http.get(url);
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      print('Error deleting expense: $e');
      return false;
    }
  }
  static Future<List<Map<String, dynamic>>> fetchExpenseSummary(String routerId) async {
    final baseUrl = await ConfigService.getBaseUrl();
    final url = Uri.parse('$baseUrl/expense_operations.php').replace(
      queryParameters: {
        'action': 'summary',
        'router_id': routerId,
      }
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> rawList = data['data'];
          return rawList.map((item) {
            final itemMap = Map<String, dynamic>.from(item as Map);
            return {
              'month': int.tryParse(itemMap['month'].toString()) ?? 0,
              'year': int.tryParse(itemMap['year'].toString()) ?? 0,
              'total': double.tryParse(itemMap['total'].toString()) ?? 0.0,
              'count': int.tryParse(itemMap['count'].toString()) ?? 0,
            };
          }).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error getting expense summary: $e');
      return [];
    }
  }
}
