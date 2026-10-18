// In-memory operational store matching PostgreSQL schema for instant local testing and fallback

export interface DeviceRecord {
  id: string;
  deviceName: string;
  role: 'captain' | 'counter' | 'admin';
  deviceFingerprint: string;
  apiKeyHash: string;
  isActive: boolean;
  lastSeenAt?: string;
  registeredAt: string;
}

export interface TableRecord {
  id: string;
  tableNumber: string;
  displayName: string;
  section: string;
  capacity: number;
  status: 'available' | 'occupied' | 'billed' | 'reserved' | 'maintenance';
  activeOrderId?: string | null;
  sortOrder: number;
}

export interface MenuCategoryRecord {
  id: string;
  name: string;
  description?: string;
  sortOrder: number;
  isActive: boolean;
}

export interface MenuItemRecord {
  id: string;
  categoryId: string;
  name: string;
  shortCode?: string;
  description?: string;
  pricePaise: number;
  taxRatePercent: number;
  isAvailable: boolean;
  isVeg: boolean;
  variants: Array<{ id: string; name: string; pricePaise: number }>;
  addOns: Array<{ id: string; name: string; pricePaise: number }>;
  sortOrder: number;
}

export interface OrderItemRecord {
  id: string;
  orderId: string;
  menuItemId: string;
  nameSnapshot: string;
  pricePaiseSnapshot: number;
  taxRateSnapshot: number;
  quantity: number;
  itemNotes?: string;
  selectedVariants: Array<{ id: string; name: string; pricePaise: number }>;
  selectedAddons: Array<{ id: string; name: string; pricePaise: number }>;
  status: 'draft' | 'sent_to_kitchen' | 'preparing' | 'served' | 'cancelled';
  kotId?: string | null;
  cancellationReason?: string;
  cancelledByDeviceId?: string;
  createdAt: string;
  updatedAt: string;
}

export interface OrderRecord {
  id: string;
  orderNumber: string;
  tableId: string;
  tableName?: string;
  captainDeviceId?: string;
  status: 'draft' | 'active' | 'preparing' | 'ready' | 'billed' | 'settled' | 'cancelled';
  customerNotes?: string;
  guestCount: number;
  subtotalPaise: number;
  taxPaise: number;
  discountPaise: number;
  totalPaise: number;
  items: OrderItemRecord[];
  createdAt: string;
  updatedAt: string;
}

export interface KotRecord {
  id: string;
  kotNumber: string;
  orderId: string;
  tableId: string;
  status: 'queued' | 'printing' | 'printed' | 'failed' | 'cancelled';
  printCount: number;
  items: OrderItemRecord[];
  printedAt?: string;
  cancellationReason?: string;
  createdAt: string;
}

export interface BillItemRecord {
  id: string;
  billId: string;
  menuItemId: string;
  nameSnapshot: string;
  unitPricePaise: number;
  quantity: number;
  totalPaise: number;
  taxPaise: number;
  optionsSnapshot: Record<string, unknown>;
  createdAt: string;
}

export interface BillRecord {
  id: string;
  billNumber: string;
  orderId: string;
  tableId: string;
  subtotalPaise: number;
  taxPaise: number;
  discountPaise: number;
  totalPaise: number;
  status: 'draft' | 'finalized' | 'settled' | 'voided';
  printStatus: 'pending' | 'printed' | 'failed';
  printCount: number;
  voidReason?: string;
  createdByDeviceId?: string;
  items: BillItemRecord[];
  finalizedAt?: string;
  settledAt?: string;
  createdAt: string;
}

export interface PaymentRecord {
  id: string;
  billId: string;
  amountPaise: number;
  paymentMethod: 'cash' | 'upi' | 'card' | 'split' | 'other';
  referenceNumber?: string;
  status: 'pending' | 'completed' | 'failed' | 'refunded';
  idempotencyKey: string;
  settledByDeviceId?: string;
  notes?: string;
  createdAt: string;
}

export interface PrintJobRecord {
  id: string;
  targetPrinter: 'counter_bill' | 'kitchen_kot';
  jobType: 'bill' | 'kot' | 'reprint_bill' | 'reprint_kot' | 'test_print' | 'report';
  referenceId?: string;
  payload: Record<string, unknown>;
  status: 'queued' | 'processing' | 'completed' | 'failed';
  retryCount: number;
  maxRetries: number;
  errorMessage?: string;
  isReprint: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface AuditLogRecord {
  id: string;
  eventType: string;
  entityType: string;
  entityId: string;
  actorDeviceId?: string;
  reason?: string;
  details: Record<string, unknown>;
  createdAt: string;
}

export interface LicenseRecord {
  id: string;
  restaurantId: string;
  restaurantName: string;
  licenseKey: string;
  status: 'active' | 'grace' | 'expired' | 'suspended';
  validFrom: string;
  validUntil: string;
  lastVerifiedAt: string;
  signature: string;
  signedPayload: Record<string, unknown>;
}

export class InMemoryStore {
  public devices: Map<string, DeviceRecord> = new Map();
  public tables: Map<string, TableRecord> = new Map();
  public categories: Map<string, MenuCategoryRecord> = new Map();
  public menuItems: Map<string, MenuItemRecord> = new Map();
  public orders: Map<string, OrderRecord> = new Map();
  public kots: Map<string, KotRecord> = new Map();
  public bills: Map<string, BillRecord> = new Map();
  public payments: Map<string, PaymentRecord> = new Map();
  public printJobs: Map<string, PrintJobRecord> = new Map();
  public auditLogs: AuditLogRecord[] = [];
  public settings: Map<string, Record<string, unknown>> = new Map();
  public license?: LicenseRecord;

  constructor() {
    this.seed();
  }

  public seed() {
    // 1. Settings
    this.settings.set('restaurant_profile', {
      restaurantId: 'rest_curry_leaf_01',
      name: 'Curry Leaf Fine Dining',
      tagline: 'Authentic Coastal & South Indian Cuisine',
      address: '123 Spice Garden Road, Indiranagar, Bengaluru, Karnataka 560038',
      phone: '+91 80 4123 4567',
      gstin: '29AABCU9603R1ZM',
      currency: 'INR',
    });

    // 2. Devices
    const dev1: DeviceRecord = {
      id: 'dev_counter_01',
      deviceName: 'Counter Main PC',
      role: 'counter',
      deviceFingerprint: 'fp_win_counter_01',
      apiKeyHash: 'counter_dev_token',
      isActive: true,
      registeredAt: new Date().toISOString(),
    };
    const dev2: DeviceRecord = {
      id: 'dev_captain_01',
      deviceName: 'Captain Tablet 1 - Ground Floor',
      role: 'captain',
      deviceFingerprint: 'fp_tab_android_01',
      apiKeyHash: 'captain_dev_token_01',
      isActive: true,
      registeredAt: new Date().toISOString(),
    };
    const dev3: DeviceRecord = {
      id: 'dev_admin_01',
      deviceName: 'Admin Manager Laptop',
      role: 'admin',
      deviceFingerprint: 'fp_admin_manager_01',
      apiKeyHash: 'admin_dev_token',
      isActive: true,
      registeredAt: new Date().toISOString(),
    };
    this.devices.set(dev1.id, dev1);
    this.devices.set(dev2.id, dev2);
    this.devices.set(dev3.id, dev3);

    // 3. Tables
    const initialTables: TableRecord[] = [
      { id: 'tab_t1', tableNumber: 'T1', displayName: 'Table 1', section: 'Main Dining', capacity: 4, status: 'available', sortOrder: 1 },
      { id: 'tab_t2', tableNumber: 'T2', displayName: 'Table 2', section: 'Main Dining', capacity: 2, status: 'available', sortOrder: 2 },
      { id: 'tab_t3', tableNumber: 'T3', displayName: 'Table 3', section: 'Main Dining', capacity: 4, status: 'available', sortOrder: 3 },
      { id: 'tab_t4', tableNumber: 'T4', displayName: 'Table 4', section: 'Main Dining', capacity: 6, status: 'available', sortOrder: 4 },
      { id: 'tab_t5', tableNumber: 'T5', displayName: 'Table 5', section: 'Main Dining', capacity: 8, status: 'available', sortOrder: 5 },
      { id: 'tab_p1', tableNumber: 'P1', displayName: 'Patio 1', section: 'Outdoor Patio', capacity: 2, status: 'available', sortOrder: 6 },
      { id: 'tab_p2', tableNumber: 'P2', displayName: 'Patio 2', section: 'Outdoor Patio', capacity: 4, status: 'available', sortOrder: 7 },
      { id: 'tab_ac1', tableNumber: 'AC1', displayName: 'VIP AC 1', section: 'AC Family Section', capacity: 6, status: 'available', sortOrder: 8 },
    ];
    for (const t of initialTables) {
      this.tables.set(t.id, t);
    }

    // 4. Categories
    const initialCategories: MenuCategoryRecord[] = [
      { id: 'cat_starters', name: 'Starters & Quick Bites', sortOrder: 1, isActive: true },
      { id: 'cat_tandoor', name: 'Tandoori & Grills', sortOrder: 2, isActive: true },
      { id: 'cat_mains', name: 'Main Course Curries', sortOrder: 3, isActive: true },
      { id: 'cat_biryani', name: 'Biryani & Rice', sortOrder: 4, isActive: true },
      { id: 'cat_breads', name: 'Breads & Accompaniments', sortOrder: 5, isActive: true },
      { id: 'cat_beverages', name: 'Beverages & Coolers', sortOrder: 6, isActive: true },
      { id: 'cat_desserts', name: 'Desserts', sortOrder: 7, isActive: true },
    ];
    for (const c of initialCategories) {
      this.categories.set(c.id, c);
    }

    // 5. Menu Items (All in integer paise)
    const items: MenuItemRecord[] = [
      {
        id: 'item_paneer_65',
        categoryId: 'cat_starters',
        name: 'Curry Leaf Paneer 65',
        shortCode: 'P65',
        description: 'Crisp cottage cheese cubes tossed in spicy tempering with fresh curry leaves',
        pricePaise: 24000,
        taxRatePercent: 5.0,
        isAvailable: true,
        isVeg: true,
        variants: [
          { id: 'half', name: 'Half', pricePaise: 14000 },
          { id: 'full', name: 'Full', pricePaise: 24000 },
        ],
        addOns: [{ id: 'extra_chilli_dip', name: 'Extra Chilli Dip', pricePaise: 3000 }],
        sortOrder: 1,
      },
      {
        id: 'item_chicken_ghee_roast',
        categoryId: 'cat_starters',
        name: 'Kundapura Chicken Ghee Roast',
        shortCode: 'CGR',
        description: 'Tender chicken braised in clarified butter and fiery Byadgi red chilli paste',
        pricePaise: 34000,
        taxRatePercent: 5.0,
        isAvailable: true,
        isVeg: false,
        variants: [
          { id: 'half', name: 'Half', pricePaise: 20000 },
          { id: 'full', name: 'Full', pricePaise: 34000 },
        ],
        addOns: [],
        sortOrder: 2,
      },
      {
        id: 'item_paneer_butter_masala',
        categoryId: 'cat_mains',
        name: 'Paneer Butter Masala',
        shortCode: 'PBM',
        description: 'Fresh paneer cubes simmered in velvety tomato cream gravy',
        pricePaise: 28000,
        taxRatePercent: 5.0,
        isAvailable: true,
        isVeg: true,
        variants: [],
        addOns: [{ id: 'extra_butter', name: 'Extra Butter Dollop', pricePaise: 2500 }],
        sortOrder: 3,
      },
      {
        id: 'item_chicken_curry',
        categoryId: 'cat_mains',
        name: 'Curry Leaf Country Chicken Curry',
        shortCode: 'CCC',
        description: 'Homestyle chicken simmered with ground spices, shallots, and fresh curry leaves',
        pricePaise: 35000,
        taxRatePercent: 5.0,
        isAvailable: true,
        isVeg: false,
        variants: [
          { id: 'half', name: 'Half', pricePaise: 21000 },
          { id: 'full', name: 'Full', pricePaise: 35000 },
        ],
        addOns: [],
        sortOrder: 4,
      },
      {
        id: 'item_chicken_biryani',
        categoryId: 'cat_biryani',
        name: 'Ambur Chicken Dum Biryani',
        shortCode: 'ACBY',
        description: 'Short-grain seeraga samba rice cooked with tender chicken and whole spices',
        pricePaise: 32000,
        taxRatePercent: 5.0,
        isAvailable: true,
        isVeg: false,
        variants: [
          { id: 'single', name: 'Single Portion', pricePaise: 22000 },
          { id: 'regular', name: 'Regular Portion', pricePaise: 32000 },
        ],
        addOns: [{ id: 'boiled_egg', name: 'Extra Boiled Egg', pricePaise: 2500 }],
        sortOrder: 5,
      },
      {
        id: 'item_butter_naan',
        categoryId: 'cat_breads',
        name: 'Butter Garlic Naan',
        shortCode: 'BGN',
        description: 'Tandoor leavened flatbread brushed with garlic butter',
        pricePaise: 7000,
        taxRatePercent: 5.0,
        isAvailable: true,
        isVeg: true,
        variants: [],
        addOns: [],
        sortOrder: 6,
      },
      {
        id: 'item_masala_chaas',
        categoryId: 'cat_beverages',
        name: 'Spiced Buttermilk (Neer Moru)',
        shortCode: 'NMR',
        description: 'Refreshing churned yogurt tempered with ginger, green chilli, and curry leaves',
        pricePaise: 6000,
        taxRatePercent: 5.0,
        isAvailable: true,
        isVeg: true,
        variants: [],
        addOns: [],
        sortOrder: 7,
      },
    ];
    for (const item of items) {
      this.menuItems.set(item.id, item);
    }

    // 6. Default active license cache
    this.license = {
      id: 'current_license',
      restaurantId: 'rest_curry_leaf_01',
      restaurantName: 'Curry Leaf Fine Dining',
      licenseKey: 'HINOPT-LIC-CL-2026-ACTIVE',
      status: 'active',
      validFrom: new Date(Date.now() - 30 * 24 * 3600 * 1000).toISOString(),
      validUntil: new Date(Date.now() + 335 * 24 * 3600 * 1000).toISOString(),
      lastVerifiedAt: new Date().toISOString(),
      signature: 'simulated_initial_seed_signature',
      signedPayload: {
        restaurantId: 'rest_curry_leaf_01',
        features: ['pos', 'kot', 'billing', 'reports'],
      },
    };

    // 7. Seed active live orders for real-time counter & captain processing
    const order1: OrderRecord = {
      id: 'ord_live_101',
      orderNumber: 'ORD-101',
      tableId: 'tab_t2',
      tableName: 'Table 2',
      guestCount: 2,
      status: 'preparing',
      subtotalPaise: 41000,
      taxPaise: 2050,
      totalPaise: 43050,
      version: 1,
      createdAt: new Date(Date.now() - 12 * 60 * 1000).toISOString(),
      updatedAt: new Date().toISOString(),
      items: [
        {
          id: 'item_rec_1',
          orderId: 'ord_live_101',
          menuItemId: 'item_chicken_65',
          nameSnapshot: 'Chicken 65 (Curry Leaf Special)',
          unitPricePaise: 29000,
          quantity: 1,
          totalPaise: 29000,
          taxPaise: 1450,
          status: 'preparing',
          kotPrinted: true,
          createdAt: new Date().toISOString(),
        },
        {
          id: 'item_rec_2',
          orderId: 'ord_live_101',
          menuItemId: 'item_masala_chaas',
          nameSnapshot: 'Spiced Buttermilk (Neer Moru)',
          unitPricePaise: 6000,
          quantity: 2,
          totalPaise: 12000,
          taxPaise: 600,
          status: 'ready',
          kotPrinted: true,
          createdAt: new Date().toISOString(),
        },
      ],
    };

    const order2: OrderRecord = {
      id: 'ord_live_102',
      orderNumber: 'ORD-102',
      tableId: 'tab_t4',
      tableName: 'Table 4',
      guestCount: 4,
      status: 'active',
      subtotalPaise: 120000,
      taxPaise: 6000,
      totalPaise: 126000,
      version: 1,
      createdAt: new Date(Date.now() - 5 * 60 * 1000).toISOString(),
      updatedAt: new Date().toISOString(),
      items: [
        {
          id: 'item_rec_3',
          orderId: 'ord_live_102',
          menuItemId: 'item_chicken_biryani',
          nameSnapshot: 'Ambur Chicken Dum Biryani',
          unitPricePaise: 32000,
          quantity: 2,
          totalPaise: 64000,
          taxPaise: 3200,
          status: 'preparing',
          kotPrinted: true,
          createdAt: new Date().toISOString(),
        },
        {
          id: 'item_rec_4',
          orderId: 'ord_live_102',
          menuItemId: 'item_butter_naan',
          nameSnapshot: 'Butter Garlic Naan',
          unitPricePaise: 7000,
          quantity: 4,
          totalPaise: 28000,
          taxPaise: 1400,
          status: 'preparing',
          kotPrinted: true,
          createdAt: new Date().toISOString(),
        },
        {
          id: 'item_rec_5',
          orderId: 'ord_live_102',
          menuItemId: 'item_paneer_butter_masala',
          nameSnapshot: 'Paneer Butter Masala',
          unitPricePaise: 28000,
          quantity: 1,
          totalPaise: 28000,
          taxPaise: 1400,
          status: 'pending',
          kotPrinted: true,
          createdAt: new Date().toISOString(),
        },
      ],
    };

    this.orders.set(order1.id, order1);
    this.orders.set(order2.id, order2);

    const t2 = this.tables.get('tab_t2');
    if (t2) {
      t2.status = 'occupied';
    }
    const t4 = this.tables.get('tab_t4');
    if (t4) {
      t4.status = 'occupied';
    }
  }
}

export const inMemoryStore = new InMemoryStore();
