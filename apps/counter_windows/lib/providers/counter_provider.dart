import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/table_model.dart';
import '../models/order_model.dart';
import '../models/bill_model.dart';
import '../models/printer_model.dart';
import '../models/menu_model.dart';
import '../services/mock_counter_data.dart';
import '../services/counter_api_service.dart';

enum CounterTab {
  orders,
  tables,
  billing,
  menu,
  printers,
  reports,
}

class CounterProvider extends ChangeNotifier {
  final CounterApiService _counterApiService = CounterApiService();
  CounterApiService get apiService => _counterApiService;
  CounterApiService get _apiClient => _counterApiService;

  CounterTab _activeTab = CounterTab.orders;

  List<RestaurantTable> _tables = [];
  List<RestaurantOrder> _activeOrders = [];
  List<RestaurantBill> _settledBills = [];
  List<ThermalPrinterConfig> _printers = [];
  List<MenuItem> _menuItems = [];

  RestaurantOrder? _selectedOrder;
  RestaurantBill? _currentDraftBill;

  bool _isSettlingPayment = false;
  String? _lastSettlementError;
  RestaurantBill? _lastSettledBill;

  String _searchQuery = '';
  String _selectedSection = 'All';

  // System Health
  bool _localServerHealthy = false;
  bool _databaseHealthy = false;
  String _licenseStatus = 'Checking...';
  int _licenseDaysRemaining = 365;
  String _restaurantName = 'Curry Leaf';

  String get restaurantName => _restaurantName;

  // Background Auto-Polling & Pull-to-Refresh
  Timer? _autoPollTimer;
  bool _isRefreshing = false;

  CounterProvider() {
    _initData();
    _startAutoPolling();
  }

  // Getters
  ApiClient get apiClient => _apiClient;
  CounterTab get activeTab => _activeTab;
  List<RestaurantTable> get tables => _tables;
  List<RestaurantOrder> get activeOrders => _activeOrders;
  List<RestaurantBill> get settledBills => _settledBills;
  List<ThermalPrinterConfig> get printers => _printers;
  List<MenuItem> get menuItems => _menuItems;
  RestaurantOrder? get selectedOrder => _selectedOrder;
  RestaurantBill? get currentDraftBill => _currentDraftBill;
  bool get isSettlingPayment => _isSettlingPayment;
  String? get lastSettlementError => _lastSettlementError;
  RestaurantBill? get lastSettledBill => _lastSettledBill;
  String get searchQuery => _searchQuery;
  String get selectedSection => _selectedSection;

  List<String> get availableSections {
    final sections = {'All'};
    for (var t in _tables) {
      if (t.section.trim().isNotEmpty) {
        sections.add(t.section.trim());
      }
    }
    return sections.toList();
  }

  bool get localServerHealthy => _localServerHealthy;
  bool get databaseHealthy => _databaseHealthy;
  String get licenseStatus => _licenseStatus;
  int get licenseDaysRemaining => _licenseDaysRemaining;
  bool get isLicenseLocked =>
      _licenseStatus.toLowerCase() == 'expired' ||
      _licenseStatus.toLowerCase() == 'suspended' ||
      (_licenseStatus.toLowerCase() != 'active' && _licenseDaysRemaining <= 0);
  String get serverHost => _counterApiService.host;
  int get serverPort => _counterApiService.port;
  bool get isRefreshing => _isRefreshing;

  Future<void> setServerHost(String host, [int port = 4000]) async {
    _counterApiService.updateHost(host, port);
    notifyListeners();
    await refreshFromLiveApi(isManual: true);
  }

  Future<bool> createTable({
    required String tableNumber,
    String? displayName,
    required String section,
    required int capacity,
  }) async {
    final created = await _counterApiService.createTable(
      tableNumber: tableNumber,
      displayName: displayName,
      section: section,
      capacity: capacity,
    );
    if (created != null) {
      _tables.add(created);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> updateTable(
    String id, {
    String? tableNumber,
    String? displayName,
    String? section,
    int? capacity,
  }) async {
    final ok = await _counterApiService.updateTable(
      id,
      tableNumber: tableNumber,
      displayName: displayName,
      section: section,
      capacity: capacity,
    );
    if (ok) {
      await refreshFromLiveApi(isManual: true);
      return true;
    }
    return false;
  }

  Future<bool> deleteTable(String id) async {
    final ok = await _counterApiService.deleteTable(id);
    if (ok) {
      _tables.removeWhere((t) => t.id == id);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<List<String>> fetchSystemPrinters() => _counterApiService.getSystemPrinters();

  Future<bool> cancelOrder(String orderId, String reason) async {
    final ok = await _counterApiService.cancelOrder(orderId, reason);
    if (ok) {
      _selectedOrder = null;
      _currentDraftBill = null;
      await refreshFromLiveApi(isManual: true);
      return true;
    }
    return false;
  }

  Future<bool> wipeAllDemoData({bool includeMenu = true}) async {
    final ok = await _counterApiService.wipeAllData();
    if (ok) {
      _selectedOrder = null;
      _currentDraftBill = null;
      _tables.clear();
      _activeOrders.clear();
      _settledBills.clear();
      if (includeMenu) {
        await _counterApiService.wipeAllMenuItems();
        _menuItems.clear();
      }
      await refreshFromLiveApi(isManual: true);
      return true;
    }
    return false;
  }

  Future<bool> clearDemoTables() async {
    final ok = await _counterApiService.clearDemoTables();
    if (ok) {
      await refreshFromLiveApi(isManual: true);
      return true;
    }
    return false;
  }

  Future<Map<String, dynamic>?> exportBackup() async {
    return await _counterApiService.exportBackup();
  }

  Future<bool> restoreBackup(Map<String, dynamic> backupData) async {
    final result = await _counterApiService.restoreBackup(backupData);
    if (result != null) {
      await refreshFromLiveApi(isManual: true);
      return true;
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> listBackupSnapshots() async {
    return await _counterApiService.listBackupSnapshots();
  }

  Future<bool> restoreSnapshot(String fileName) async {
    final ok = await _counterApiService.restoreSnapshot(fileName);
    if (ok) {
      await refreshFromLiveApi(isManual: true);
      return true;
    }
    return false;
  }

  Future<Map<String, dynamic>?> syncCloudBackup() async {
    return await _counterApiService.syncCloudBackup();
  }

  Future<bool> restoreCloudBackup() async {
    final result = await _counterApiService.restoreCloudBackup();
    if (result != null) {
      await refreshFromLiveApi(isManual: true);
      return true;
    }
    return false;
  }

  Future<Map<String, dynamic>?> getCloudBackupStatus() async {
    return await _counterApiService.getCloudBackupStatus();
  }

  Future<Map<String, dynamic>?> checkLicenseHeartbeat() async {
    final result = await _counterApiService.checkLicenseHeartbeat();
    if (result != null && result['status'] == 'revoked') {
      _licenseStatus = 'suspended';
      notifyListeners();
    }
    return result;
  }

  Future<bool> testServerConnection(String host, int port) async {
    return _counterApiService.checkHealthFor(host, port);
  }

  ThermalPrinterConfig? get billPrinter =>
      _printers.where((p) => p.role == PrinterRole.counterBill).firstOrNull;

  ThermalPrinterConfig? get kotPrinter =>
      _printers.where((p) => p.role == PrinterRole.kitchenKot).firstOrNull;

  Future<void> _initData() async {
    // 1. Initial baseline to ensure seamless startup without layout flash
    _tables = MockCounterData.getTables();
    _activeOrders = MockCounterData.getActiveOrders();
    _settledBills = MockCounterData.getSettledBills();
    _printers = MockCounterData.getPrinters();
    _menuItems = MockCounterData.getMenuItems();

    // 2. Fetch live data from Local API (http://127.0.0.1:4000/api)
    await refreshFromLiveApi(isManual: false);
  }

  void _startAutoPolling() {
    _autoPollTimer?.cancel();
    // Auto-poll every 4 seconds to detect live captain orders & table status updates
    _autoPollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_isRefreshing && !_isSettlingPayment) {
        _pollActiveState();
      }
    });
  }

  void _stopAutoPolling() {
    _autoPollTimer?.cancel();
    _autoPollTimer = null;
  }

  /// Periodic background lightweight poll for orders, tables, and server health
  Future<void> _pollActiveState() async {
    try {
      final health = await _apiClient.getHealth();
      _localServerHealthy = health.isServerHealthy;
      _databaseHealthy = health.isDatabaseHealthy;
      _licenseStatus = health.licenseStatus;
      _licenseDaysRemaining = health.daysRemaining;
      _restaurantName = health.restaurantName;

      if (_localServerHealthy) {
        final liveTables = await _apiClient.getTables();
        if (liveTables != null) {
          _tables = liveTables;
        }

        final tableMap = {for (var t in _tables) t.id: t.name};
        final liveOrders = await _apiClient.getActiveOrders(tableIdToName: tableMap);
        if (liveOrders != null) {
          _activeOrders = liveOrders;
        }

        // Auto-sync open bill with latest order changes
        if (_currentDraftBill != null && !_isSettlingPayment) {
          final activeOrder = _activeOrders.where((o) => o.id == _currentDraftBill!.orderId).firstOrNull;
          if (activeOrder != null &&
              (activeOrder.activeItems.length != _currentDraftBill!.items.length ||
               activeOrder.subtotalPaise != _currentDraftBill!.subtotalPaise)) {
            _syncDraftBillFromOrder(activeOrder);
          }
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Full refresh (invoked manually by button, pull-to-refresh, or host reconfiguration)
  Future<void> refreshFromLiveApi({bool isManual = false}) async {
    if (isManual) {
      _isRefreshing = true;
      notifyListeners();
    }

    try {
      final health = await _apiClient.getHealth();
      _localServerHealthy = health.isServerHealthy;
      _databaseHealthy = health.isDatabaseHealthy;
      _licenseStatus = health.licenseStatus;
      _licenseDaysRemaining = health.daysRemaining;
      _restaurantName = health.restaurantName;

      final liveTables = await _apiClient.getTables();
      if (liveTables != null) {
        _tables = liveTables;
      }

      final tableMap = {for (var t in _tables) t.id: t.name};
      final liveOrders = await _apiClient.getActiveOrders(tableIdToName: tableMap);
      if (liveOrders != null) {
        _activeOrders = liveOrders;
      }

      // Sync open bill if any
      if (_currentDraftBill != null && !_isSettlingPayment) {
        final activeOrder = _activeOrders.where((o) => o.id == _currentDraftBill!.orderId).firstOrNull;
        if (activeOrder != null) {
          _syncDraftBillFromOrder(activeOrder);
        }
      }

      final livePrinters = await _apiClient.getPrinters();
      if (livePrinters != null && livePrinters.isNotEmpty) {
        _printers = livePrinters;
      }

      final liveMenu = await _apiClient.getMenu();
      if (liveMenu != null) {
        _menuItems = liveMenu;
      }
    } catch (_) {} finally {
      if (isManual) {
        _isRefreshing = false;
      }
      notifyListeners();
    }
  }

  void setActiveTab(CounterTab tab) {
    _activeTab = tab;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSection(String section) {
    _selectedSection = section;
    notifyListeners();
  }

  Future<void> selectOrder(RestaurantOrder order) async {
    _selectedOrder = order;

    // Pure on-screen draft bill preview - NEVER fires the physical printer when viewing!
    final billSuffix = order.id.length > 6 ? order.id.substring(order.id.length - 6).toUpperCase() : order.id.toUpperCase();
    _currentDraftBill = RestaurantBill.fromOrder(
      order: order,
      billNumber: 'INV-$billSuffix',
      cashierName: 'Cashier',
    );

    _activeTab = CounterTab.billing;
    notifyListeners();
  }

  void selectOrderByTableId(String tableId) {
    final order = _activeOrders.where((o) => o.tableId == tableId).firstOrNull;
    if (order != null) {
      selectOrder(order);
    }
  }

  void _syncDraftBillFromOrder(RestaurantOrder activeOrder) {
    if (_currentDraftBill == null) return;
    final discount = _currentDraftBill!.discountPaise;
    final reason = _currentDraftBill!.discountReason;
    final updated = RestaurantBill.fromOrder(
      order: activeOrder,
      billNumber: _currentDraftBill!.billNumber,
      cashierName: _currentDraftBill!.cashierName,
    );
    final taxable = (updated.subtotalPaise - discount).clamp(0, double.infinity).toInt();
    final cgst = (taxable * 0.025).round();
    final sgst = (taxable * 0.025).round();
    _currentDraftBill = updated.copyWith(
      id: _currentDraftBill!.id,
      discountPaise: discount,
      discountReason: reason,
      cgstPaise: cgst,
      sgstPaise: sgst,
      totalPaise: taxable + cgst + sgst,
    );
  }

  /// Cashier adds an extra item directly to the active bill from Counter
  void addItemToCurrentBill(MenuItem menuItem, int quantity) {
    if (_currentDraftBill == null) return;
    final itemTotal = menuItem.pricePaise * quantity;
    final newItem = BillItemSnapshot(
      name: menuItem.name,
      quantity: quantity,
      unitPricePaise: menuItem.pricePaise,
      totalPaise: itemTotal,
    );

    final updatedItems = List<BillItemSnapshot>.from(_currentDraftBill!.items);
    final existingIndex = updatedItems.indexWhere((i) => i.name.toLowerCase() == menuItem.name.toLowerCase());
    if (existingIndex >= 0) {
      final existing = updatedItems[existingIndex];
      final newQty = existing.quantity + quantity;
      updatedItems[existingIndex] = BillItemSnapshot(
        name: existing.name,
        quantity: newQty,
        unitPricePaise: existing.unitPricePaise,
        totalPaise: existing.unitPricePaise * newQty,
      );
    } else {
      updatedItems.add(newItem);
    }

    final newSubtotal = updatedItems.fold<int>(0, (sum, i) => sum + i.totalPaise);
    final taxable = (newSubtotal - _currentDraftBill!.discountPaise).clamp(0, double.infinity).toInt();
    final cgst = (taxable * 0.025).round();
    final sgst = (taxable * 0.025).round();

    _currentDraftBill = _currentDraftBill!.copyWith(
      items: updatedItems,
      subtotalPaise: newSubtotal,
      cgstPaise: cgst,
      sgstPaise: sgst,
      totalPaise: taxable + cgst + sgst,
    );
    notifyListeners();
  }

  /// Manually syncs or re-fetches the current draft bill with latest order items & prices
  Future<void> refreshCurrentBill() async {
    if (_currentDraftBill == null) return;
    final orderId = _currentDraftBill!.orderId;

    if (_localServerHealthy) {
      final liveBill = await _apiClient.generateBill(
        orderId,
        discountPaise: _currentDraftBill!.discountPaise,
      );
      if (liveBill != null) {
        _currentDraftBill = liveBill.copyWith(
          discountReason: _currentDraftBill!.discountReason,
          cashierName: _currentDraftBill!.cashierName,
          tableName: _currentDraftBill!.tableName,
        );
        notifyListeners();
        return;
      }
    }

    final activeOrder = _activeOrders.where((o) => o.id == orderId).firstOrNull;
    if (activeOrder != null) {
      _syncDraftBillFromOrder(activeOrder);
      notifyListeners();
    }
  }

  Future<void> applyDiscount(int discountPaise, String reason) async {
    if (_currentDraftBill == null) return;

    final subtotal = _currentDraftBill!.subtotalPaise;
    final taxable = (subtotal - discountPaise).clamp(0, double.infinity).toInt();
    final cgst = (taxable * 0.025).round();
    final sgst = (taxable * 0.025).round();
    final total = taxable + cgst + sgst;

    _currentDraftBill = _currentDraftBill!.copyWith(
      discountPaise: discountPaise,
      discountReason: reason,
      cgstPaise: cgst,
      sgstPaise: sgst,
      totalPaise: total,
    );
    notifyListeners();

    // Persist discount update to backend if online
    if (_localServerHealthy) {
      try {
        final liveBill = await _apiClient.generateBill(
          _currentDraftBill!.orderId,
          discountPaise: discountPaise,
        );
        if (liveBill != null) {
          _currentDraftBill = liveBill.copyWith(
            discountReason: reason,
            cashierName: _currentDraftBill!.cashierName,
            tableName: _currentDraftBill!.tableName,
          );
          notifyListeners();
        }
      } catch (_) {}
    }
  }

  Future<bool> settlePayment({
    required PaymentMethod method,
    String? reference,
  }) async {
    // Duplicate click protection: blocks clicks if already in progress or bill is null
    if (_currentDraftBill == null || _isSettlingPayment) return false;

    _isSettlingPayment = true;
    _lastSettlementError = null;
    notifyListeners();

    try {
      final billToSettle = _currentDraftBill!;

      // Connect to Live API: POST /api/bills/:id/payments
      await _apiClient.settlePayment(
        billId: billToSettle.id,
        method: method.name.toUpperCase(),
        amountPaise: billToSettle.totalPaise,
        reference: reference,
      );

      final settledBill = billToSettle.copyWith(
        cashierName: 'Deepa',
        paymentMethod: method,
        paymentStatus: PaymentStatus.settled,
        paymentReference: reference,
        settledAt: DateTime.now(),
      );

      _settledBills.insert(0, settledBill);
      _lastSettledBill = settledBill;

      // Update table state to available
      final tableIndex = _tables.indexWhere((t) => t.id == settledBill.tableId);
      if (tableIndex >= 0) {
        _tables[tableIndex] = _tables[tableIndex].copyWith(
          status: TableStatus.available,
          clearActiveOrder: true,
          activeOrderTotalPaise: 0,
          clearOccupiedSince: true,
        );
      }

      // Remove from active orders
      _activeOrders.removeWhere((o) => o.id == settledBill.orderId);
      _selectedOrder = null;
      _currentDraftBill = null;

      _isSettlingPayment = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSettlingPayment = false;
      _lastSettlementError = e.toString();
      notifyListeners();
      return false;
    }
  }

  void reprintBill(RestaurantBill bill, String reason) {
    final index = _settledBills.indexWhere((b) => b.id == bill.id);
    if (index >= 0) {
      _settledBills[index] = _settledBills[index].copyWith(
        isReprint: true,
        reprintCount: _settledBills[index].reprintCount + 1,
      );
      notifyListeners();
    }
    _apiClient.reprintBill(bill.id, reason: reason);
  }

  void toggleMenuItemAvailability(String id) {
    final index = _menuItems.indexWhere((m) => m.id == id);
    if (index >= 0) {
      final current = _menuItems[index];
      final newStatus = !current.isAvailable;
      _menuItems[index] = current.copyWith(isAvailable: newStatus);
      notifyListeners();
      _apiClient.toggleMenuItemAvailability(id, newStatus);
    }
  }

  Future<bool> addNewMenuItem({
    required String name,
    required String category,
    required int pricePaise,
    required bool isVeg,
    String? description,
    String? imageUrl,
  }) async {
    final created = await _apiClient.createMenuItem(
      name: name,
      category: category,
      pricePaise: pricePaise,
      isVeg: isVeg,
      description: description,
      imageUrl: imageUrl,
    );

    if (created != null) {
      _menuItems.insert(0, created);
      notifyListeners();
      return true;
    }

    // Local fallback if offline
    final localItem = MenuItem(
      id: 'm-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      category: category,
      pricePaise: pricePaise,
      isVeg: isVeg,
      description: description ?? '',
      imageUrl: imageUrl,
      isAvailable: true,
    );
    _menuItems.insert(0, localItem);
    notifyListeners();
    return true;
  }

  Future<void> updateMenuItemPrice(String id, int newPricePaise) async {
    final index = _menuItems.indexWhere((m) => m.id == id);
    if (index >= 0) {
      _menuItems[index] = _menuItems[index].copyWith(pricePaise: newPricePaise);
      notifyListeners();
      await _counterApiService.updateMenuItemPrice(id, newPricePaise);
    }
  }

  Future<bool> deleteMenuItem(String id) async {
    final ok = await _counterApiService.deleteMenuItem(id);
    _menuItems.removeWhere((item) => item.id == id);
    notifyListeners();
    return ok;
  }

  Future<bool> wipeAllMenuItems() async {
    final ok = await _counterApiService.wipeAllMenuItems();
    _menuItems.clear();
    notifyListeners();
    return ok;
  }

  Future<bool> seedDemoMenu() async {
    final ok = await _counterApiService.seedDemoMenu();
    if (ok) {
      await refreshFromLiveApi(isManual: true);
    }
    return ok;
  }

  Future<void> testPrint(PrinterRole role) async {
    final printer = _printers.where((p) => p.role == role).firstOrNull;
    if (printer != null) {
      final success = await _apiClient.testPrint(printer.id);
      final index = _printers.indexOf(printer);
      _printers[index] = printer.copyWith(
        lastTestPrintAt: DateTime.now(),
        isConnected: success,
      );
      notifyListeners();
    }
  }

  Future<bool> updatePrinterAddress(PrinterRole role, String newTarget, [int paperWidthMm = 80]) async {
    final printer = _printers.where((p) => p.role == role).firstOrNull;
    if (printer == null) return false;

    final success = await _apiClient.updatePrinterConfig(
      printer.id,
      target: newTarget.trim(),
      paperWidth: '${paperWidthMm}mm',
    );

    final index = _printers.indexOf(printer);
    _printers[index] = printer.copyWith(
      address: newTarget.trim(),
      paperWidthMm: paperWidthMm,
      isConnected: true,
    );
    notifyListeners();
    return success;
  }

  @override
  void dispose() {
    _stopAutoPolling();
    super.dispose();
  }

  // Financial Metrics
  double get totalSalesRupees {
    return _settledBills.fold(0.0, (sum, bill) => sum + bill.totalRupees);
  }

  double get totalGstRupees {
    return _settledBills.fold(0.0, (sum, bill) => sum + bill.totalGstRupees);
  }

  double get totalDiscountsRupees {
    return _settledBills.fold(0.0, (sum, bill) => sum + bill.discountRupees);
  }

  Map<PaymentMethod, double> get salesByMethod {
    final map = {
      PaymentMethod.cash: 0.0,
      PaymentMethod.upi: 0.0,
      PaymentMethod.card: 0.0,
      PaymentMethod.split: 0.0,
    };
    for (final bill in _settledBills) {
      map[bill.paymentMethod] = (map[bill.paymentMethod] ?? 0.0) + bill.totalRupees;
    }
    return map;
  }
}
