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
        id: 'm-19',
        name: 'Curry Leaf Paneer 65',
        category: 'Starters',
        pricePaise: 24000,
        isVeg: true,
        description: 'Crisp cottage cheese cubes tossed in spicy tempering with fresh curry leaves.',
        imageUrl: 'https://images.unsplash.com/photo-1567184109-775c97b8782a?auto=format&fit=crop&w=600&q=80',
        variants: ['Half', 'Full'],
        addons: ['Extra Chilli Dip'],
      ),
      MenuItem(
        id: 'm-1',
        name: 'Paneer Tikka Angara',
        category: 'Starters',
        pricePaise: 28000, // ₹ 280
        isVeg: true,
        description: 'Charcoal grilled cottage cheese marinated in fiery spices and yoghurt.',
        imageUrl: 'https://images.unsplash.com/photo-1599488615731-7e5c2823ff28?auto=format&fit=crop&w=600&q=80',
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
        imageUrl: 'https://images.unsplash.com/photo-1551782450-a2132b4ba21d?auto=format&fit=crop&w=600&q=80',
      ),
      MenuItem(
        id: 'm-3',
        name: 'Kundapura Chicken Ghee Roast',
        category: 'Starters',
        pricePaise: 36000, // ₹ 360
        isVeg: false,
        description: 'Mangalorean delicacy cooked in pure desi ghee and fiery Byadgi chillies.',
        imageUrl: 'https://images.unsplash.com/photo-1626777552726-4a6b54c97e46?auto=format&fit=crop&w=600&q=80',
        variants: ['Half', 'Full'],
      ),
      MenuItem(
        id: 'm-20',
        name: 'Guntur Chilli Chicken Fry',
        category: 'Starters',
        pricePaise: 32000,
        isVeg: false,
        description: 'Andhra-style spiced boneless chicken tossed with fiery green chillies and curry leaves.',
        imageUrl: 'https://images.unsplash.com/photo-1562967914-608f82629710?auto=format&fit=crop&w=600&q=80',
      ),
      MenuItem(
        id: 'm-4',
        name: 'Mutton Seekh Kebab',
        category: 'Starters',
        pricePaise: 42000, // ₹ 420
        isVeg: false,
        description: 'Finely minced spiced mutton skewered and roasted in traditional tandoor.',
        imageUrl: 'https://images.unsplash.com/photo-1599488615731-7e5c2823ff28?auto=format&fit=crop&w=600&q=80',
      ),

      // Tandoor & Grills
      MenuItem(
        id: 'm-21',
        name: 'Tandoori Murgh (Clay Oven)',
        category: 'Tandoor',
        pricePaise: 38000,
        isVeg: false,
        description: 'Classic whole spring chicken marinated in Kashmiri chilli yogurt and whole spices.',
        imageUrl: 'https://images.unsplash.com/photo-1610057099443-fde8c4d50f91?auto=format&fit=crop&w=600&q=80',
        variants: ['Half', 'Full'],
      ),
      MenuItem(
        id: 'm-22',
        name: 'Tandoori Malai Broccoli',
        category: 'Tandoor',
        pricePaise: 29000,
        isVeg: true,
        description: 'Fresh broccoli florets steeped in cheese, cardamom cream, and chargrilled.',
        imageUrl: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=600&q=80',
      ),

      // Biryani & Rice
      MenuItem(
        id: 'm-5',
        name: 'Hyderabadi Chicken Dum Biryani',
        category: 'Biryani & Rice',
        pricePaise: 38000, // ₹ 380
        isVeg: false,
        description: 'Aromatic aged basmati rice layered with marinated tender chicken and saffron.',
        imageUrl: 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?auto=format&fit=crop&w=600&q=80',
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
        imageUrl: 'https://images.unsplash.com/photo-1589302168068-964664d93dc0?auto=format&fit=crop&w=600&q=80',
      ),
      MenuItem(
        id: 'm-7',
        name: 'Subz Nizami Biryani',
        category: 'Biryani & Rice',
        pricePaise: 31000, // ₹ 310
        isVeg: true,
        description: 'Garden fresh vegetables and paneer cooked in aromatic spices and saffron dum.',
        imageUrl: 'https://images.unsplash.com/photo-1642821373181-696a54913e93?auto=format&fit=crop&w=600&q=80',
      ),
      MenuItem(
        id: 'm-8',
        name: 'Jeera Rice & Dal Tadka Combo',
        category: 'Biryani & Rice',
        pricePaise: 22000, // ₹ 220
        isVeg: true,
        description: 'Cumin tempered basmati rice served with yellow lentils and garlic tadka.',
        imageUrl: 'https://images.unsplash.com/photo-1512058564366-18510be2db19?auto=format&fit=crop&w=600&q=80',
      ),

      // Curries & Gravies
      MenuItem(
        id: 'm-9',
        name: 'Butter Chicken Grand Trunk',
        category: 'Curries',
        pricePaise: 39000, // ₹ 390
        isVeg: false,
        description: 'Clay oven cooked chicken in velvety tomato-butter gravy with fenugreek.',
        imageUrl: 'https://images.unsplash.com/photo-1588166524941-3bf61a9c41db?auto=format&fit=crop&w=600&q=80',
        variants: ['Sweet & Mild', 'Traditional Spicy'],
      ),
      MenuItem(
        id: 'm-10',
        name: 'Paneer Butter Masala',
        category: 'Curries',
        pricePaise: 32000, // ₹ 320
        isVeg: true,
        description: 'Soft cottage cheese simmered in a rich tomato, butter, and cashew sauce.',
        imageUrl: 'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?auto=format&fit=crop&w=600&q=80',
      ),
      MenuItem(
        id: 'm-26',
        name: 'Curry Leaf Country Chicken Curry',
        category: 'Curries',
        pricePaise: 35000,
        isVeg: false,
        description: 'Homestyle chicken simmered with ground spices, shallots, and fresh curry leaves.',
        imageUrl: 'https://images.unsplash.com/photo-1603894584373-5ac82b2ae398?auto=format&fit=crop&w=600&q=80',
      ),
      MenuItem(
        id: 'm-11',
        name: 'Dal Makhani Heritage',
        category: 'Curries',
        pricePaise: 29000, // ₹ 290
        isVeg: true,
        description: 'Whole black lentils simmered overnight with cream, butter, and garlic.',
        imageUrl: 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?auto=format&fit=crop&w=600&q=80',
      ),
      MenuItem(
        id: 'm-12',
        name: 'Rogan Josh Kashmiri',
        category: 'Curries',
        pricePaise: 46000, // ₹ 460
        isVeg: false,
        description: 'Tender braised mutton chunks cooked with Kashmiri chillies and aromatic herbs.',
        imageUrl: 'https://images.unsplash.com/photo-1545247181-516773cae7be?auto=format&fit=crop&w=600&q=80',
      ),

      // Breads
      MenuItem(
        id: 'm-13',
        name: 'Butter Garlic Naan',
        category: 'Breads',
        pricePaise: 7500, // ₹ 75
        isVeg: true,
        description: 'Tandoori refined flour bread glazed with garlic butter and fresh cilantro.',
        imageUrl: 'https://images.unsplash.com/photo-1601050690597-df0568f70950?auto=format&fit=crop&w=600&q=80',
      ),
      MenuItem(
        id: 'm-14',
        name: 'Butter Roti (Whole Wheat)',
        category: 'Breads',
        pricePaise: 3500, // ₹ 35
        isVeg: true,
        description: 'Whole wheat flatbread baked in clay oven topped with butter.',
        imageUrl: 'https://images.unsplash.com/photo-1626777552726-4a6b54c97e46?auto=format&fit=crop&w=600&q=80',
      ),
      MenuItem(
        id: 'm-15',
        name: 'Cheese Chilli Naan',
        category: 'Breads',
        pricePaise: 11000, // ₹ 110
        isVeg: true,
        description: 'Stuffed with mozzarella cheese and chopped green chillies.',
        imageUrl: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=600&q=80',
      ),

      // Beverages
      MenuItem(
        id: 'm-16',
        name: 'Royal Kesaria Lassi',
        category: 'Beverages',
        pricePaise: 12000, // ₹ 120
        isVeg: true,
        description: 'Thick churned sweet yogurt drink flavored with saffron and crushed pistachios.',
        imageUrl: 'https://images.unsplash.com/photo-1553530666-ba11a7da3888?auto=format&fit=crop&w=600&q=80',
      ),
      MenuItem(
        id: 'm-23',
        name: 'Spiced Buttermilk (Neer Moru)',
        category: 'Beverages',
        pricePaise: 6000,
        isVeg: true,
        description: 'Refreshing churned yogurt tempered with ginger, green chilli, and curry leaves.',
        imageUrl: 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?auto=format&fit=crop&w=600&q=80',
      ),
      MenuItem(
        id: 'm-17',
        name: 'Fresh Lime Soda (Sweet/Salt)',
        category: 'Beverages',
        pricePaise: 8000, // ₹ 80
        isVeg: true,
        description: 'Refreshing chilled soda with freshly squeezed lime juice.',
        imageUrl: 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?auto=format&fit=crop&w=600&q=80',
      ),

      // Desserts
      MenuItem(
        id: 'm-18',
        name: 'Gulab Jamun with Rabri',
        category: 'Desserts',
        pricePaise: 15000, // ₹ 150
        isVeg: true,
        description: 'Warm fried milk dumplings served with chilled condensed milk rabri.',
        imageUrl: 'https://images.unsplash.com/photo-1541832676-9b763b0239ab?auto=format&fit=crop&w=600&q=80',
      ),
      MenuItem(
        id: 'm-24',
        name: 'Royal Matka Kesar Kulfi',
        category: 'Desserts',
        pricePaise: 13000,
        isVeg: true,
        description: 'Traditional slow-reduced milk kulfi infused with saffron and crunchy pistachios.',
        imageUrl: 'https://images.unsplash.com/photo-1505394033641-40c6ad1178d7?auto=format&fit=crop&w=600&q=80',
      ),
      MenuItem(
        id: 'm-25',
        name: 'Elaneer Payasam (Tender Coconut)',
        category: 'Desserts',
        pricePaise: 16000,
        isVeg: true,
        description: 'South Indian coastal specialty dessert made with fresh tender coconut pulp and condensed milk.',
        imageUrl: 'https://images.unsplash.com/photo-1579954115545-a95591f28bfc?auto=format&fit=crop&w=600&q=80',
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
