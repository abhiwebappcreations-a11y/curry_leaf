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
  List<Map<String, dynamic>> _discoveredPrinters = [];
  List<Map<String, dynamic>> get discoveredPrinters => _discoveredPrinters;
  bool _isDiscoveringPrinters = false;
  bool get isDiscoveringPrinters => _isDiscoveringPrinters;

  Future<void> autoDiscoverPrinters() async {
    _isDiscoveringPrinters = true;
    notifyListeners();
    try {
      final found = await _counterApiService.discoverAllPrinters();
      if (found.isNotEmpty) {
        _discoveredPrinters = found;
      }
    } catch (_) {}
    _isDiscoveringPrinters = false;
    notifyListeners();
  }

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
  String _ownerName = '';
  String _phone = '';
  String _city = '';
  String _hardwareId = '';
  String _printerMode = 'single';
  bool _isGstEnabled = false;
  double _gstRatePercent = 5.0;
  double _cgstRatePercent = 2.5;
  double _sgstRatePercent = 2.5;
  String _gstin = '';
  String _activeOrderFilter = 'all'; // 'all', 'dine_in', 'takeaway'
  int _takeawayCounter = 101;

  // License Limits & Usage
  int _menuItemsLimit = 100;
  int _captainDevicesLimit = 5;
  int _counterPcsLimit = 1;
  int _menuItemsUsage = 0;
  int _captainDevicesUsage = 0;
  int _counterPcsUsage = 0;

  // Online Ordering & Own Delivery Add-On Module
  bool _isOnlineOrderingEnabled = false;
  String _onlineStoreUrl = '';
  String _customDomain = '';

  bool get isOnlineOrderingEnabled => _isOnlineOrderingEnabled;
  String get onlineStoreUrl => _onlineStoreUrl;
  String get customDomain => _customDomain;

  String get restaurantName => _restaurantName;
  String get ownerName => _ownerName;
  String get phone => _phone;
  String get city => _city;
  String get hardwareId => _hardwareId;
  String get printerMode => _printerMode;
  bool get isSinglePrinterMode => _printerMode == 'single';
  bool get isGstEnabled => _isGstEnabled;
  double get gstRatePercent => _gstRatePercent;
  double get cgstRatePercent => _cgstRatePercent;
  double get sgstRatePercent => _sgstRatePercent;
  String get gstin => _gstin;
  String get activeOrderFilter => _activeOrderFilter;

  void setActiveOrderFilter(String filter) {
    _activeOrderFilter = filter;
    notifyListeners();
  }

  int get menuItemsLimit => _menuItemsLimit;
  int get captainDevicesLimit => _captainDevicesLimit;
  int get counterPcsLimit => _counterPcsLimit;
  int get menuItemsUsage => _menuItemsUsage;
  int get captainDevicesUsage => _captainDevicesUsage;
  int get counterPcsUsage => _counterPcsUsage;

  bool get isMenuItemLimitReached => _menuItems.length >= _menuItemsLimit;
  bool get isCaptainDeviceLimitReached => _captainDevicesUsage >= _captainDevicesLimit;

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
  List<ThermalPrinterConfig> get printers => _printers.isNotEmpty ? _printers : MockCounterData.getPrinters();
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

  // Wi-Fi Auto-Discovery & Captain Pairing
  List<Map<String, dynamic>> _pendingDevices = [];
  List<Map<String, dynamic>> _pendingCancelRequests = [];
  Map<String, dynamic>? _lanInfo;

  List<Map<String, dynamic>> get pendingDevices => _pendingDevices;
  List<Map<String, dynamic>> get pendingCancelRequests => _pendingCancelRequests;
  bool get hasPendingCancelRequests => _pendingCancelRequests.isNotEmpty;
  bool get hasPendingDevices => _pendingDevices.isNotEmpty;
  Map<String, dynamic>? get lanInfo => _lanInfo;
  String get lanHost => _lanInfo?['host']?.toString() ?? '127.0.0.1';
  bool get isLicenseLocked =>
      _licenseStatus.toLowerCase() == 'expired' ||
      _licenseStatus.toLowerCase() == 'suspended' ||
      (_licenseStatus.toLowerCase() == 'unlicensed' && _licenseDaysRemaining <= 0);
  String get serverHost => _counterApiService.host;
  int get serverPort => _counterApiService.port;
  bool get isRefreshing => _isRefreshing;

  Future<void> setServerHost(String host, [int port = 4000]) async {
    _counterApiService.updateHost(host, port);
    notifyListeners();
    await refreshFromLiveApi(isManual: true);
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
      _tables.sort(naturalTableCompare);
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

  Future<bool> activateLicense(String licenseKey) async {
    final result = await _counterApiService.activateLicenseKey(licenseKey);
    if (result != null && result['license'] != null) {
      final lic = result['license'] as Map<String, dynamic>;
      _licenseStatus = lic['status']?.toString() ?? 'active';
      _licenseDaysRemaining = (lic['daysRemaining'] as int?) ?? 365;
      if (lic['restaurantName'] != null) {
        _restaurantName = lic['restaurantName'].toString();
      }
      if (lic['ownerName'] != null) {
        _ownerName = lic['ownerName'].toString();
      }
      if (lic['phone'] != null) {
        _phone = lic['phone'].toString();
      }
      if (lic['city'] != null) {
        _city = lic['city'].toString();
      }
      if (lic['hardwareId'] != null) {
        _hardwareId = lic['hardwareId'].toString();
      } else if (lic['hwid'] != null) {
        _hardwareId = lic['hwid'].toString();
      }
      if (lic['limits'] != null && lic['limits'] is Map) {
        final lim = lic['limits'] as Map<String, dynamic>;
        if (lim['menuItems'] is num) _menuItemsLimit = (lim['menuItems'] as num).toInt();
        if (lim['captainDevices'] is num) _captainDevicesLimit = (lim['captainDevices'] as num).toInt();
        if (lim['counterPcs'] is num) _counterPcsLimit = (lim['counterPcs'] as num).toInt();
      }
      notifyListeners();
      await refreshFromLiveApi(isManual: true);
      return true;
    }
    return false;
  }

  Future<bool> testServerConnection(String host, int port) async {
    return _counterApiService.checkHealthFor(host, port);
  }

  Future<bool> approveCancelRequest(String requestId) async {
    final ok = await _counterApiService.approveCancelRequest(requestId);
    if (ok) {
      _pendingCancelRequests.removeWhere((r) => r['id'] == requestId);
      notifyListeners();
      await refreshFromLiveApi(isManual: true);
    }
    return ok;
  }

  Future<bool> rejectCancelRequest(String requestId) async {
    final ok = await _counterApiService.rejectCancelRequest(requestId);
    if (ok) {
      _pendingCancelRequests.removeWhere((r) => r['id'] == requestId);
      notifyListeners();
    }
    return ok;
  }

  Future<bool> printCustomerBill(String id) async {
    return await _counterApiService.printCustomerBill(id);
  }

  Future<bool> setPrinterMode(String mode) async {
    _printerMode = mode;
    notifyListeners();
    final ok = await _counterApiService.setPrinterMode(mode);
    await refreshFromLiveApi(isManual: true);
    return ok;
  }

  Future<bool> fireKotForTable({
    required String tableId,
    required List<Map<String, dynamic>> items,
    String? customerNotes,
  }) async {
    final ok = await _counterApiService.fireKotForTable(
      tableId: tableId,
      items: items,
      customerNotes: customerNotes,
    );
    if (ok) {
      await refreshFromLiveApi(isManual: true);
    }
    return ok;
  }

  ThermalPrinterConfig? get billPrinter =>
      printers.where((p) => p.role == PrinterRole.counterBill).firstOrNull;

  ThermalPrinterConfig? get kotPrinter =>
      printers.where((p) => p.role == PrinterRole.kitchenKot).firstOrNull;

  Future<void> _initData() async {
    // 1. Initially initialize empty to avoid flash of demo/stale data
    _tables = [];
    _activeOrders = [];
    _settledBills = [];
    _printers = [];
    _menuItems = [];

    // 2. Fetch live data from Local API (http://127.0.0.1:4000/api)
    await refreshFromLiveApi(isManual: false);

    // 3. Fallback to sample floor tables only if completely offline/uninitialized
    if (_tables.isEmpty && !_localServerHealthy) {
      _tables = MockCounterData.getTables();
      _menuItems = MockCounterData.getMenuItems();
      _printers = MockCounterData.getPrinters();
    }
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
      _ownerName = health.ownerName;
      _phone = health.phone;
      _city = health.city;
      if (health.hardwareId.isNotEmpty) {
        _hardwareId = health.hardwareId;
      }
      _menuItemsLimit = health.menuItemsLimit;
      _captainDevicesLimit = health.captainDevicesLimit;
      _counterPcsLimit = health.counterPcsLimit;
      _menuItemsUsage = health.menuItemsUsage;
      _captainDevicesUsage = health.captainDevicesUsage;
      _counterPcsUsage = health.counterPcsUsage;
      _isGstEnabled = health.isGstEnabled;
      _gstRatePercent = health.gstRatePercent;
      _cgstRatePercent = health.cgstRatePercent;
      _sgstRatePercent = health.sgstRatePercent;
      _gstin = health.gstin;
      _isOnlineOrderingEnabled = health.isOnlineOrderingEnabled;
      _onlineStoreUrl = health.onlineStoreUrl;
      _customDomain = health.customDomain;
      _isOnlineOrderingEnabled = health.isOnlineOrderingEnabled;
      _onlineStoreUrl = health.onlineStoreUrl;
      _customDomain = health.customDomain;

      if (_localServerHealthy) {
        final liveTables = await _apiClient.getTables();
        if (liveTables != null) {
          _tables = (liveTables..sort(naturalTableCompare));
        }

        final tableMap = {for (var t in _tables) t.id: t.name};
        final liveOrders = await _apiClient.getActiveOrders(tableIdToName: tableMap);
        if (liveOrders != null) {
          _activeOrders = liveOrders;
        }

        final liveBills = await _apiClient.getBills();
        _settledBills = liveBills;

        // Auto-sync open bill with latest order changes
        if (_currentDraftBill != null && !_isSettlingPayment) {
          final activeOrder = _activeOrders.where((o) => o.id == _currentDraftBill!.orderId).firstOrNull;
          if (activeOrder != null &&
              (activeOrder.activeItems.length != _currentDraftBill!.items.length ||
               activeOrder.subtotalPaise != _currentDraftBill!.subtotalPaise)) {
            _syncDraftBillFromOrder(activeOrder);
          }
        }
        // Check for pending Captain devices on LAN
        final pending = await _apiClient.getPendingDevices();
        _pendingDevices = pending;

        // Check for pending cancellation requests from Captains
        final cancelReqs = await _counterApiService.getPendingCancelRequests();
        _pendingCancelRequests = cancelReqs;

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
      _ownerName = health.ownerName;
      _phone = health.phone;
      _city = health.city;
      if (health.hardwareId.isNotEmpty) {
        _hardwareId = health.hardwareId;
      } else if (_hardwareId.isEmpty) {
        final hw = await _counterApiService.getHardwareId();
        if (hw != null && hw.isNotEmpty) _hardwareId = hw;
      }
      _menuItemsLimit = health.menuItemsLimit;
      _captainDevicesLimit = health.captainDevicesLimit;
      _counterPcsLimit = health.counterPcsLimit;
      _menuItemsUsage = health.menuItemsUsage;
      _captainDevicesUsage = health.captainDevicesUsage;
      _counterPcsUsage = health.counterPcsUsage;
      _isGstEnabled = health.isGstEnabled;
      _gstRatePercent = health.gstRatePercent;
      _cgstRatePercent = health.cgstRatePercent;
      _sgstRatePercent = health.sgstRatePercent;
      _gstin = health.gstin;
      _isOnlineOrderingEnabled = health.isOnlineOrderingEnabled;
      _onlineStoreUrl = health.onlineStoreUrl;
      _customDomain = health.customDomain;

      _lanInfo = await _apiClient.getLanInfo();
      _pendingDevices = await _apiClient.getPendingDevices();

      final liveTables = await _apiClient.getTables();
      if (liveTables != null) {
        _tables = (liveTables..sort(naturalTableCompare));
      }

      final tableMap = {for (var t in _tables) t.id: t.name};
      final liveOrders = await _apiClient.getActiveOrders(tableIdToName: tableMap);
      if (liveOrders != null) {
        _activeOrders = liveOrders;
      }

      final liveBills = await _apiClient.getBills();
      _settledBills = liveBills;

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
      } else if (_printers.isEmpty) {
        _printers = MockCounterData.getPrinters();
      }
      _printerMode = await _apiClient.getPrinterMode();

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
      cashierName: _ownerName.isNotEmpty ? _ownerName : 'Cashier',
      isGstEnabled: _isGstEnabled,
      gstRatePercent: _gstRatePercent,
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
      isGstEnabled: _isGstEnabled,
      gstRatePercent: _gstRatePercent,
    );
    final taxable = (updated.subtotalPaise - discount).clamp(0, double.infinity).toInt();
    final halfRate = (_gstRatePercent / 200.0);
    final cgst = _isGstEnabled ? (taxable * halfRate).round() : 0;
    final sgst = _isGstEnabled ? (taxable * halfRate).round() : 0;
    _currentDraftBill = updated.copyWith(
      id: _currentDraftBill!.id,
      discountPaise: discount,
      discountReason: reason,
      isGstEnabled: _isGstEnabled,
      gstRatePercent: _gstRatePercent,
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
    final halfRate = (_gstRatePercent / 200.0);
    final cgst = _isGstEnabled ? (taxable * halfRate).round() : 0;
    final sgst = _isGstEnabled ? (taxable * halfRate).round() : 0;

    _currentDraftBill = _currentDraftBill!.copyWith(
      items: updatedItems,
      subtotalPaise: newSubtotal,
      isGstEnabled: _isGstEnabled,
      gstRatePercent: _gstRatePercent,
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


  Future<void> updateGstConfig({
    required bool enabled,
    required double cgstRate,
    required double sgstRate,
    String gstin = '',
  }) async {
    _isGstEnabled = enabled;
    _cgstRatePercent = cgstRate;
    _sgstRatePercent = sgstRate;
    _gstRatePercent = cgstRate + sgstRate;
    _gstin = gstin;

    if (_currentDraftBill != null) {
      final taxable = (_currentDraftBill!.subtotalPaise - _currentDraftBill!.discountPaise).clamp(0, double.infinity).toInt();
      final cgstPaise = _isGstEnabled ? (taxable * (_cgstRatePercent / 100.0)).round() : 0;
      final sgstPaise = _isGstEnabled ? (taxable * (_sgstRatePercent / 100.0)).round() : 0;
      _currentDraftBill = _currentDraftBill!.copyWith(
        isGstEnabled: _isGstEnabled,
        gstRatePercent: _gstRatePercent,
        cgstPaise: cgstPaise,
        sgstPaise: sgstPaise,
        totalPaise: taxable + cgstPaise + sgstPaise,
      );
    }
    notifyListeners();
    await _counterApiService.updateGstSettings(
      enabled: _isGstEnabled,
      ratePercent: _gstRatePercent,
      cgstRate: _cgstRatePercent,
      sgstRate: _sgstRatePercent,
      gstin: _gstin,
    );
  }

  Future<RestaurantOrder> createTakeawayOrder({
    required String customerName,
    required String customerPhone,
    required List<OrderItem> items,
    bool fireKot = true,
  }) async {
    final token = 'TA-$_takeawayCounter';
    _takeawayCounter++;
    final orderId = 'ord_ta_${DateTime.now().millisecondsSinceEpoch}';
    final newOrder = RestaurantOrder(
      id: orderId,
      tableId: token,
      tableName: 'Takeaway $token',
      items: items,
      status: 'ACTIVE',
      guestCount: 1,
      createdAt: DateTime.now(),
      orderType: 'takeaway',
      customerName: customerName,
      customerPhone: customerPhone,
    );
    _activeOrders.insert(0, newOrder);
    selectOrder(newOrder);
    notifyListeners();

    // Call live local API to record order and print KOT
    try {
      final backendItems = items.map((i) => {
        'menuItemId': i.menuItemId,
        'quantity': i.quantity,
      }).toList();

      await _counterApiService.createTakeawayBackendOrder(
        tableId: token,
        customerName: customerName,
        customerPhone: customerPhone,
        items: backendItems,
        fireKot: fireKot,
      );
    } catch (_) {}

    return newOrder;
  }

  Future<void> toggleGst([bool? enabled]) async {
    final nextState = enabled ?? !_isGstEnabled;
    _isGstEnabled = nextState;
    if (_currentDraftBill != null) {
      final taxable = (_currentDraftBill!.subtotalPaise - _currentDraftBill!.discountPaise).clamp(0, double.infinity).toInt();
      final halfRate = (_gstRatePercent / 200.0);
      final cgst = _isGstEnabled ? (taxable * halfRate).round() : 0;
      final sgst = _isGstEnabled ? (taxable * halfRate).round() : 0;
      _currentDraftBill = _currentDraftBill!.copyWith(
        isGstEnabled: _isGstEnabled,
        gstRatePercent: _gstRatePercent,
        cgstPaise: cgst,
        sgstPaise: sgst,
        totalPaise: taxable + cgst + sgst,
      );
    }
    notifyListeners();
    await _counterApiService.updateGstSettings(enabled: _isGstEnabled, ratePercent: _gstRatePercent);
  }

  Future<void> setGstRate(double rate) async {
    _gstRatePercent = rate;
    if (_currentDraftBill != null) {
      final taxable = (_currentDraftBill!.subtotalPaise - _currentDraftBill!.discountPaise).clamp(0, double.infinity).toInt();
      final halfRate = (_gstRatePercent / 200.0);
      final cgst = _isGstEnabled ? (taxable * halfRate).round() : 0;
      final sgst = _isGstEnabled ? (taxable * halfRate).round() : 0;
      _currentDraftBill = _currentDraftBill!.copyWith(
        isGstEnabled: _isGstEnabled,
        gstRatePercent: _gstRatePercent,
        cgstPaise: cgst,
        sgstPaise: sgst,
        totalPaise: taxable + cgst + sgst,
      );
    }
    notifyListeners();
    await _counterApiService.updateGstSettings(enabled: _isGstEnabled, ratePercent: _gstRatePercent);
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

      // 1. Ensure bill is registered on backend before settlement
      RestaurantBill? liveBill;
      try {
        liveBill = await _counterApiService.generateBill(
          billToSettle.orderId,
          discountPaise: billToSettle.discountPaise,
          isGstEnabled: billToSettle.isGstEnabled,
          gstRatePercent: billToSettle.gstRatePercent,
        );
      } catch (_) {}

      final effectiveBillId = liveBill?.id ?? billToSettle.id;

      // 2. Connect to Live API: POST /api/bills/:id/payments
      final ok = await _counterApiService.settlePayment(
        billId: effectiveBillId,
        orderId: billToSettle.orderId,
        method: method.name.toUpperCase(),
        amountPaise: billToSettle.totalPaise,
        reference: reference,
      );

      if (!ok && liveBill != null) {
        throw Exception('Failed to settle payment on local POS server.');
      }

      final settledBill = billToSettle.copyWith(
        cashierName: _ownerName.isNotEmpty ? _ownerName : 'Cashier',
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

  void toggleMenuItemDeliveryAvailability(String id) {
    final index = _menuItems.indexWhere((m) => m.id == id);
    if (index >= 0) {
      final current = _menuItems[index];
      final newStatus = !current.isDeliveryAvailable;
      _menuItems[index] = current.copyWith(isDeliveryAvailable: newStatus);
      notifyListeners();
      _apiClient.toggleMenuItemDeliveryAvailability(id, newStatus);
    }
  }

  Future<({bool success, String? errorMessage})> addNewMenuItemWithResult({
    required String name,
    required String category,
    required int pricePaise,
    required bool isVeg,
    String? description,
    String? imageUrl,
  }) async {
    if (_menuItems.length >= _menuItemsLimit) {
      return (
        success: false,
        errorMessage: 'Menu items limit reached ($_menuItemsLimit max). Upgrade your license in Hinopt Admin to add more items.'
      );
    }

    final res = await _apiClient.createMenuItemWithDetails(
      name: name,
      category: category,
      pricePaise: pricePaise,
      isVeg: isVeg,
      description: description,
      imageUrl: imageUrl,
    );

    if (res.item != null) {
      _menuItems.insert(0, res.item!);
      _menuItemsUsage = _menuItems.length;
      notifyListeners();
      return (success: true, errorMessage: null);
    }

    if (res.errorMessage != null && res.errorMessage!.toLowerCase().contains('limit')) {
      return (success: false, errorMessage: res.errorMessage);
    }

    if (_localServerHealthy) {
      return (success: false, errorMessage: res.errorMessage ?? 'Failed to add dish to server.');
    }

    // Local fallback if completely offline and limit not reached
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
    _menuItemsUsage = _menuItems.length;
    notifyListeners();
    return (success: true, errorMessage: null);
  }

  Future<bool> addNewMenuItem({
    required String name,
    required String category,
    required int pricePaise,
    required bool isVeg,
    String? description,
    String? imageUrl,
  }) async {
    final res = await addNewMenuItemWithResult(
      name: name,
      category: category,
      pricePaise: pricePaise,
      isVeg: isVeg,
      description: description,
      imageUrl: imageUrl,
    );
    return res.success;
  }

  Future<void> updateMenuItemPrice(String id, int newPricePaise) async {
    final index = _menuItems.indexWhere((m) => m.id == id);
    if (index >= 0) {
      _menuItems[index] = _menuItems[index].copyWith(pricePaise: newPricePaise);
      notifyListeners();
      await _counterApiService.updateMenuItemPrice(id, newPricePaise);
    }
  }

  Future<bool> updateMenuItemDetails({
    required String id,
    required String name,
    required String category,
    required int pricePaise,
    required bool isVeg,
    String? description,
  }) async {
    final index = _menuItems.indexWhere((m) => m.id == id);
    if (index >= 0) {
      _menuItems[index] = _menuItems[index].copyWith(
        name: name,
        category: category,
        pricePaise: pricePaise,
        isVeg: isVeg,
        description: description ?? '',
      );
      notifyListeners();
      return await _counterApiService.updateMenuItem(
        id: id,
        name: name,
        category: category,
        pricePaise: pricePaise,
        isVeg: isVeg,
        description: description ?? '',
      );
    }
    return false;
  }

  Future<bool> deleteMenuItem(String id) async {
    await _counterApiService.deleteMenuItem(id);
    _menuItems.removeWhere((item) => item.id == id);
    notifyListeners();
    return true;
  }

  Future<bool> renameCategory(String oldName, String newName) async {
    final oldTrimmed = oldName.trim();
    final newTrimmed = newName.trim();
    if (oldTrimmed.isEmpty || newTrimmed.isEmpty || oldTrimmed.toLowerCase() == newTrimmed.toLowerCase()) {
      return false;
    }

    // Update in-memory dishes immediately for instant UI responsiveness
    for (int i = 0; i < _menuItems.length; i++) {
      if (_menuItems[i].category.trim().toLowerCase() == oldTrimmed.toLowerCase()) {
        _menuItems[i] = _menuItems[i].copyWith(category: newTrimmed);
      }
    }
    notifyListeners();

    // Sync to local POS server
    final ok = await _counterApiService.renameCategory(oldTrimmed, newTrimmed);
    return ok;
  }

  Future<bool> deleteCategory(String categoryName, [String reassignTo = 'Others']) async {
    final catTrimmed = categoryName.trim();
    if (catTrimmed.isEmpty) return false;

    // Update in-memory dishes immediately
    for (int i = 0; i < _menuItems.length; i++) {
      if (_menuItems[i].category.trim().toLowerCase() == catTrimmed.toLowerCase()) {
        _menuItems[i] = _menuItems[i].copyWith(category: reassignTo);
      }
    }
    notifyListeners();

    final ok = await _counterApiService.deleteCategory(catTrimmed, reassignTo);
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

  Future<({bool success, String? errorMessage})> approveDeviceWithResult(String deviceId) async {
    if (_captainDevicesUsage >= _captainDevicesLimit) {
      return (
        success: false,
        errorMessage: 'Captain devices limit reached ($_captainDevicesLimit max). Upgrade your license in Hinopt Admin to connect more devices.'
      );
    }
    final res = await _apiClient.approveDeviceWithResult(deviceId);
    if (res.success) {
      _pendingDevices.removeWhere((d) => d['id'] == deviceId);
      _captainDevicesUsage++;
      notifyListeners();
    }
    return res;
  }

  Future<bool> approveDevice(String deviceId) async {
    final res = await approveDeviceWithResult(deviceId);
    return res.success;
  }

  Future<bool> rejectDevice(String deviceId) async {
    final ok = await _apiClient.rejectDevice(deviceId);
    if (ok) {
      _pendingDevices.removeWhere((d) => d['id'] == deviceId);
      notifyListeners();
    }
    return ok;
  }

  Future<void> testPrint(PrinterRole role) async {
    final printerList = printers;
    final printer = printerList.where((p) => p.role == role).firstOrNull;
    if (printer != null) {
      bool success = true;
      if (_localServerHealthy) {
        success = await _apiClient.testPrint(printer.id);
      }
      if (_printers.isEmpty) {
        _printers = List.from(printerList);
      }
      final index = _printers.indexWhere((p) => p.role == role);
      if (index >= 0) {
        _printers[index] = printer.copyWith(
          lastTestPrintAt: DateTime.now(),
          isConnected: success || !_localServerHealthy,
        );
      }
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

  Future<({bool success, String? message})> submitUpgradeRequest({
    required int requestedMenuItems,
    required int requestedCaptainDevices,
    required int requestedCounterPcs,
    String? contactPhone,
    String? notes,
  }) async {
    return await _counterApiService.submitUpgradeRequest(
      requestedMenuItems: requestedMenuItems,
      requestedCaptainDevices: requestedCaptainDevices,
      requestedCounterPcs: requestedCounterPcs,
      contactPhone: contactPhone,
      notes: notes,
    );
  }
}
