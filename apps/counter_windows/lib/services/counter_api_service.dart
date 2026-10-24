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
  final String restaurantName;

  SystemHealthInfo({
    required this.isServerHealthy,
    required this.isDatabaseHealthy,
    required this.licenseStatus,
    required this.daysRemaining,
    this.restaurantName = 'Curry Leaf Fine Dine',
  });
}

class CounterApiService {
  String baseUrl;
  String host;
  int port;

  CounterApiService({
    this.host = '127.0.0.1',
    this.port = 4000,
    String? baseUrl,
  }) : baseUrl = baseUrl ?? 'http://127.0.0.1:4000/api';

  void updateHost(String newHost, [int newPort = 4000]) {
    host = newHost.trim();
    port = newPort;
    baseUrl = 'http://$host:$port/api';
  }

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
        final restData = data is Map ? data['restaurant'] as Map<String, dynamic>? : null;
        final restName = restData?['name']?.toString() ??
            (lic?['restaurantName']?.toString() ?? 'Hinopt POS');
        final licStatus = lic?['status']?.toString().toUpperCase() == 'ACTIVE'
            ? 'Active (Licensed to $restName)'
            : (lic?['status']?.toString() ?? 'Active');
        final days = lic?['daysRemaining'] as int? ?? 365;

        return SystemHealthInfo(
          isServerHealthy: isServer,
          isDatabaseHealthy: isDb,
          licenseStatus: licStatus,
          daysRemaining: days,
          restaurantName: restName,
        );
      }
    } catch (_) {}

    return SystemHealthInfo(
      isServerHealthy: false,
      isDatabaseHealthy: false,
      licenseStatus: 'Connecting to Local API (localhost:4000)...',
      daysRemaining: 365,
      restaurantName: 'Hinopt POS',
    );
  }

  /// Pings /api/health for a specific host and port to verify reachability
  Future<bool> checkHealthFor(String testHost, int testPort) async {
    try {
      final testUrl = 'http://${testHost.trim()}:$testPort/api/health';
      final response = await http
          .get(Uri.parse(testUrl), headers: headers)
          .timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
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
        return list.map((json) => RestaurantTable.fromJson(json as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return null;
  }

  Future<RestaurantTable?> createTable({
    required String tableNumber,
    String? displayName,
    required String section,
    required int capacity,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/tables'),
            headers: headers,
            body: jsonEncode({
              'tableNumber': tableNumber,
              'displayName': displayName ?? 'Table $tableNumber',
              'section': section,
              'capacity': capacity,
            }),
          )
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = unwrapResponse(response);
        final tableJson = (data is Map && data.containsKey('table')) ? data['table'] : data;
        return RestaurantTable.fromJson(tableJson as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  Future<bool> updateTable(
    String id, {
    String? tableNumber,
    String? displayName,
    String? section,
    int? capacity,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (tableNumber != null) body['tableNumber'] = tableNumber;
      if (displayName != null) body['displayName'] = displayName;
      if (section != null) body['section'] = section;
      if (capacity != null) body['capacity'] = capacity;

      final response = await http
          .put(
            Uri.parse('$baseUrl/tables/$id'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteTable(String id) async {
    try {
      final response = await http
          .delete(Uri.parse('$baseUrl/tables/$id'), headers: headers)
          .timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> getSystemPrinters() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/printers/system-devices'), headers: headers)
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = unwrapResponse(response);
        if (data is Map && data.containsKey('devices')) {
          final list = data['devices'] as List;
          return list.map((e) => e.toString()).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  Future<bool> cancelOrder(String orderId, String reason) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/orders/$orderId/cancel'),
            headers: headers,
            body: jsonEncode({'reason': reason}),
          )
          .timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> wipeAllData() async {
    try {
      final response = await http
          .delete(Uri.parse('$baseUrl/tables/all/wipe'), headers: headers)
          .timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> clearDemoTables() async {
    try {
      final response = await http
          .delete(Uri.parse('$baseUrl/tables/demo/clear'), headers: headers)
          .timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<RestaurantOrder>?> getActiveOrders({Map<String, String>? tableIdToName}) async {
    try {
      // 1. Fetch active, preparing, and ready orders from Local API
      http.Response response = await http
          .get(Uri.parse('$baseUrl/orders?status=active,preparing,ready'), headers: headers)
          .timeout(const Duration(seconds: 4));

      List<dynamic> list = [];

      if (response.statusCode == 200) {
        final data = unwrapResponse(response);
        if (data is Map<String, dynamic>) {
          list = (data['orders'] ?? []) as List<dynamic>;
        } else if (data is List) {
          list = data;
        }
      }

      // 2. Fallback: If comma-separated filter returned empty, fetch all and filter locally
      if (list.isEmpty) {
        try {
          final allResponse = await http
              .get(Uri.parse('$baseUrl/orders'), headers: headers)
              .timeout(const Duration(seconds: 4));
          if (allResponse.statusCode == 200) {
            final allData = unwrapResponse(allResponse);
            final rawList = (allData is Map<String, dynamic> ? allData['orders'] : allData) as List<dynamic>? ?? [];
            list = rawList.where((o) {
              if (o is! Map) return false;
              final st = (o['status'] ?? '').toString().toLowerCase();
              return st == 'active' || st == 'preparing' || st == 'ready' || st == 'draft';
            }).toList();
          }
        } catch (_) {}
      }

      // 3. Map orders and populate table names
      final orders = list.map((json) {
        final map = Map<String, dynamic>.from(json as Map);
        final tableId = (map['tableId'] ?? '').toString();

        final currentName = (map['tableName'] ?? '').toString().trim();
        if (currentName.isEmpty || currentName.toLowerCase() == tableId.toLowerCase()) {
          if (tableIdToName != null && tableIdToName.containsKey(tableId)) {
            map['tableName'] = tableIdToName[tableId];
          } else if (tableId.isNotEmpty) {
            if (tableId.startsWith('tab_t')) {
              map['tableName'] = 'Table ${tableId.substring(5)}';
            } else if (tableId.startsWith('tbl_')) {
              map['tableName'] = 'Table ${tableId.substring(4)}';
            } else {
              map['tableName'] = tableId.toUpperCase();
            }
          } else {
            map['tableName'] = 'Table';
          }
        }

        return RestaurantOrder.fromJson(map);
      }).toList();

      return orders;
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
        return items;
      }
    } catch (_) {}
    return null;
  }

  Future<MenuItem?> createMenuItem({
    required String name,
    required String category,
    required int pricePaise,
    required bool isVeg,
    String? description,
    String? imageUrl,
  }) async {
    try {
      final payload = <String, dynamic>{
        'name': name,
        'categoryId': category,
        'pricePaise': pricePaise,
        'isVeg': isVeg,
        'description': description ?? '',
      };
      if (imageUrl != null && imageUrl.isNotEmpty) {
        payload['imageUrl'] = imageUrl;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/menu/items'),
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = unwrapResponse(response);
        final itemJson = (data is Map<String, dynamic> && data['item'] != null)
            ? data['item'] as Map<String, dynamic>
            : data as Map<String, dynamic>;
        return MenuItem.fromJson(itemJson);
      }
    } catch (_) {}
    return null;
  }

  Future<bool> toggleMenuItemAvailability(String id, bool isAvailable) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/menu/items/$id/availability'),
        headers: headers,
        body: jsonEncode({
          'isAvailable': isAvailable,
        }),
      ).timeout(const Duration(seconds: 4));

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateMenuItemPrice(String id, int newPricePaise) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/menu/items/$id/price'),
        headers: headers,
        body: jsonEncode({
          'pricePaise': newPricePaise,
        }),
      ).timeout(const Duration(seconds: 4));

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteMenuItem(String id) async {
    try {
      final response = await http
          .delete(Uri.parse('$baseUrl/menu/items/$id'), headers: headers)
          .timeout(const Duration(seconds: 4));
      return response.statusCode == 200 || response.statusCode == 404;
    } catch (_) {
      return false;
    }
  }

  Future<bool> wipeAllMenuItems() async {
    try {
      final response = await http
          .delete(Uri.parse('$baseUrl/menu/items/all/wipe'), headers: headers)
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> seedDemoMenu() async {
    try {
      final response = await http
          .post(Uri.parse('$baseUrl/menu/demo/seed'), headers: headers)
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<RestaurantBill?> generateBill(String orderId, {int discountPaise = 0}) async {
    final idempotencyKey = generateUuidV4();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/billing/orders/$orderId/bill'),
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

  Future<bool> updatePrinterConfig(String printerId, {required String target, String paperWidth = '80mm'}) async {
    final roleId = (printerId.contains('kot') || printerId.contains('kitchen'))
        ? 'kitchen_kot'
        : 'counter_bill';
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/printers/$roleId'),
        headers: headers,
        body: jsonEncode({
          'target': target,
          'paperWidth': paperWidth,
        }),
      ).timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> exportBackup() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/backup/export'),
        headers: headers,
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          return body['data'] as Map<String, dynamic>?;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> restoreBackup(Map<String, dynamic> backupData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/backup/restore'),
        headers: headers,
        body: jsonEncode({'backupData': backupData}),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          return body['data'] as Map<String, dynamic>?;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> listBackupSnapshots() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/backup/snapshots'),
        headers: headers,
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] is List) {
          return (body['data'] as List).cast<Map<String, dynamic>>();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<bool> restoreSnapshot(String fileName) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/backup/restore-snapshot'),
        headers: headers,
        body: jsonEncode({'fileName': fileName}),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['success'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> syncCloudBackup() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/backup/cloud-sync'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          return body['data'] as Map<String, dynamic>?;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> restoreCloudBackup() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/backup/cloud-restore'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          return body['data'] as Map<String, dynamic>?;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCloudBackupStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/backup/cloud-status'),
        headers: headers,
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          return body['data'] as Map<String, dynamic>?;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> checkLicenseHeartbeat() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/license/heartbeat'),
        headers: headers,
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          return body['data'] as Map<String, dynamic>?;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

/// Backward compatibility alias
typedef ApiClient = CounterApiService;
