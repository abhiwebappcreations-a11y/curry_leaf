import 'dart:async';
import 'dart:convert';
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
  // Device-local draft storage: maps tableId -> unsent OrderItem list
  final Map<String, List<OrderItem>> _localDraftsByTableId = {};
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
  bool _isLimitExceeded = false;
  bool _isNameConfigured = false;
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
  bool get isLimitExceeded => _isLimitExceeded;
  bool get isNameConfigured => _isNameConfigured;
  String? get pairingMessage => _pairingMessage;
  String get deviceName => _deviceName;
  String get deviceId => _deviceId;
  List<KotTicket> get kotHistory => _kotHistory;
  ApiService get apiService => _apiService;

  bool hasDraft(String tableId) =>
      (_localDraftsByTableId[tableId]?.isNotEmpty ?? false) ||
      (_ordersByTableId[tableId]?.draftItems.isNotEmpty ?? false);

  int getDraftCount(String tableId) {
    final drafts = _localDraftsByTableId[tableId];
    if (drafts != null && drafts.isNotEmpty) {
      return drafts.fold(0, (sum, i) => sum + i.quantity);
    }
    return _ordersByTableId[tableId]?.draftItems.fold(0, (sum, i) => sum + i.quantity) ?? 0;
  }

  static int naturalTableCompare(RestaurantTable a, RestaurantTable b) {
    final regex = RegExp(r'(\d+|\D+)');
    final aMatches = regex.allMatches(a.name).map((m) => m.group(0)!).toList();
    final bMatches = regex.allMatches(b.name).map((m) => m.group(0)!).toList();

    for (int i = 0; i < aMatches.length && i < bMatches.length; i++) {
      final aPart = aMatches[i];
      final bPart = bMatches[i];
      final aNum = int.tryParse(aPart);
      final bNum = int.tryParse(bPart);

      if (aNum != null && bNum != null) {
        final comp = aNum.compareTo(bNum);
        if (comp != 0) return comp;
      } else {
        final comp = aPart.toLowerCase().compareTo(bPart.toLowerCase());
        if (comp != 0) return comp;
      }
    }
    return aMatches.length.compareTo(bMatches.length);
  }

  Future<void> _saveLocalDraftsToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> data = {};
      _localDraftsByTableId.forEach((tblId, items) {
        if (items.isNotEmpty) {
          data[tblId] = items.map((i) => i.toJson()).toList();
        }
      });
      await prefs.setString('local_captain_drafts_v1', jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _loadLocalDraftsFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('local_captain_drafts_v1');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(jsonStr);
        _localDraftsByTableId.clear();
        decoded.forEach((tblId, itemsList) {
          if (itemsList is List) {
            _localDraftsByTableId[tblId] = itemsList
                .map((itemMap) => OrderItem.fromJson(itemMap as Map<String, dynamic>))
                .toList();
          }
        });
      }
    } catch (_) {}
  }

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

      if (savedDeviceName != null && savedDeviceName.trim().isNotEmpty) {
        _deviceName = savedDeviceName.trim();
        _isNameConfigured = true;
      } else {
        _isNameConfigured = false;
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

        // 2. Handshake only if waiter name has been given
        if (_isNameConfigured) {
          await sendPairingRequest();
        }
      } else {
        _isPairingApproved = true;
      }
    } catch (_) {
      _isPairingApproved = _apiService.useDemoMode;
      _isPairingPending = false;
      _pairingMessage = 'Network error connecting to Counter POS (${_apiService.host}:${_apiService.port}).';
    }

    await _loadLocalDraftsFromPrefs();

    _tables = (await _apiService.fetchTables())..sort(naturalTableCompare);
    _menuItems = await _apiService.fetchMenu();
    if (_apiService.useDemoMode) {
      _ordersByTableId.addAll(MockData.getSeedOrders());
    } else {
      final liveOrders = await _apiService.fetchActiveOrders();
      for (var o in liveOrders) {
        final localDrafts = _localDraftsByTableId[o.tableId] ?? [];
        if (localDrafts.isNotEmpty) {
          final serverSubmitted = o.items.where((i) => !i.isDraft).toList();
          _ordersByTableId[o.tableId] = o.copyWith(
            items: [...serverSubmitted, ...localDrafts],
          );
        } else {
          _ordersByTableId[o.tableId] = o;
        }
      }
      // Ensure tables with local drafts that have no server order are also represented in _ordersByTableId
      for (var entry in _localDraftsByTableId.entries) {
        if (entry.value.isNotEmpty && !_ordersByTableId.containsKey(entry.key)) {
          final tbl = _tables.where((t) => t.id == entry.key).firstOrNull;
          _ordersByTableId[entry.key] = RestaurantOrder(
            id: tbl?.activeOrderId ?? 'ord-${DateTime.now().millisecondsSinceEpoch}',
            tableId: entry.key,
            tableName: tbl?.name ?? 'Table',
            items: List.from(entry.value),
            createdAt: DateTime.now(),
            guestCount: tbl?.capacity ?? 4,
          );
        }
      }
    }

    _isLoading = false;
    notifyListeners();
    startAutoPolling();
  }

  Future<void> sendPairingRequest([String? customName]) async {
    final prefs = await SharedPreferences.getInstance();
    if (customName != null && customName.trim().isNotEmpty) {
      _deviceName = customName.trim();
      await prefs.setString('captain_device_name', _deviceName);
    }
    _isNameConfigured = true;
    notifyListeners();

    try {
      final pairRes = await _apiService.requestPairing(
        deviceId: _deviceId,
        deviceName: _deviceName,
      );

      if (pairRes != null) {
        final status = pairRes['status']?.toString();
        if (status == 'approved') {
          _isPairingApproved = true;
          _isPairingPending = false;
          _isLimitExceeded = false;
          if (pairRes['apiKey'] != null) {
            await prefs.setString('captain_api_key', pairRes['apiKey'].toString());
          }
        } else if (status == 'limit_exceeded') {
          _isPairingApproved = false;
          _isPairingPending = false;
          _isLimitExceeded = true;
          _pairingMessage = pairRes['message']?.toString() ??
              'Captain device limit reached. Please upgrade your Hinopt license.';
          _startPairingPolling();
        } else {
          // Pending Counter Manager Approval
          _isPairingApproved = false;
          _isPairingPending = true;
          _isLimitExceeded = false;
          _pairingMessage = pairRes['message']?.toString() ??
              'New device detected. Please tap "Approve" on Counter POS screen.';
          _startPairingPolling();
        }
      } else {
        _isPairingApproved = false;
        _isPairingPending = false;
        _isLimitExceeded = false;
        _pairingMessage = 'Cannot connect to Counter POS at ${_apiService.host}:${_apiService.port}. Please verify Wi-Fi connection.';
      }
    } catch (_) {
      _isPairingApproved = _apiService.useDemoMode;
      _isPairingPending = false;
      _pairingMessage = 'Network error connecting to Counter POS (${_apiService.host}:${_apiService.port}).';
    }

    notifyListeners();
  }

  void promptRename() {
    _isNameConfigured = false;
    notifyListeners();
  }

  Future<void> updateDeviceName(String name) async {
    await sendPairingRequest(name);
  }

  void _startPairingPolling() {
    _pairingPollTimer?.cancel();
    _pairingPollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final res = await _apiService.checkPairStatus(_deviceId);
      if (res != null) {
        final status = res['status']?.toString();
        if (status == 'approved') {
          _pairingPollTimer?.cancel();
          _pairingPollTimer = null;
          _isPairingApproved = true;
          _isPairingPending = false;
          _isLimitExceeded = false;

          if (res['apiKey'] != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('captain_api_key', res['apiKey'].toString());
          }

          _tables = await _apiService.fetchTables();
          _menuItems = await _apiService.fetchMenu();
          final liveOrders = await _apiService.fetchActiveOrders();
          _ordersByTableId.clear();
          for (var o in liveOrders) {
            _ordersByTableId[o.tableId] = o;
          }

          await pollLatestState();
          notifyListeners();
        } else if (status == 'declined' || status == 'rejected') {
          _pairingPollTimer?.cancel();
          _pairingPollTimer = null;
          _isPairingApproved = false;
          _isPairingPending = false;
          _pairingMessage = 'Connection request was declined by Counter Cashier.';
          notifyListeners();
        } else if (status == 'limit_exceeded') {
          _isPairingApproved = false;
          _isPairingPending = false;
          _isLimitExceeded = true;
          _pairingMessage = res['message']?.toString() ??
              'Captain device limit reached. Please upgrade your Hinopt license.';
          notifyListeners();
        }
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
          // Preserve local unsent draft items if captain has drafts on this table
          final existing = _ordersByTableId[o.tableId];
          final existingDrafts = existing?.draftItems ?? [];
          if (existingDrafts.isNotEmpty) {
            final serverSubmitted = o.items.where((i) => !i.isDraft).toList();
            _ordersByTableId[o.tableId] = o.copyWith(
              items: [...serverSubmitted, ...existingDrafts],
            );
          } else {
            _ordersByTableId[o.tableId] = o;
          }
        }

        // Clean up settled tables that no longer have server orders AND have no local drafts
        // Never purge the table the captain is currently viewing
        _ordersByTableId.removeWhere((tblId, ord) =>
            tblId != _currentTable?.id &&
            !serverTableIds.contains(tblId) &&
            ord.draftItems.isEmpty);

        if (_currentTable != null) {
          final updatedTable = _tables.where((t) => t.id == _currentTable!.id).firstOrNull;
          if (updatedTable != null) {
            _currentTable = updatedTable;
          }

          // Ensure active order object exists for the table being edited
          _ensureActiveOrder();

          // Keep current active order synchronized without duplicating drafts
          if (_currentOrder != null) {
            final serverOrder = liveOrders.where((o) => o.tableId == _currentTable!.id).firstOrNull;
            final localDrafts = _currentOrder!.draftItems;

            if (serverOrder != null) {
              // Server has an active order for this table: keep server's submitted items and local unsent drafts
              final serverSubmitted = serverOrder.items.where((i) => !i.isDraft).toList();
              if (localDrafts.isNotEmpty) {
                _currentOrder = serverOrder.copyWith(
                  items: [...serverSubmitted, ...localDrafts],
                );
              } else {
                _currentOrder = serverOrder;
              }
              _ordersByTableId[_currentTable!.id] = _currentOrder!;
            } else {
              // No server order for this table yet (e.g. fresh table with unsent drafts).
              // Keep _currentOrder intact: NEVER duplicate local drafts!
              _ordersByTableId[_currentTable!.id] = _currentOrder!;
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

  void _ensureActiveOrder() {
    if (_currentTable == null) return;
    if (_currentOrder == null) {
      if (_ordersByTableId.containsKey(_currentTable!.id)) {
        _currentOrder = _ordersByTableId[_currentTable!.id];
      } else {
        _currentOrder = RestaurantOrder(
          id: _currentTable!.activeOrderId ?? 'ord-${DateTime.now().millisecondsSinceEpoch}',
          tableId: _currentTable!.id,
          tableName: _currentTable!.name,
          items: [],
          createdAt: DateTime.now(),
          guestCount: _currentTable!.capacity,
        );
        _ordersByTableId[_currentTable!.id] = _currentOrder!;
      }
    }
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
    _ensureActiveOrder();
    if (_currentOrder == null || _currentTable == null) return;

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
    _ensureActiveOrder();
    if (_currentOrder == null || _currentTable == null) return;

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
    _ensureActiveOrder();
    if (_currentOrder == null || _currentTable == null) return;
    List<OrderItem> updated = List.from(_currentOrder!.items);
    updated.removeWhere((i) => i.id == itemId && i.isDraft);

    _currentOrder = _currentOrder!.copyWith(items: updated);
    _ordersByTableId[_currentTable!.id] = _currentOrder!;
    notifyListeners();
  }

  Future<KotTicket?> sendDraftToKitchen() async {
    _ensureActiveOrder();
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
