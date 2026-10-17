import '../models/table_model.dart';
import '../models/order_model.dart';
import '../models/bill_model.dart';
import '../models/menu_model.dart';
import '../models/printer_model.dart';

class MockCounterData {
  static List<RestaurantTable> getTables() {
    return [
      RestaurantTable(
        id: 'tbl-1',
        name: 'T-01',
        section: 'Main Hall',
        capacity: 2,
        status: TableStatus.available,
      ),
      RestaurantTable(
        id: 'tbl-2',
        name: 'T-02',
        section: 'Main Hall',
        capacity: 4,
        status: TableStatus.occupied,
        activeOrderId: 'ord-101',
        activeOrderTotalPaise: 88000, // ₹ 880
        occupiedSince: DateTime.now().subtract(const Duration(minutes: 35)),
        guestCount: 3,
      ),
      RestaurantTable(
        id: 'tbl-3',
        name: 'T-03',
        section: 'Main Hall',
        capacity: 6,
        status: TableStatus.available,
      ),
      RestaurantTable(
        id: 'tbl-4',
        name: 'T-04',
        section: 'AC Dining',
        capacity: 4,
        status: TableStatus.occupied,
        activeOrderId: 'ord-102',
        activeOrderTotalPaise: 145000, // ₹ 1,450
        occupiedSince: DateTime.now().subtract(const Duration(minutes: 55)),
        guestCount: 4,
      ),
      RestaurantTable(
        id: 'tbl-5',
        name: 'T-05',
        section: 'AC Dining',
        capacity: 4,
        status: TableStatus.billed,
        activeOrderId: 'ord-103',
        activeOrderTotalPaise: 210000, // ₹ 2,100
        occupiedSince: DateTime.now().subtract(const Duration(minutes: 75)),
        guestCount: 4,
      ),
      RestaurantTable(
        id: 'tbl-6',
        name: 'T-06',
        section: 'AC Dining',
        capacity: 8,
        status: TableStatus.reserved,
      ),
      RestaurantTable(
        id: 'tbl-7',
        name: 'R-01',
        section: 'Rooftop',
        capacity: 4,
        status: TableStatus.available,
      ),
      RestaurantTable(
        id: 'tbl-8',
        name: 'R-02',
        section: 'Rooftop',
        capacity: 4,
        status: TableStatus.occupied,
        activeOrderId: 'ord-104',
        activeOrderTotalPaise: 62000, // ₹ 620
        occupiedSince: DateTime.now().subtract(const Duration(minutes: 20)),
        guestCount: 2,
      ),
      RestaurantTable(
        id: 'tbl-9',
        name: 'TK-1',
        section: 'Takeaway',
        capacity: 1,
        status: TableStatus.available,
      ),
    ];
  }

  static List<RestaurantOrder> getActiveOrders() {
    return [
      RestaurantOrder(
        id: 'ord-101',
        tableId: 'tbl-2',
        tableName: 'T-02',
        createdAt: DateTime.now().subtract(const Duration(minutes: 35)),
        guestCount: 3,
        items: [
          OrderItem(
            id: 'item-1',
            menuItemId: 'm-1',
            name: 'Paneer Tikka Angara',
            quantity: 1,
            pricePaise: 28000,
            isVeg: true,
            status: OrderItemStatus.served,
            sentAt: DateTime.now().subtract(const Duration(minutes: 30)),
          ),
          OrderItem(
            id: 'item-2',
            menuItemId: 'm-5',
            name: 'Hyderabadi Chicken Dum Biryani',
            quantity: 1,
            pricePaise: 38000,
            isVeg: false,
            status: OrderItemStatus.preparing,
            sentAt: DateTime.now().subtract(const Duration(minutes: 25)),
          ),
          OrderItem(
            id: 'item-3',
            menuItemId: 'm-16',
            name: 'Royal Kesaria Lassi',
            quantity: 2,
            pricePaise: 12000,
            isVeg: true,
            status: OrderItemStatus.served,
            sentAt: DateTime.now().subtract(const Duration(minutes: 25)),
          ),
        ],
      ),
      RestaurantOrder(
        id: 'ord-102',
        tableId: 'tbl-4',
        tableName: 'T-04',
        createdAt: DateTime.now().subtract(const Duration(minutes: 55)),
        guestCount: 4,
        items: [
          OrderItem(
            id: 'item-4',
            menuItemId: 'm-3',
            name: 'Chicken Ghee Roast',
            quantity: 1,
            pricePaise: 36000,
            isVeg: false,
            status: OrderItemStatus.served,
            sentAt: DateTime.now().subtract(const Duration(minutes: 50)),
          ),
          OrderItem(
            id: 'item-5',
            menuItemId: 'm-9',
            name: 'Butter Chicken Grand Trunk',
            quantity: 1,
            pricePaise: 39000,
            isVeg: false,
            status: OrderItemStatus.served,
            sentAt: DateTime.now().subtract(const Duration(minutes: 40)),
          ),
          OrderItem(
            id: 'item-6',
            menuItemId: 'm-13',
            name: 'Butter Garlic Naan',
            quantity: 4,
            pricePaise: 7500,
            isVeg: true,
            status: OrderItemStatus.served,
            sentAt: DateTime.now().subtract(const Duration(minutes: 40)),
          ),
          OrderItem(
            id: 'item-7',
            menuItemId: 'm-5',
            name: 'Hyderabadi Chicken Dum Biryani',
            quantity: 1,
            pricePaise: 38000,
            isVeg: false,
            status: OrderItemStatus.served,
            sentAt: DateTime.now().subtract(const Duration(minutes: 35)),
          ),
        ],
      ),
      RestaurantOrder(
        id: 'ord-103',
        tableId: 'tbl-5',
        tableName: 'T-05',
        createdAt: DateTime.now().subtract(const Duration(minutes: 75)),
        guestCount: 4,
        items: [
          OrderItem(
            id: 'item-8',
            menuItemId: 'm-6',
            name: 'Dum Pukht Mutton Biryani',
            quantity: 2,
            pricePaise: 48000,
            isVeg: false,
            status: OrderItemStatus.served,
            sentAt: DateTime.now().subtract(const Duration(minutes: 65)),
          ),
          OrderItem(
            id: 'item-9',
            menuItemId: 'm-12',
            name: 'Rogan Josh Kashmiri',
            quantity: 1,
            pricePaise: 46000,
            isVeg: false,
            status: OrderItemStatus.served,
            sentAt: DateTime.now().subtract(const Duration(minutes: 65)),
          ),
          OrderItem(
            id: 'item-10',
            menuItemId: 'm-15',
            name: 'Cheese Chilli Naan',
            quantity: 4,
            pricePaise: 11000,
            isVeg: true,
            status: OrderItemStatus.served,
            sentAt: DateTime.now().subtract(const Duration(minutes: 60)),
          ),
          OrderItem(
            id: 'item-11',
            menuItemId: 'm-18',
            name: 'Gulab Jamun with Rabri',
            quantity: 4,
            pricePaise: 15000,
            isVeg: true,
            status: OrderItemStatus.served,
            sentAt: DateTime.now().subtract(const Duration(minutes: 45)),
          ),
        ],
      ),
      RestaurantOrder(
        id: 'ord-104',
        tableId: 'tbl-8',
        tableName: 'R-02',
        createdAt: DateTime.now().subtract(const Duration(minutes: 20)),
        guestCount: 2,
        items: [
          OrderItem(
            id: 'item-12',
            menuItemId: 'm-1',
            name: 'Paneer Tikka Angara',
            quantity: 1,
            pricePaise: 28000,
            isVeg: true,
            status: OrderItemStatus.preparing,
            sentAt: DateTime.now().subtract(const Duration(minutes: 18)),
          ),
          OrderItem(
            id: 'item-13',
            menuItemId: 'm-2',
            name: 'Crispy Corn & Waterchestnut',
            quantity: 1,
            pricePaise: 24000,
            isVeg: true,
            status: OrderItemStatus.preparing,
            sentAt: DateTime.now().subtract(const Duration(minutes: 18)),
          ),
          OrderItem(
            id: 'item-14',
            menuItemId: 'm-17',
            name: 'Fresh Lime Soda (Sweet/Salt)',
            quantity: 2,
            pricePaise: 8000,
            isVeg: true,
            status: OrderItemStatus.served,
            sentAt: DateTime.now().subtract(const Duration(minutes: 15)),
          ),
        ],
      ),
    ];
  }

  static List<RestaurantBill> getSettledBills() {
    return [
      RestaurantBill(
        id: 'bill-801',
        billNumber: 'INV-2026-0041',
        orderId: 'ord-098',
        tableId: 'tbl-1',
        tableName: 'T-01',
        cashierName: 'Deepa (Shift A)',
        items: [
          BillItemSnapshot(name: 'Hyderabadi Chicken Dum Biryani', quantity: 2, unitPricePaise: 38000, totalPaise: 76000),
          BillItemSnapshot(name: 'Fresh Lime Soda', quantity: 2, unitPricePaise: 8000, totalPaise: 16000),
        ],
        subtotalPaise: 92000,
        cgstPaise: 2300,
        sgstPaise: 2300,
        totalPaise: 96600, // ₹ 966
        paymentMethod: PaymentMethod.upi,
        paymentStatus: PaymentStatus.settled,
        paymentReference: 'UPI/984729103829',
        createdAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 15)),
        settledAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 10)),
      ),
      RestaurantBill(
        id: 'bill-802',
        billNumber: 'INV-2026-0042',
        orderId: 'ord-099',
        tableId: 'tbl-3',
        tableName: 'T-03',
        cashierName: 'Deepa (Shift A)',
        items: [
          BillItemSnapshot(name: 'Butter Chicken Grand Trunk', quantity: 2, unitPricePaise: 39000, totalPaise: 78000),
          BillItemSnapshot(name: 'Butter Garlic Naan', quantity: 6, unitPricePaise: 7500, totalPaise: 45000),
          BillItemSnapshot(name: 'Royal Kesaria Lassi', quantity: 3, unitPricePaise: 12000, totalPaise: 36000),
        ],
        subtotalPaise: 159000,
        discountPaise: 9000,
        discountReason: 'Loyalty Regular 5%',
        cgstPaise: 3750,
        sgstPaise: 3750,
        totalPaise: 157500, // ₹ 1,575
        paymentMethod: PaymentMethod.card,
        paymentStatus: PaymentStatus.settled,
        paymentReference: 'CARD-TXN-882190',
        createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 30)),
        settledAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 25)),
      ),
      RestaurantBill(
        id: 'bill-803',
        billNumber: 'INV-2026-0043',
        orderId: 'ord-100',
        tableId: 'tbl-7',
        tableName: 'R-01',
        cashierName: 'Deepa (Shift A)',
        items: [
          BillItemSnapshot(name: 'Paneer Butter Masala', quantity: 1, unitPricePaise: 32000, totalPaise: 32000),
          BillItemSnapshot(name: 'Butter Roti (Whole Wheat)', quantity: 4, unitPricePaise: 3500, totalPaise: 14000),
        ],
        subtotalPaise: 46000,
        cgstPaise: 1150,
        sgstPaise: 1150,
        totalPaise: 48300, // ₹ 483
        paymentMethod: PaymentMethod.cash,
        paymentStatus: PaymentStatus.settled,
        createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
        settledAt: DateTime.now().subtract(const Duration(minutes: 40)),
      ),
    ];
  }

  static List<ThermalPrinterConfig> getPrinters() {
    return [
      ThermalPrinterConfig(
        id: 'prn-bill',
        role: PrinterRole.counterBill,
        name: 'Epson TM-T82III (Billing)',
        connectionType: PrinterConnectionType.usb,
        address: 'USB001',
        paperWidthMm: 80,
        isConnected: true,
        lastTestPrintAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      ThermalPrinterConfig(
        id: 'prn-kot',
        role: PrinterRole.kitchenKot,
        name: 'TVS RP-3200 Plus (Kitchen)',
        connectionType: PrinterConnectionType.ethernet,
        address: '192.168.1.200',
        port: 9100,
        paperWidthMm: 80,
        isConnected: true,
        lastTestPrintAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ];
  }

  static List<MenuItem> getMenuItems() {
    return [
      MenuItem(id: 'm-1', name: 'Paneer Tikka Angara', category: 'Starters', pricePaise: 28000, isVeg: true, isAvailable: true),
      MenuItem(id: 'm-2', name: 'Crispy Corn & Waterchestnut', category: 'Starters', pricePaise: 24000, isVeg: true, isAvailable: true),
      MenuItem(id: 'm-3', name: 'Chicken Ghee Roast', category: 'Starters', pricePaise: 36000, isVeg: false, isAvailable: true),
      MenuItem(id: 'm-4', name: 'Mutton Seekh Kebab', category: 'Starters', pricePaise: 42000, isVeg: false, isAvailable: true),
      MenuItem(id: 'm-5', name: 'Hyderabadi Chicken Dum Biryani', category: 'Biryani & Rice', pricePaise: 38000, isVeg: false, isAvailable: true),
      MenuItem(id: 'm-6', name: 'Dum Pukht Mutton Biryani', category: 'Biryani & Rice', pricePaise: 48000, isVeg: false, isAvailable: true),
      MenuItem(id: 'm-7', name: 'Subz Nizami Biryani', category: 'Biryani & Rice', pricePaise: 31000, isVeg: true, isAvailable: true),
      MenuItem(id: 'm-8', name: 'Jeera Rice & Dal Tadka', category: 'Biryani & Rice', pricePaise: 22000, isVeg: true, isAvailable: true),
      MenuItem(id: 'm-9', name: 'Butter Chicken Grand Trunk', category: 'Curries', pricePaise: 39000, isVeg: false, isAvailable: true),
      MenuItem(id: 'm-10', name: 'Paneer Butter Masala', category: 'Curries', pricePaise: 32000, isVeg: true, isAvailable: true),
      MenuItem(id: 'm-11', name: 'Dal Makhani Heritage', category: 'Curries', pricePaise: 29000, isVeg: true, isAvailable: true),
      MenuItem(id: 'm-12', name: 'Rogan Josh Kashmiri', category: 'Curries', pricePaise: 46000, isVeg: false, isAvailable: true),
      MenuItem(id: 'm-13', name: 'Butter Garlic Naan', category: 'Breads', pricePaise: 7500, isVeg: true, isAvailable: true),
      MenuItem(id: 'm-14', name: 'Butter Roti (Whole Wheat)', category: 'Breads', pricePaise: 3500, isVeg: true, isAvailable: true),
      MenuItem(id: 'm-15', name: 'Cheese Chilli Naan', category: 'Breads', pricePaise: 11000, isVeg: true, isAvailable: true),
      MenuItem(id: 'm-16', name: 'Royal Kesaria Lassi', category: 'Beverages', pricePaise: 12000, isVeg: true, isAvailable: true),
      MenuItem(id: 'm-17', name: 'Fresh Lime Soda (Sweet/Salt)', category: 'Beverages', pricePaise: 8000, isVeg: true, isAvailable: true),
      MenuItem(id: 'm-18', name: 'Gulab Jamun with Rabri', category: 'Desserts', pricePaise: 15000, isVeg: true, isAvailable: true),
    ];
  }
}
