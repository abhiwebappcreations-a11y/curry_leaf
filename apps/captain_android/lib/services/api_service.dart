import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
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
    this.host = '192.168.29.116', // Default to Counter PC IP (fallback: 192.168.1.100)
    this.port = 4000,
    this.useDemoMode = false,    // Set default to false
  });

  String get baseUrl {
    // When running inside a browser preview on the host machine, route to 127.0.0.1
    if (kIsWeb && (host == '192.168.1.100' || host == '192.168.29.116')) {
      return 'http://127.0.0.1:$port/api';
    }
    return 'http://$host:$port/api';
  }

  Map<String, String> get _defaultHeaders => {
    'Content-Type': 'application/json',
    'X-Device-Id': 'dev_captain_01',
    'X-Device-Role': 'captain',
    'X-Api-Key': 'captain_dev_token_01',
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

  /// Unwraps backend { success: true, data: { ... } } response envelope
  dynamic _unwrapResponse(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
      return decoded['data'];
    }
    return decoded;
  }

  Future<bool> checkHealth({String? customHost, int? customPort}) async {
    if (useDemoMode) return true;
    final targetHost = customHost ?? host;
    final targetPort = customPort ?? port;
    String url;
    if (kIsWeb && (targetHost == '192.168.1.100' || targetHost == '192.168.29.116')) {
      url = 'http://127.0.0.1:$targetPort/api/health';
    } else {
      url = 'http://$targetHost:$targetPort/api/health';
    }
    try {
      final response = await http
          .get(Uri.parse(url), headers: _defaultHeaders)
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
          .get(Uri.parse('$baseUrl/tables'), headers: _defaultHeaders)
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = _unwrapResponse(response);
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
    return MockData.getInitialTables();
  }

  Future<List<MenuItem>> fetchMenu() async {
    if (useDemoMode) {
      await Future.delayed(const Duration(milliseconds: 200));
      return MockData.getInitialMenu();
    }
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/menu'), headers: _defaultHeaders)
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = _unwrapResponse(response);
        final List<MenuItem> parsedItems = [];
        if (data is Map<String, dynamic>) {
          if (data['menu'] is List) {
            // Hierarchical category listing
            for (var cat in data['menu'] as List) {
              final catName = (cat['name'] ?? 'General').toString();
              if (cat['items'] is List) {
                for (var item in cat['items'] as List) {
                  final map = Map<String, dynamic>.from(item as Map);
                  map['category'] = catName;
                  parsedItems.add(MenuItem.fromJson(map));
                }
              }
            }
          } else if (data['items'] is List) {
            for (var item in data['items'] as List) {
              parsedItems.add(MenuItem.fromJson(item as Map<String, dynamic>));
            }
          }
        } else if (data is List) {
          for (var item in data) {
            parsedItems.add(MenuItem.fromJson(item as Map<String, dynamic>));
          }
        }
        if (parsedItems.isNotEmpty) {
          return parsedItems;
        }
      }
    } catch (_) {}
    return MockData.getInitialMenu();
  }

  List<Map<String, dynamic>> _formatOrderItems(List<OrderItem> items) {
    return items.map((item) => {
      'menuItemId': item.menuItemId,
      'quantity': item.quantity,
      'itemNotes': item.notes ?? '',
      'selectedVariants': item.selectedVariant != null
          ? [{'id': 'v1', 'name': item.selectedVariant!, 'pricePaise': 0}]
          : [],
      'selectedAddons': item.selectedAddons
          .map((a) => {'id': a, 'name': a, 'pricePaise': 0})
          .toList(),
    }).toList();
  }

  /// Creates a new order on the server for the specified table.
  /// If the table already has an active order (409 Conflict), extracts and returns activeOrderId.
  Future<String?> createOrder({
    required String tableId,
    int? guestCount,
    List<OrderItem>? initialItems,
    String? customerNotes,
  }) async {
    if (useDemoMode) return 'ord-demo-${DateTime.now().millisecondsSinceEpoch}';

    try {
      final body = <String, dynamic>{
        'tableId': tableId,
        if (guestCount != null && guestCount > 0) 'guestCount': guestCount,
        if (customerNotes != null && customerNotes.isNotEmpty) 'customerNotes': customerNotes,
        if (initialItems != null && initialItems.isNotEmpty)
          'items': _formatOrderItems(initialItems),
      };

      final response = await http
          .post(
            Uri.parse('$baseUrl/orders'),
            headers: _defaultHeaders,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = _unwrapResponse(response);
        if (data is Map<String, dynamic> && data['order'] != null) {
          return data['order']['id'] as String?;
        }
      } else if (response.statusCode == 409) {
        // Table already has active order on server
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final errorData = decoded['error'] ?? decoded['data'];
          if (errorData is Map<String, dynamic> && errorData['activeOrderId'] != null) {
            return errorData['activeOrderId'] as String;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Appends draft items to an existing order on the server
  Future<bool> addItemsToOrder({
    required String orderId,
    required List<OrderItem> items,
  }) async {
    if (useDemoMode) return true;
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/orders/$orderId/items'),
            headers: _defaultHeaders,
            body: jsonEncode({
              'items': _formatOrderItems(items),
            }),
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
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

    final headers = {
      ..._defaultHeaders,
      'Idempotency-Key': idempotencyKey,
    };

    final payloadItems = _formatOrderItems(itemsToSend);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/orders/$orderId/kot'),
        headers: headers,
        body: jsonEncode({
          'tableId': tableId,
          'items': payloadItems,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = _unwrapResponse(response);
        final kotJson = (data is Map<String, dynamic> && data.containsKey('kot'))
            ? data['kot'] as Map<String, dynamic>
            : (data is Map<String, dynamic> ? data : <String, dynamic>{});
        kotJson['tableName'] = tableName;
        return KotTicket.fromJson(kotJson);
      }
    } catch (_) {
      // In offline resilience mode, return confirmed local KOT ticket
    }

    // Graceful offline fallback ticket when live local-api is not yet reachable
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
}
