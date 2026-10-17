import '../models/table_model.dart';
import '../models/menu_item_model.dart';
import '../models/order_model.dart';

class MockData {
  static List<RestaurantTable> getInitialTables() {
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

  static List<MenuItem> getInitialMenu() {
    return [
      // Starters
      MenuItem(
        id: 'm-1',
        name: 'Paneer Tikka Angara',
        category: 'Starters',
        pricePaise: 28000, // ₹ 280
        isVeg: true,
        description: 'Charcoal grilled cottage cheese marinated in fiery spices and yoghurt.',
        variants: ['Mild', 'Medium Spicy', 'Extra Spicy'],
        addons: ['Extra Mint Chutney', 'Extra Onion Salad'],
      ),
      MenuItem(
        id: 'm-2',
        name: 'Crispy Corn & Waterchestnut',
        category: 'Starters',
        pricePaise: 24000, // ₹ 240
        isVeg: true,
        description: 'Golden fried sweet corn tossed with bell peppers and black pepper.',
      ),
      MenuItem(
        id: 'm-3',
        name: 'Chicken Ghee Roast',
        category: 'Starters',
        pricePaise: 36000, // ₹ 360
        isVeg: false,
        description: 'Mangalorean delicacy cooked in pure desi ghee and fiery Byadgi chillies.',
        variants: ['Bone-in', 'Boneless'],
      ),
      MenuItem(
        id: 'm-4',
        name: 'Mutton Seekh Kebab',
        category: 'Starters',
        pricePaise: 42000, // ₹ 420
        isVeg: false,
        description: 'Finely minced spiced mutton skewered and roasted in traditional tandoor.',
      ),

      // Biryani & Rice
      MenuItem(
        id: 'm-5',
        name: 'Hyderabadi Chicken Dum Biryani',
        category: 'Biryani & Rice',
        pricePaise: 38000, // ₹ 380
        isVeg: false,
        description: 'Aromatic aged basmati rice layered with marinated tender chicken and saffron.',
        variants: ['Regular', 'Double Masala'],
        addons: ['Extra Mirchi Ka Salan', 'Extra Raita', 'Boiled Egg'],
      ),
      MenuItem(
        id: 'm-6',
        name: 'Dum Pukht Mutton Biryani',
        category: 'Biryani & Rice',
        pricePaise: 48000, // ₹ 480
        isVeg: false,
        description: 'Slow-cooked succulent mutton shank layered with flavored basmati rice.',
      ),
      MenuItem(
        id: 'm-7',
        name: 'Subz Nizami Biryani',
        category: 'Biryani & Rice',
        pricePaise: 31000, // ₹ 310
        isVeg: true,
        description: 'Garden fresh vegetables and paneer cooked in aromatic spices and saffron dum.',
      ),
      MenuItem(
        id: 'm-8',
        name: 'Jeera Rice & Dal Tadka Combo',
        category: 'Biryani & Rice',
        pricePaise: 22000, // ₹ 220
        isVeg: true,
        description: 'Cumin tempered basmati rice served with yellow lentils and garlic tadka.',
      ),

      // Curries & Gravies
      MenuItem(
        id: 'm-9',
        name: 'Butter Chicken Grand Trunk',
        category: 'Curries',
        pricePaise: 39000, // ₹ 390
        isVeg: false,
        description: 'Clay oven cooked chicken in velvety tomato-butter gravy with fenugreek.',
        variants: ['Sweet & Mild', 'Traditional Spicy'],
      ),
      MenuItem(
        id: 'm-10',
        name: 'Paneer Butter Masala',
        category: 'Curries',
        pricePaise: 32000, // ₹ 320
        isVeg: true,
        description: 'Soft cottage cheese simmered in a rich tomato, butter, and cashew sauce.',
      ),
      MenuItem(
        id: 'm-11',
        name: 'Dal Makhani Heritage',
        category: 'Curries',
        pricePaise: 29000, // ₹ 290
        isVeg: true,
        description: 'Whole black lentils simmered overnight with cream, butter, and garlic.',
      ),
      MenuItem(
        id: 'm-12',
        name: 'Rogan Josh Kashmiri',
        category: 'Curries',
        pricePaise: 46000, // ₹ 460
        isVeg: false,
        description: 'Tender braised mutton chunks cooked with Kashmiri chillies and aromatic herbs.',
      ),

      // Breads
      MenuItem(
        id: 'm-13',
        name: 'Butter Garlic Naan',
        category: 'Breads',
        pricePaise: 7500, // ₹ 75
        isVeg: true,
        description: 'Tandoori refined flour bread glazed with garlic butter and fresh cilantro.',
      ),
      MenuItem(
        id: 'm-14',
        name: 'Butter Roti (Whole Wheat)',
        category: 'Breads',
        pricePaise: 3500, // ₹ 35
        isVeg: true,
        description: 'Whole wheat flatbread baked in clay oven topped with butter.',
      ),
      MenuItem(
        id: 'm-15',
        name: 'Cheese Chilli Naan',
        category: 'Breads',
        pricePaise: 11000, // ₹ 110
        isVeg: true,
        description: 'Stuffed with mozzarella cheese and chopped green chillies.',
      ),

      // Beverages & Desserts
      MenuItem(
        id: 'm-16',
        name: 'Royal Kesaria Lassi',
        category: 'Beverages',
        pricePaise: 12000, // ₹ 120
        isVeg: true,
        description: 'Thick churned sweet yogurt drink flavored with saffron and crushed pistachios.',
      ),
      MenuItem(
        id: 'm-17',
        name: 'Fresh Lime Soda (Sweet/Salt)',
        category: 'Beverages',
        pricePaise: 8000, // ₹ 80
        isVeg: true,
        description: 'Refreshing chilled soda with freshly squeezed lime juice.',
      ),
      MenuItem(
        id: 'm-18',
        name: 'Gulab Jamun with Rabri',
        category: 'Desserts',
        pricePaise: 15000, // ₹ 150
        isVeg: true,
        description: 'Warm fried milk dumplings served with chilled condensed milk rabri.',
      ),
    ];
  }

  static Map<String, RestaurantOrder> getSeedOrders() {
    return {
      'tbl-2': RestaurantOrder(
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
            isDraft: false,
            sentAt: DateTime.now().subtract(const Duration(minutes: 30)),
            status: OrderItemStatus.served,
          ),
          OrderItem(
            id: 'item-2',
            menuItemId: 'm-5',
            name: 'Hyderabadi Chicken Dum Biryani',
            quantity: 1,
            pricePaise: 38000,
            isVeg: false,
            isDraft: false,
            sentAt: DateTime.now().subtract(const Duration(minutes: 25)),
            status: OrderItemStatus.preparing,
          ),
          OrderItem(
            id: 'item-3',
            menuItemId: 'm-16',
            name: 'Royal Kesaria Lassi',
            quantity: 2,
            pricePaise: 12000,
            isVeg: true,
            isDraft: false,
            sentAt: DateTime.now().subtract(const Duration(minutes: 25)),
            status: OrderItemStatus.served,
          ),
        ],
      ),
      'tbl-4': RestaurantOrder(
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
            isDraft: false,
            sentAt: DateTime.now().subtract(const Duration(minutes: 50)),
            status: OrderItemStatus.served,
          ),
          OrderItem(
            id: 'item-5',
            menuItemId: 'm-9',
            name: 'Butter Chicken Grand Trunk',
            quantity: 1,
            pricePaise: 39000,
            isVeg: false,
            isDraft: false,
            sentAt: DateTime.now().subtract(const Duration(minutes: 40)),
            status: OrderItemStatus.served,
          ),
          OrderItem(
            id: 'item-6',
            menuItemId: 'm-13',
            name: 'Butter Garlic Naan',
            quantity: 4,
            pricePaise: 7500,
            isVeg: true,
            isDraft: false,
            sentAt: DateTime.now().subtract(const Duration(minutes: 40)),
            status: OrderItemStatus.served,
          ),
          OrderItem(
            id: 'item-7',
            menuItemId: 'm-5',
            name: 'Hyderabadi Chicken Dum Biryani',
            quantity: 1,
            pricePaise: 38000,
            isVeg: false,
            isDraft: false,
            sentAt: DateTime.now().subtract(const Duration(minutes: 35)),
            status: OrderItemStatus.preparing,
          ),
        ],
      ),
    };
  }
}
