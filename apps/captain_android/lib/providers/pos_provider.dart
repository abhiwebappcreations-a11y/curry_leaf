import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/table_model.dart';
import '../models/menu_item_model.dart';
import '../models/order_model.dart';
import '../models/kot_model.dart';
import '../services/api_service.dart';
import '../services/mock_data.dart';
import '../services/discovery_service.dart';

class PosProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<RestaurantTable> _tables = [];
  List<MenuItem> _menuItems = [];
  final Map<String, RestaurantOrder> _ordersByTableId = {};
  final List<KotTicket> _kotHistory = [];

  String _selectedSection = 'All';
  String _selectedCategory = 'All';
  String _searchQuery = '';

  RestaurantTable? _currentTable;
  RestaurantOrder? _currentOrder;

  bool _isLoading = false;
  bool _isSubmittingKot = false;
  String? _lastError;
  bool _isConnected = true;
  Timer? _autoPollTimer;
  Timer? _pairingPollTimer;

  bool _isPairingApproved = false;
  bool _isPairingPending = false;
  String? _pairingMessage;
  String _deviceId = 'dev_captain_01';
  String _deviceName = 'Captain Phone';

  PosProvider() {
    init();
  }

  // Getters
  List<RestaurantTable> get tables => _tables;
  List<MenuItem> get menuItems => _menuItems;
  String get selectedSection => _selectedSection;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  RestaurantTable? get currentTable => _currentTable;
  RestaurantOrder? get currentOrder => _currentOrder;
  bool get isLoading => _isLoading;
  bool get isSubmittingKot => _isSubmittingKot;
  String? get lastError => _lastError;
  bool get isConnected => _isConnected;
  bool get isPairingApproved => _isPairingApproved;
  bool get isPairingPending => _isPairingPending;
  String? get pairingMessage => _pairingMessage;
  String get deviceName => _deviceName;
  String get deviceId => _deviceId;
  List<KotTicket> get kotHistory => _kotHistory;
  ApiService get apiService => _apiService;

  List<String> get availableSections {
    final sections = {'All'};
    for (var t in _tables) {
      sections.add(t.section);
    }
    return sections.toList();
  }

  List<String> get availableCategories {
    final categories = {'All'};
    for (var m in _menuItems) {
      categories.add(m.category);
    }
    return categories.toList();
  }

  List<RestaurantTable> get filteredTables {
    if (_selectedSection == 'All') return _tables;
    return _tables.where((t) => t.section == _selectedSection).toList();
  }

  List<MenuItem> get filteredMenu {
    return _menuItems.where((item) {
      final matchesCategory =
          _selectedCategory == 'All' || item.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.category.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  int get occupiedTableCount =>
      _tables.where((t) => t.status == TableStatus.occupied).length;

  int get availableTableCount =>
      _tables.where((t) => t.status == TableStatus.available).length;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedHost = prefs.getString('counter_pc_host');
      final savedPort = prefs.getInt('counter_pc_port');
      final savedDemo = prefs.getBool('counter_demo_mode');
      final savedDeviceId = prefs.getString('captain_device_id');
      final savedDeviceName = prefs.getString('captain_device_name');
      final savedApiKey = prefs.getString('captain_api_key');

      if (savedDeviceId != null && savedDeviceId.isNotEmpty) {
        _deviceId = savedDeviceId;
      } else {
        _deviceId = 'cap_${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
        await prefs.setString('captain_device_id', _deviceId);
      }

      if (savedDeviceName != null && savedDeviceName.isNotEmpty) {
        _deviceName = savedDeviceName;
      }
      if (savedApiKey != null && savedApiKey.isNotEmpty) {
        _apiService.apiKey = savedApiKey;
      }

      if (savedHost != null && savedHost.trim().isNotEmpty) {
        _apiService.host = savedHost.trim();
      }
      if (savedPort != null && savedPort > 0) {
        _apiService.port = savedPort;
      }
      if (savedDemo != null) {
        _apiService.useDemoMode = savedDemo;
      }

      _apiService.deviceId = _deviceId;

      // 1. If not demo mode, attempt Zero-Config Wi-Fi Auto-Discovery
      if (!_apiService.useDemoMode) {
        final discovered = await CounterDiscoveryService.discoverCounterPos();
        if (discovered != null && discovered['host'] != null) {
          _apiService.host = discovered['host'].toString();
          if (discovered['port'] != null) {
            _apiService.port = int.tryParse(discovered['port'].toString()) ?? 4000;
          }
        }

        // 2. Pair / Permission Handshake with Counter POS
        final pairRes = await _apiService.requestPairing(
          deviceId: _deviceId,
          deviceName: _deviceName,
        );

        if (pairRes != null) {
          final status = pairRes['status']?.toString();
          if (status == 'approved') {
            _isPairingApproved = true;
            _isPairingPending = false;
            if (pairRes['apiKey'] != null) {
              await prefs.setString('captain_api_key', pairRes['apiKey'].toString());
            }
          } else {
            // Pending Counter Manager Approval
            _isPairingApproved = false;
            _isPairingPending = true;
            _pairingMessage = pairRes['message']?.toString() ??
                'New device detected. Please tap "Approve" on Counter POS screen.';
            _startPairingPolling();
          }
        } else {
          // If pair request fails (offline or demo), allow graceful local use
          _isPairingApproved = true;
        }
      } else {
        _isPairingApproved = true;
      }
    } catch (_) {
      _isPairingApproved = true;
    }

    _tables = await _apiService.fetchTables();
    _menuItems = await _apiService.fetchMenu();
    if (_apiService.useDemoMode) {
      _ordersByTableId.addAll(MockData.getSeedOrders());
    } else {
      final liveOrders = await _apiService.fetchActiveOrders();
      for (var o in liveOrders) {
        _ordersByTableId[o.tableId] = o;
      }
    }

    _isLoading = false;
    notifyListeners();
    startAutoPolling();
  }

  void _startPairingPolling() {
    _pairingPollTimer?.cancel();
    _pairingPollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final res = await _apiService.checkPairStatus(_deviceId);
      if (res != null && res['status'] == 'approved') {
        _pairingPollTimer?.cancel();
        _pairingPollTimer = null;
        _isPairingApproved = true;
        _isPairingPending = false;

        if (res['apiKey'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('captain_api_key', res['apiKey'].toString());
        }

        await pollLatestState();
        notifyListeners();
      }
    });
  }

  void startAutoPolling() {
    _autoPollTimer?.cancel();
    _autoPollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_isLoading && !_isSubmittingKot) {
        pollLatestState();
      }
    });
  }

  void stopAutoPolling() {
    _autoPollTimer?.cancel();
    _autoPollTimer = null;
  }

  /// Periodic background sync: listens to Counter POS changes
  /// (stock toggles, price updates, table occupancy/settlement, menu wipe)
  Future<void> pollLatestState() async {
    try {
      final healthy = await _apiService.checkHealth();
      _isConnected = healthy;
      if (healthy && !_apiService.useDemoMode) {
        final liveTables = await _apiService.fetchTables();
        _tables = liveTables;

        final liveOrders = await _apiService.fetchActiveOrders();
        final serverTableIds = <String>{};
        for (var o in liveOrders) {
          serverTableIds.add(o.tableId);
          _ordersByTableId[o.tableId] = o;
        }

        // Clean up settled tables that no longer have server orders
        _ordersByTableId.removeWhere((tblId, ord) =>
            !serverTableIds.contains(tblId) && ord.draftItems.isEmpty);

        if (_currentTable != null) {
          final updatedTable = _tables.where((t) => t.id == _currentTable!.id).firstOrNull;
          if (updatedTable != null) {
            _currentTable = updatedTable;
            if (updatedTable.status == TableStatus.available &&
                _currentOrder != null &&
                _currentOrder!.draftItems.isEmpty) {
              _ordersByTableId.remove(_currentTable!.id);
              _currentOrder = null;
            }
          }

          // Keep current active order synchronized with real server item IDs
          if (_currentOrder != null && _ordersByTableId.containsKey(_currentTable!.id)) {
            final serverOrder = _ordersByTableId[_currentTable!.id]!;
            final localDrafts = _currentOrder!.draftItems;
            if (localDrafts.isNotEmpty) {
              _currentOrder = serverOrder.copyWith(
                items: [...serverOrder.items, ...localDrafts],
              );
            } else {
              _currentOrder = serverOrder;
            }
          }
        }

        notifyListeners();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pairingPollTimer?.cancel();
    stopAutoPolling();
    super.dispose();
  }

  void setSection(String section) {
    _selectedSection = section;
    notifyListeners();
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void selectTable(RestaurantTable table) {
    _currentTable = table;
    if (_ordersByTableId.containsKey(table.id)) {
      _currentOrder = _ordersByTableId[table.id];
    } else {
      // Start a fresh draft order for this table
      _currentOrder = RestaurantOrder(
        id: table.activeOrderId ?? 'ord-${DateTime.now().millisecondsSinceEpoch}',
        tableId: table.id,
        tableName: table.name,
        items: [],
        createdAt: DateTime.now(),
        guestCount: table.capacity,
      );
      _ordersByTableId[table.id] = _currentOrder!;
    }
    notifyListeners();
  }

  void clearSelectedTable() {
    _currentTable = null;
    _currentOrder = null;
    _searchQuery = '';
    notifyListeners();
  }

  void addItemToDraft(
    MenuItem item, {
    int quantity = 1,
    String? notes,
    String? variant,
    List<String> addons = const [],
  }) {
    if (_currentOrder == null) return;

    final existingIndex = _currentOrder!.items.indexWhere(
      (i) =>
          i.isDraft &&
          i.menuItemId == item.id &&
          i.selectedVariant == variant &&
          i.notes == notes,
    );

    List<OrderItem> updatedItems = List.from(_currentOrder!.items);

    if (existingIndex >= 0) {
      final existing = updatedItems[existingIndex];
      updatedItems[existingIndex] = existing.copyWith(
        quantity: existing.quantity + quantity,
      );
    } else {
      updatedItems.add(
        OrderItem(
          id: 'item-${DateTime.now().millisecondsSinceEpoch}',
          menuItemId: item.id,
          name: item.name,
          quantity: quantity,
          pricePaise: item.pricePaise,
          isVeg: item.isVeg,
          notes: notes,
          selectedVariant: variant,
          selectedAddons: addons,
          isDraft: true,
          status: OrderItemStatus.draft,
        ),
      );
    }

    _currentOrder = _currentOrder!.copyWith(items: updatedItems);
    _ordersByTableId[_currentTable!.id] = _currentOrder!;
    notifyListeners();
  }

  void updateDraftQuantity(String itemId, int delta) {
    if (_currentOrder == null) return;

    final index = _currentOrder!.items.indexWhere((i) => i.id == itemId);
    if (index < 0) return;

    final item = _currentOrder!.items[index];
    if (!item.isDraft) return; // Cannot directly mutate submitted items

    List<OrderItem> updated = List.from(_currentOrder!.items);
    final newQty = item.quantity + delta;

    if (newQty <= 0) {
      updated.removeAt(index);
    } else {
      updated[index] = item.copyWith(quantity: newQty);
    }

    _currentOrder = _currentOrder!.copyWith(items: updated);
    _ordersByTableId[_currentTable!.id] = _currentOrder!;
    notifyListeners();
  }

  void removeDraftItem(String itemId) {
    if (_currentOrder == null) return;
    List<OrderItem> updated = List.from(_currentOrder!.items);
    updated.removeWhere((i) => i.id == itemId && i.isDraft);

    _currentOrder = _currentOrder!.copyWith(items: updated);
    _ordersByTableId[_currentTable!.id] = _currentOrder!;
    notifyListeners();
  }

  Future<KotTicket?> sendDraftToKitchen() async {
    if (_currentOrder == null || _currentOrder!.draftItems.isEmpty) return null;

    _isSubmittingKot = true;
    _lastError = null;
    notifyListeners();

    try {
      final itemsToSend = _currentOrder!.draftItems;
      final idempotencyKey = ApiService.generateUuidV4();

      String activeOrderId = _currentOrder!.id;
      final serverTableOrderId = _currentTable?.activeOrderId;
      if (serverTableOrderId != null && serverTableOrderId.isNotEmpty) {
        activeOrderId = serverTableOrderId;
      }

      // Fast atomic KOT submission (dispatches order items & prints KOT in a single network round-trip)
      final result = await _apiService.submitKot(
        orderId: activeOrderId,
        tableId: _currentTable!.id,
        tableName: _currentTable!.name,
        itemsToSend: itemsToSend,
        idempotencyKey: idempotencyKey,
      );

      final ticket = result.ticket;
      final serverOrder = result.order;

      if (serverOrder != null) {
        _currentOrder = serverOrder;
        _ordersByTableId[_currentTable!.id] = serverOrder;
        activeOrderId = serverOrder.id;
      } else {
        // Fallback local update
        final now = DateTime.now();
        final updatedItems = _currentOrder!.items.map((item) {
          if (item.isDraft) {
            return item.copyWith(
              isDraft: false,
              sentAt: now,
              status: OrderItemStatus.sentToKitchen,
            );
          }
          return item;
        }).toList();

        _currentOrder = _currentOrder!.copyWith(
          id: activeOrderId,
          items: updatedItems,
          status: 'ACTIVE',
        );
        _ordersByTableId[_currentTable!.id] = _currentOrder!;
      }

      // Update table status
      final tableIndex = _tables.indexWhere((t) => t.id == _currentTable!.id);
      if (tableIndex >= 0) {
        _tables[tableIndex] = _tables[tableIndex].copyWith(
          status: TableStatus.occupied,
          activeOrderId: activeOrderId,
          activeOrderTotalPaise: _currentOrder!.totalPaise,
          occupiedSince: _tables[tableIndex].occupiedSince ?? DateTime.now(),
        );
        _currentTable = _tables[tableIndex];
      }

      _kotHistory.insert(0, ticket);
      _isSubmittingKot = false;
      notifyListeners();

      // Refresh table floor state
      pollLatestState();

      return ticket;
    } catch (e) {
      _lastError = e.toString();
      _isSubmittingKot = false;
      notifyListeners();
      return null;
    }
  }

  void requestItemCancellation(OrderItem item, String reason) {
    if (_currentOrder == null) return;
    final orderId = _currentOrder!.id;
    final index = _currentOrder!.items.indexWhere((i) => i.id == item.id);
    if (index >= 0) {
      List<OrderItem> updated = List.from(_currentOrder!.items);
      updated[index] = item.copyWith(
        status: OrderItemStatus.cancelRequested,
        notes: '${item.notes ?? ""} [Cancel Req: $reason]'.trim(),
      );
      _currentOrder = _currentOrder!.copyWith(items: updated);
      _ordersByTableId[_currentTable!.id] = _currentOrder!;
      notifyListeners();

      // Dispatch request to Counter POS backend for manager approval & kitchen ticket
      _apiService.requestCancellation(
        orderId: orderId,
        itemId: item.id,
        reason: reason,
      );
    }
  }

  Future<void> updateServerConfig(String host, int port, bool demoMode) async {
    _apiService.host = host;
    _apiService.port = port;
    _apiService.useDemoMode = demoMode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('counter_pc_host', host);
      await prefs.setInt('counter_pc_port', port);
      await prefs.setBool('counter_demo_mode', demoMode);
    } catch (_) {}
    init();
  }
}
