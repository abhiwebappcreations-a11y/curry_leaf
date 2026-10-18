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

  bool get localServerHealthy => _localServerHealthy;
  bool get databaseHealthy => _databaseHealthy;
  String get licenseStatus => _licenseStatus;
  int get licenseDaysRemaining => _licenseDaysRemaining;
  String get serverHost => _counterApiService.host;
  int get serverPort => _counterApiService.port;
  bool get isRefreshing => _isRefreshing;

  Future<void> setServerHost(String host, [int port = 4000]) async {
    _counterApiService.updateHost(host, port);
    notifyListeners();
    await refreshFromLiveApi(isManual: true);
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

      final liveTables = await _apiClient.getTables();
      if (liveTables != null && liveTables.isNotEmpty) {
        _tables = liveTables;
      }

      final tableMap = {for (var t in _tables) t.id: t.name};
      final liveOrders = await _apiClient.getActiveOrders(tableIdToName: tableMap);
      if (liveOrders != null) {
        _activeOrders = liveOrders;
      }

      final livePrinters = await _apiClient.getPrinters();
      if (livePrinters != null && livePrinters.isNotEmpty) {
        _printers = livePrinters;
      }

      final liveMenu = await _apiClient.getMenu();
      if (liveMenu != null && liveMenu.isNotEmpty) {
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

    // Call POST /api/orders/:id/bill to finalize on backend if live, or fallback to local model
    final liveBill = await _apiClient.generateBill(order.id);
    if (liveBill != null) {
      _currentDraftBill = liveBill.copyWith(
        cashierName: 'Deepa',
        tableName: order.tableName,
      );
    } else {
      _currentDraftBill = RestaurantBill.fromOrder(
        order: order,
        billNumber: 'INV-2026-00${_settledBills.length + 44}',
        cashierName: 'Deepa',
      );
    }

    _activeTab = CounterTab.billing;
    notifyListeners();
  }

  void selectOrderByTableId(String tableId) {
    final order = _activeOrders.where((o) => o.tableId == tableId).firstOrNull;
    if (order != null) {
      selectOrder(order);
    }
  }

  void applyDiscount(int discountPaise, String reason) {
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
      _menuItems[index] = current.copyWith(isAvailable: !current.isAvailable);
      notifyListeners();
    }
  }

  void updateMenuItemPrice(String id, int newPricePaise) {
    final index = _menuItems.indexWhere((m) => m.id == id);
    if (index >= 0) {
      _menuItems[index] = _menuItems[index].copyWith(pricePaise: newPricePaise);
      notifyListeners();
    }
  }

  Future<void> testPrint(PrinterRole role) async {
    final printer = _printers.where((p) => p.role == role).firstOrNull;
    if (printer != null) {
      await _apiClient.testPrint(printer.id);
      final index = _printers.indexOf(printer);
      _printers[index] = printer.copyWith(
        lastTestPrintAt: DateTime.now(),
        isConnected: true,
      );
      notifyListeners();
    }
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
