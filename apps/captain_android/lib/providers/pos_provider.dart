import 'package:flutter/foundation.dart';
import '../models/table_model.dart';
import '../models/menu_item_model.dart';
import '../models/order_model.dart';
import '../models/kot_model.dart';
import '../services/api_service.dart';
import '../services/mock_data.dart';

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

    _tables = await _apiService.fetchTables();
    _menuItems = await _apiService.fetchMenu();
    _ordersByTableId.addAll(MockData.getSeedOrders());

    _isLoading = false;
    notifyListeners();
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
        id: 'ord-${DateTime.now().millisecondsSinceEpoch}',
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

      final ticket = await _apiService.submitKot(
        orderId: _currentOrder!.id,
        tableId: _currentTable!.id,
        tableName: _currentTable!.name,
        itemsToSend: itemsToSend,
        idempotencyKey: idempotencyKey,
      );

      // Transition draft items to submitted items
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
        items: updatedItems,
        status: 'IN_KITCHEN',
      );
      _ordersByTableId[_currentTable!.id] = _currentOrder!;

      // Update table status
      final tableIndex = _tables.indexWhere((t) => t.id == _currentTable!.id);
      if (tableIndex >= 0) {
        _tables[tableIndex] = _tables[tableIndex].copyWith(
          status: TableStatus.occupied,
          activeOrderId: _currentOrder!.id,
          activeOrderTotalPaise: _currentOrder!.totalPaise,
          occupiedSince: _tables[tableIndex].occupiedSince ?? now,
        );
        _currentTable = _tables[tableIndex];
      }

      _kotHistory.insert(0, ticket);
      _isSubmittingKot = false;
      notifyListeners();
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
    }
  }

  void updateServerConfig(String host, int port, bool demoMode) {
    _apiService.host = host;
    _apiService.port = port;
    _apiService.useDemoMode = demoMode;
    init();
  }
}
