import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/table_model.dart';
import '../models/menu_item_model.dart';
import '../models/order_model.dart';
import '../models/kot_model.dart';
import 'mock_data.dart';

class ApiService {
  String host;
  int port;
  bool useDemoMode;

  ApiService({
    this.host = '127.0.0.1',
    this.port = 4000,
    this.useDemoMode = true,
  });

  String get baseUrl => 'http://$host:$port/api';

  Future<bool> checkHealth() async {
    if (useDemoMode) return true;
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<RestaurantTable>> fetchTables() async {
    if (useDemoMode) {
      await Future.delayed(const Duration(milliseconds: 250));
      return MockData.getInitialTables();
    }
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/tables'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => RestaurantTable.fromJson(json)).toList();
      }
    } catch (_) {}
    return MockData.getInitialTables();
  }

  Future<List<MenuItem>> fetchMenu() async {
    if (useDemoMode) {
      await Future.delayed(const Duration(milliseconds: 200));
      return MockData.getInitialMenu();
    }
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/menu'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => MenuItem.fromJson(json)).toList();
      }
    } catch (_) {}
    return MockData.getInitialMenu();
  }

  Future<KotTicket> submitKot({
    required String orderId,
    required String tableId,
    required String tableName,
    required List<OrderItem> itemsToSend,
    required String idempotencyKey,
  }) async {
    if (useDemoMode) {
      await Future.delayed(const Duration(milliseconds: 400));
      return KotTicket(
        id: 'kot-${DateTime.now().millisecondsSinceEpoch}',
        kotNumber: 'KOT-${DateTime.now().minute}${DateTime.now().second}',
        orderId: orderId,
        tableId: tableId,
        tableName: tableName,
        items: itemsToSend
            .map((item) => KotItem(
                  name: item.name,
                  quantity: item.quantity,
                  notes: item.notes,
                  variant: item.selectedVariant,
                ))
            .toList(),
        timestamp: DateTime.now(),
        status: KotStatus.printed,
      );
    }

    final response = await http.post(
      Uri.parse('$baseUrl/orders/$orderId/kot'),
      headers: {
        'Content-Type': 'application/json',
        'Idempotency-Key': idempotencyKey,
      },
      body: jsonEncode({
        'tableId': tableId,
        'items': itemsToSend.map((i) => i.toJson()).toList(),
      }),
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return KotTicket.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to send KOT: ${response.body}');
    }
  }
}
