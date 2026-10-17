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

  CounterProvider() {
    _initData();
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
    await refreshFromLiveApi();
  }

  Future<void> refreshFromLiveApi() async {
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

      final liveOrders = await _apiClient.getActiveOrders();
      if (liveOrders != null && liveOrders.isNotEmpty) {
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
    } catch (_) {}

    notifyListeners();
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

  Future<void> reprintBill(RestaurantBill bill, String reason) async {
    final index = _settledBills.indexWhere((b) => b.id == bill.id);
    if (index >= 0) {
      await _apiClient.reprintBill(bill.id, reason: reason);
      final updated = bill.copyWith(
        isReprint: true,
        reprintCount: bill.reprintCount + 1,
      );
      _settledBills[index] = updated;
      notifyListeners();
    }
  }

  void toggleMenuItemAvailability(String id) {
    final index = _menuItems.indexWhere((m) => m.id == id);
    if (index >= 0) {
      final item = _menuItems[index];
      _menuItems[index] = item.copyWith(isAvailable: !item.isAvailable);
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
    final index = _printers.indexWhere((p) => p.role == role);
    if (index >= 0) {
      final printer = _printers[index];
      await _apiClient.testPrint(printer.id);
      _printers[index] = _printers[index].copyWith(
        lastTestPrintAt: DateTime.now(),
        isConnected: true,
      );
      notifyListeners();
    }
  }

  void updatePrinter(ThermalPrinterConfig config) {
    final index = _printers.indexWhere((p) => p.id == config.id);
    if (index >= 0) {
      _printers[index] = config;
      notifyListeners();
    }
  }

  // Reports
  double get totalSalesRupees {
    final paise = _settledBills.fold(0, (sum, b) => sum + b.totalPaise);
    return paise / 100.0;
  }

  double get totalGstRupees {
    final paise = _settledBills.fold(0, (sum, b) => sum + b.cgstPaise + b.sgstPaise);
    return paise / 100.0;
  }

  double get totalDiscountsRupees {
    final paise = _settledBills.fold(0, (sum, b) => sum + b.discountPaise);
    return paise / 100.0;
  }

  Map<PaymentMethod, double> get salesByMethod {
    final map = <PaymentMethod, double>{
      PaymentMethod.cash: 0.0,
      PaymentMethod.upi: 0.0,
      PaymentMethod.card: 0.0,
      PaymentMethod.split: 0.0,
    };
    for (var b in _settledBills) {
      map[b.paymentMethod] = (map[b.paymentMethod] ?? 0) + b.totalRupees;
    }
    return map;
  }
}
