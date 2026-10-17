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

class CounterApiService {
  final String baseUrl;

  CounterApiService({this.baseUrl = 'http://localhost:4000/api'});

  Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'X-Device-Id': 'dev_counter_01',
    'X-Device-Role': 'counter',
    'X-Api-Key': 'counter_dev_token',
  };

  /// Unwraps standard backend { success: true, data: { ... } } envelope
  dynamic unwrapResponse(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
      return decoded['data'];
    }
    return decoded;
  }

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
          .get(Uri.parse('$baseUrl/health'), headers: headers)
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = unwrapResponse(response);
        final components = data is Map<String, dynamic>
            ? data['components'] as Map<String, dynamic>?
            : null;

        final isServer = (data is Map && data['status'] == 'healthy') ||
            components?['apiServer']?['status'] == 'online';
        final isDb = components?['database']?['status'] == 'connected' ||
            (data is Map && data['database'] == 'connected');

        final lic = components?['license'] as Map<String, dynamic>? ??
            (data is Map ? data['license'] as Map<String, dynamic>? : null);
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
      licenseStatus: 'Connecting to Local API (localhost:4000)...',
      daysRemaining: 365,
    );
  }

  Future<List<RestaurantTable>?> getTables() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/tables'), headers: headers)
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = unwrapResponse(response);
        List<dynamic> list;
        if (data is Map<String, dynamic>) {
          list = (data['tables'] ?? []) as List<dynamic>;
        } else if (data is List) {
          list = data;
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
          .get(Uri.parse('$baseUrl/orders?status=active'), headers: headers)
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = unwrapResponse(response);
        List<dynamic> list;
        if (data is Map<String, dynamic>) {
          list = (data['orders'] ?? []) as List<dynamic>;
        } else if (data is List) {
          list = data;
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
          .get(Uri.parse('$baseUrl/printers'), headers: headers)
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = unwrapResponse(response);
        List<dynamic> list;
        if (data is Map<String, dynamic>) {
          list = (data['printers'] ?? []) as List<dynamic>;
        } else if (data is List) {
          list = data;
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
          .get(Uri.parse('$baseUrl/menu'), headers: headers)
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = unwrapResponse(response);
        final List<MenuItem> items = [];
        if (data is Map<String, dynamic>) {
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
          } else if (data['items'] is List) {
            for (var item in data['items'] as List) {
              items.add(MenuItem.fromJson(item as Map<String, dynamic>));
            }
          }
        } else if (data is List) {
          for (var item in data) {
            items.add(MenuItem.fromJson(item as Map<String, dynamic>));
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
          ...headers,
          'Idempotency-Key': idempotencyKey,
        },
        body: jsonEncode({
          'discountPaise': discountPaise,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = unwrapResponse(response);
        final billJson = (data is Map<String, dynamic> && data['bill'] != null)
            ? data['bill'] as Map<String, dynamic>
            : data as Map<String, dynamic>;
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
          ...headers,
          'Idempotency-Key': idempotencyKey,
        },
        body: jsonEncode({
          'method': method.toUpperCase(),
          'paymentMethod': method.toLowerCase(),
          'amountPaise': amountPaise,
          'idempotencyKey': idempotencyKey,
          'referenceNumber': reference ?? '',
          'notes': 'Settled by Counter Cashier',
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
        headers: headers,
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
        headers: headers,
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

/// Backward compatibility alias
typedef ApiClient = CounterApiService;
