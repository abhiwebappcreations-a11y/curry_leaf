import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/table_model.dart';
import '../models/order_model.dart';
import '../models/bill_model.dart';
import '../models/printer_model.dart';
import '../models/menu_model.dart';

class SystemHealthInfo {
  final bool isServerHealthy;
  final bool isDatabaseHealthy;
  final String licenseStatus;
  final int daysRemaining;

  SystemHealthInfo({
    required this.isServerHealthy,
    required this.isDatabaseHealthy,
    required this.licenseStatus,
    required this.daysRemaining,
  });
}

class ApiClient {
  final String baseUrl;

  ApiClient({this.baseUrl = 'http://127.0.0.1:4000/api'});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'X-Device-Id': 'dev_counter_01',
    'X-Device-Role': 'counter',
    'X-Api-Key': 'counter_dev_token',
  };

  /// Generates a compliant RFC4122 UUIDv4 for Idempotency-Key
  static String generateUuidV4() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // Version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variant RFC4122
    final hexChars =
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).toList();
    return '${hexChars.sublist(0, 4).join()}-${hexChars.sublist(4, 6).join()}-${hexChars.sublist(6, 8).join()}-${hexChars.sublist(8, 10).join()}-${hexChars.sublist(10, 16).join()}';
  }

  Future<SystemHealthInfo> getHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'), headers: _headers)
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] ?? decoded;
        final components = data['components'] as Map<String, dynamic>?;

        final isServer = data['status'] == 'healthy' ||
            components?['apiServer']?['status'] == 'online';
        final isDb = components?['database']?['status'] == 'connected' ||
            data['database'] == 'connected';

        final lic = components?['license'] as Map<String, dynamic>? ??
            data['license'] as Map<String, dynamic>?;
        final licStatus = lic?['status']?.toString().toUpperCase() == 'ACTIVE'
            ? 'Active (Licensed to Curry Leaf Fine Dine)'
            : (lic?['status']?.toString() ?? 'Active');
        final days = lic?['daysRemaining'] as int? ?? 365;

        return SystemHealthInfo(
          isServerHealthy: isServer,
          isDatabaseHealthy: isDb,
          licenseStatus: licStatus,
          daysRemaining: days,
        );
      }
    } catch (_) {}

    return SystemHealthInfo(
      isServerHealthy: false,
      isDatabaseHealthy: false,
      licenseStatus: 'Connecting to Local API (127.0.0.1:4000)...',
      daysRemaining: 365,
    );
  }

  Future<List<RestaurantTable>?> getTables() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/tables'), headers: _headers)
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> list;
        if (decoded is Map<String, dynamic>) {
          list = (decoded['data']?['tables'] ?? decoded['tables'] ?? []) as List<dynamic>;
        } else if (decoded is List) {
          list = decoded;
        } else {
          list = [];
        }
        if (list.isNotEmpty) {
          return list.map((json) => RestaurantTable.fromJson(json as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {}
    return null;
  }

  Future<List<RestaurantOrder>?> getActiveOrders() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/orders?status=active'), headers: _headers)
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> list;
        if (decoded is Map<String, dynamic>) {
          list = (decoded['data']?['orders'] ?? decoded['orders'] ?? []) as List<dynamic>;
        } else if (decoded is List) {
          list = decoded;
        } else {
          list = [];
        }
        if (list.isNotEmpty) {
          return list.map((json) => RestaurantOrder.fromJson(json as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {}
    return null;
  }

  Future<List<ThermalPrinterConfig>?> getPrinters() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/printers'), headers: _headers)
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> list;
        if (decoded is Map<String, dynamic>) {
          list = (decoded['data']?['printers'] ?? decoded['printers'] ?? []) as List<dynamic>;
        } else if (decoded is List) {
          list = decoded;
        } else {
          list = [];
        }
        if (list.isNotEmpty) {
          return list.map((json) => ThermalPrinterConfig.fromJson(json as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {}
    return null;
  }

  Future<List<MenuItem>?> getMenu() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/menu'), headers: _headers)
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<MenuItem> items = [];
        if (decoded is Map<String, dynamic>) {
          final data = decoded['data'] ?? decoded;
          if (data['menu'] is List) {
            for (var cat in data['menu'] as List) {
              final catName = (cat['name'] ?? 'General').toString();
              if (cat['items'] is List) {
                for (var item in cat['items'] as List) {
                  final map = Map<String, dynamic>.from(item as Map);
                  map['category'] = catName;
                  items.add(MenuItem.fromJson(map));
                }
              }
            }
          }
        }
        if (items.isNotEmpty) return items;
      }
    } catch (_) {}
    return null;
  }

  Future<RestaurantBill?> generateBill(String orderId, {int discountPaise = 0}) async {
    final idempotencyKey = generateUuidV4();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/orders/$orderId/bill'),
        headers: {
          ..._headers,
          'Idempotency-Key': idempotencyKey,
        },
        body: jsonEncode({
          'discountPaise': discountPaise,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        final billJson = (decoded['data']?['bill'] ?? decoded['bill'] ?? decoded) as Map<String, dynamic>;
        return RestaurantBill.fromJson(billJson);
      }
    } catch (_) {}
    return null;
  }

  Future<bool> settlePayment({
    required String billId,
    required String method,
    required int amountPaise,
    String? reference,
  }) async {
    final idempotencyKey = generateUuidV4();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/bills/$billId/payments'),
        headers: {
          ..._headers,
          'Idempotency-Key': idempotencyKey,
        },
        body: jsonEncode({
          'method': method.toUpperCase(),
          'paymentMethod': method.toLowerCase(),
          'amountPaise': amountPaise,
          'idempotencyKey': idempotencyKey,
          'referenceNumber': reference ?? '',
          'notes': 'Settled by Cashier Deepa',
        }),
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> testPrint(String printerId) async {
    final target = (printerId.contains('kot') || printerId.contains('kitchen'))
        ? 'kitchen_kot'
        : 'counter_bill';
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/printers/test-print'),
        headers: _headers,
        body: jsonEncode({
          'printerId': printerId,
          'targetPrinter': target,
        }),
      ).timeout(const Duration(seconds: 4));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<bool> reprintBill(String billId, {required String reason}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/bills/$billId/reprint'),
        headers: _headers,
        body: jsonEncode({
          'reason': reason,
        }),
      ).timeout(const Duration(seconds: 4));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }
}
