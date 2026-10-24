import fs from 'fs';
import path from 'path';

// In-memory operational store matching PostgreSQL schema for instant local testing and fallback

export interface DeviceRecord {
  id: string;
  deviceName: string;
  role: 'captain' | 'counter' | 'admin';
  deviceFingerprint: string;
  apiKeyHash: string;
  isActive: boolean;
  status?: 'pending' | 'approved' | 'rejected';
  deviceIp?: string;
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
  imageUrl?: string;
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
    this.loadFromDisk();
  }

  public getStoreFilePath(): string {
    const candidateDirs = [
      path.resolve(process.cwd(), 'data'),
      path.resolve(process.cwd(), '../../data'),
      process.cwd(),
    ];
    for (const dir of candidateDirs) {
      try {
        if (!fs.existsSync(dir)) {
          fs.mkdirSync(dir, { recursive: true });
        }
        return path.join(dir, 'pos_store.json');
      } catch (_) {}
    }
    return path.resolve(process.cwd(), 'pos_store.json');
  }

  public saveToDisk(): void {
    try {
      const filePath = this.getStoreFilePath();
      const tmpPath = filePath + '.tmp';
      const bakPath = filePath + '.bak';

      const payload = {
        tables: Array.from(this.tables.values()),
        categories: Array.from(this.categories.values()),
        menuItems: Array.from(this.menuItems.values()),
        orders: Array.from(this.orders.values()),
        bills: Array.from(this.bills.values()),
        payments: Array.from(this.payments.values()),
        kots: Array.from(this.kots.values()),
        devices: Array.from(this.devices.values()),
        settings: Object.fromEntries(this.settings.entries()),
        updatedAt: new Date().toISOString(),
      };

      // 1. Atomic write to temporary file
      fs.writeFileSync(tmpPath, JSON.stringify(payload, null, 2), 'utf-8');

      // 2. Rotate existing file to .bak for power-outage protection
      if (fs.existsSync(filePath)) {
        try {
          fs.copyFileSync(filePath, bakPath);
        } catch (_) {}
      }

      // 3. Rename tmp to real file (atomic in Windows filesystem)
      fs.renameSync(tmpPath, filePath);
    } catch (err) {
      console.error('Failed to save inMemoryStore to disk:', err);
    }
  }

  public loadFromDisk(): boolean {
    const filePath = this.getStoreFilePath();
    const bakPath = filePath + '.bak';

    let targetPath: string | null = null;
    if (fs.existsSync(filePath)) {
      targetPath = filePath;
    } else if (fs.existsSync(bakPath)) {
      console.warn('Primary store file missing; recovering from power-failure backup (.bak)');
      targetPath = bakPath;
    }

    if (!targetPath) return false;

    try {
      const content = fs.readFileSync(targetPath, 'utf-8');
      const data = JSON.parse(content);
      if (Array.isArray(data.devices)) {
        for (const d of data.devices) {
          this.devices.set(d.id, d);
        }
      }
      if (Array.isArray(data.tables)) {
        this.tables.clear();
        for (const t of data.tables) {
          this.tables.set(t.id, t);
        }
      }
      if (Array.isArray(data.categories)) {
        this.categories.clear();
        for (const c of data.categories) {
          this.categories.set(c.id, c);
        }
      }
      if (Array.isArray(data.menuItems)) {
        this.menuItems.clear();
        for (const m of data.menuItems) {
          this.menuItems.set(m.id, m);
        }
      }
      if (Array.isArray(data.orders)) {
        this.orders.clear();
        for (const o of data.orders) {
          this.orders.set(o.id, o);
        }
      }
      if (Array.isArray(data.bills)) {
        this.bills.clear();
        for (const b of data.bills) {
          this.bills.set(b.id, b);
        }
      }
      if (Array.isArray(data.payments)) {
        this.payments.clear();
        for (const p of data.payments) {
          this.payments.set(p.id, p);
        }
      }
      if (Array.isArray(data.kots)) {
        this.kots.clear();
        for (const k of data.kots) {
          this.kots.set(k.id, k);
        }
      }
      if (data.settings && typeof data.settings === 'object') {
        for (const [k, v] of Object.entries(data.settings)) {
          this.settings.set(k, v as Record<string, unknown>);
        }
      }
      return true;
    } catch (err) {
      console.error('Failed to parse primary store file. Attempting recovery from .bak:', err);
      if (targetPath !== bakPath && fs.existsSync(bakPath)) {
        try {
          const bakContent = fs.readFileSync(bakPath, 'utf-8');
          const data = JSON.parse(bakContent);
          // Auto recover
          if (Array.isArray(data.devices)) {
        for (const d of data.devices) {
          this.devices.set(d.id, d);
        }
      }
      if (Array.isArray(data.tables)) {
            this.tables.clear();
            for (const t of data.tables) this.tables.set(t.id, t);
          }
          if (Array.isArray(data.menuItems)) {
            this.menuItems.clear();
            for (const m of data.menuItems) this.menuItems.set(m.id, m);
          }
          this.saveToDisk();
          console.info('Database successfully recovered from .bak backup snapshot!');
          return true;
        } catch (_) {}
      }
      return false;
    }
  }

  public exportBackupData(): Record<string, unknown> {
    return {
      version: '1.0.0',
      system: 'HinoptRestaurantPOS',
      exportedAt: new Date().toISOString(),
      restaurantName: (this.settings.get('restaurant_profile') as any)?.name || 'Curry Leaf Restro',
      tables: Array.from(this.tables.values()),
      categories: Array.from(this.categories.values()),
      menuItems: Array.from(this.menuItems.values()),
      orders: Array.from(this.orders.values()),
      bills: Array.from(this.bills.values()),
      payments: Array.from(this.payments.values()),
      kots: Array.from(this.kots.values()),
      settings: Object.fromEntries(this.settings.entries()),
    };
  }

  public restoreBackupData(data: any): {
    tablesCount: number;
    menuCount: number;
    ordersCount: number;
    billsCount: number;
  } {
    if (!data || typeof data !== 'object') {
      throw new Error('Invalid backup data format: Root object required.');
    }

    if (Array.isArray(data.tables)) {
      this.tables.clear();
      for (const t of data.tables) {
        this.tables.set(t.id, t);
      }
    }

    if (Array.isArray(data.categories)) {
      this.categories.clear();
      for (const c of data.categories) {
        this.categories.set(c.id, c);
      }
    }

    if (Array.isArray(data.menuItems)) {
      this.menuItems.clear();
      for (const m of data.menuItems) {
        this.menuItems.set(m.id, m);
      }
    }

    if (Array.isArray(data.orders)) {
      this.orders.clear();
      for (const o of data.orders) {
        this.orders.set(o.id, o);
      }
    }

    if (Array.isArray(data.bills)) {
      this.bills.clear();
      for (const b of data.bills) {
        this.bills.set(b.id, b);
      }
    }

    if (Array.isArray(data.payments)) {
      this.payments.clear();
      for (const p of data.payments) {
        this.payments.set(p.id, p);
      }
    }

    if (Array.isArray(data.kots)) {
      this.kots.clear();
      for (const k of data.kots) {
        this.kots.set(k.id, k);
      }
    }

    if (data.settings && typeof data.settings === 'object') {
      for (const [k, v] of Object.entries(data.settings)) {
        this.settings.set(k, v as Record<string, unknown>);
      }
    }

    this.saveToDisk();

    return {
      tablesCount: this.tables.size,
      menuCount: this.menuItems.size,
      ordersCount: this.orders.size,
      billsCount: this.bills.size,
    };
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

    // 5. Menu Items (All in integer paise with high-quality photos)
    const items: MenuItemRecord[] = [
      // Starters & Quick Bites
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
        imageUrl: 'https://images.unsplash.com/photo-1567184109-775c97b8782a?auto=format&fit=crop&w=600&q=80',
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
        imageUrl: 'https://images.unsplash.com/photo-1626777552726-4a6b54c97e46?auto=format&fit=crop&w=600&q=80',
        variants: [
          { id: 'half', name: 'Half', pricePaise: 20000 },
          { id: 'full', name: 'Full', pricePaise: 34000 },
        ],
        addOns: [],
        sortOrder: 2,
      },
      {
        id: 'item_crispy_corn',
        categoryId: 'cat_starters',
        name: 'Crispy Corn & Waterchestnut',
        shortCode: 'CCW',
        description: 'Golden fried sweet corn tossed with bell peppers and crushed black pepper',
        pricePaise: 24000,
        taxRatePercent: 5.0,
        isAvailable: true,
        isVeg: true,
        imageUrl: 'https://images.unsplash.com/photo-1551782450-a2132b4ba21d?auto=format&fit=crop&w=600&q=80',
        variants: [],
        addOns: [],
        sortOrder: 3,
      },
      {
        id: 'item_guntur_chicken',
        categoryId: 'cat_starters',
        name: 'Guntur Chilli Chicken Fry',
        shortCode: 'GCC',
        description: 'Andhra-style spiced boneless chicken tossed with fiery green chillies and curry leaves',
        pricePaise: 32000,
        taxRatePercent: 5.0,
        isAvailable: true,
        isVeg: false,
        imageUrl: 'https://images.unsplash.com/photo-1562967914-608f82629710?auto=format&fit=crop&w=600&q=80',
        variants: [],
        addOns: [],
        sortOrder: 4,
      },
      {
        id: 'item_mutton_seekh',
        categoryId: 'cat_starters',
        name: 'Mutton Seekh Kebab',
        shortCode: 'MSK',
        description: 'Finely minced spiced mutton skewered and roasted in traditional tandoor',
        pricePaise: 42000,
        taxRatePercent: 5.0,
        isAvailable: true,
        isVeg: false,
        imageUrl: 'https://images.unsplash.com/photo-1599488615731-7e5c2823ff28?auto=format&fit=crop&w=600&q=80',
        variants: [],
        addOns: [{ id: 'mint_chutney', name: 'Extra Mint Chutney', pricePaise: 2000 }],
        sortOrder: 5,
      },

      // Tandoori & Grills
      {
        id: 'item_paneer_tikka',
        categoryId: 'cat_tandoor',
        name: 'Paneer Tikka Angara',
        shortCode: 'PTA',
        description: 'Charcoal grilled cottage cheese marinated in fiery spices and creamy yogurt',
        pricePaise: 28000,
        taxRatePercent: 5.0,
        isAvailable: true,
        isVeg: true,
        imageUrl: 'https://images.unsplash.com/photo-1599488615731-7e5c2823ff28?auto=format&fit=crop&w=600&q=80',
        variants: [
          { id: 'mild', name: 'Mild', pricePaise: 28000 },
          { id: 'spicy', name: 'Extra Spicy', pricePaise: 28000 },
        ],
        addOns: [{ id: 'onion_salad', name: 'Lachha Onion Salad', pricePaise: 2500 }],
        sortOrder: 6,
      },
      {
        id: 'item_tandoori_murgh',
        categoryId: 'cat_tandoor',
        name: 'Tandoori Murgh (Clay Oven)',
        shortCode: 'TM',
        description: 'Classic whole spring chicken marinated in Kashmiri chilli yogurt and whole spices',
        pricePaise: 38000,
        taxRatePercent: 5.0,
        isAvailable: true,
        isVeg: false,
        imageUrl: 'https://images.unsplash.com/photo-1610057099443-fde8c4d50f91?auto=format&fit=crop&w=600&q=80',
        variants: [
          { id: 'half', name: 'Half (4 pcs)', pricePaise: 22000 },
          { id: 'full', name: 'Full (8 pcs)', pricePaise: 38000 },
        ],
        addOns: [],
        sortOrder: 7,
      },
      {
        id: 'item_malai_broccoli',
        categoryId: 'cat_tandoor',
        name: 'Tandoori Malai Broccoli',
        shortCode: 'TMB',
        description: 'Fresh broccoli florets steeped in cheese, cardamom cream, and chargrilled',
        pricePaise: 29000,
        taxRatePercent: 5.0,
        isAvailable: true,
        isVeg: true,
        imageUrl: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=600&q=80',
        variants: [],
        addOns: [],
        sortOrder: 8,
      },

      // Main Course Curries
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
        imageUrl: 'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?auto=format&fit=crop&w=600&q=80',
        variants: [],
        addOns: [{ id: 'extra_butter', name: 'Extra Butter Dollop', pricePaise: 2500 }],
        sortOrder: 9,
      },
      {
        id: 'item_butter_chicken',
        categoryId: 'cat_mains',
        name: 'Butter Chicken Grand Trunk',
        shortCode: 'BCGT',
        description: 'Clay oven cooked chicken in velvety tomato-butter gravy with crushed fenugreek',
        pricePaise: 39000,
        taxRatePercent: 5.0,
        isAvailable: true,
        isVeg: false,
        imageUrl: 'https://images.unsplash.com/photo-1588166524941-3bf61a9c41db?auto=format&fit=crop&w=600&q=80',
        variants: [
          { id: 'sweet_mild', name: 'Sweet & Mild', pricePaise: 39000 },
          { id: 'spicy', name: 'Spicy Authentic', pricePaise: 39000 },
        ],
        addOns: [],
        sortOrder: 10,
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
        imageUrl: 'https://images.unsplash.com/photo-1603894584373-5ac82b2ae398?auto=format&fit=crop&w=600&q=80',
        variants: [
          { id: 'half', name: 'Half', pricePaise: 21000 },
          { id: 'full', name: 'Full', pricePaise: 35000 },
        ],
        addOns: [],
        sortOrder: 11,
      },
      {
        id: 'item_dal_makhani',
        categoryId: 'cat_mains',
        name: 'Dal Makhani Heritage',
        shortCode: 'DMH',
        description: 'Whole black lentils simmered overnight with butter, cream, and gentle spices',
        pricePaise: 26000,
        taxRatePercent: 5.0,
        isAvailable: true,
        isVeg: true,
        imageUrl: 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?auto=format&fit=crop&w=600&q=80',
        variants: [],
        addOns: [{ id: 'extra_cream', name: 'Fresh Cream Swirl', pricePaise: 2000 }],
        sortOrder: 12,
      },
      {
        id: 'item_mutton_rogan_josh',
        categoryId: 'cat_mains',
        name: 'Kashmiri Mutton Rogan Josh',
        shortCode: 'MRJ',
        description: 'Tender braised mutton chunks cooked with Kashmiri chillies and aromatic herbs',
        pricePaise: 46000,
        taxRatePercent: 5.0,
        isAvailable: true,
        isVeg: false,
        imageUrl: 'https://images.unsplash.com/photo-1545247181-516773cae7be?auto=format&fit=crop&w=600&q=80',
        variants: [],
        addOns: [],
        sortOrder: 13,
      },

      // Biryani & Rice
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
        imageUrl: 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?auto=format&fit=crop&w=600&q=80',
        variants: [
          { id: 'single', name: 'Single Portion', pricePaise: 22000 },
          { id: 'regular', name: 'Regular Portion', pricePaise: 32000 },
        ],
        addOns: [{ id: 'boiled_egg', name: 'Extra Boiled Egg', pricePaise: 2500 }],
        sortOrder: 14,
      },
      {
        id: 'item_mutton_biryani',
        categoryId: 'cat_biryani',
        name: 'Dum Pukht Mutton Biryani',
        shortCode: 'MBY',
        description: 'Slow-cooked succulent mutton shank layered with fragrant basmati and saffron',
        pricePaise: 46000,
        taxRatePercent: 5.0,
        isAvailable: true,
        isVeg: false,
        imageUrl: 'https://images.unsplash.com/photo-1589302168068-964664d93dc0?auto=format&fit=crop&w=600&q=80',
        variants: [],
        addOns: [{ id: 'extra_salan', name: 'Extra Mirchi Ka Salan', pricePaise: 3000 }],
        sortOrder: 15,
      },
      {
        id: 'item_subz_biryani',
        categoryId: 'cat_biryani',
        name: 'Subz Nizami Dum Biryani',
        shortCode: 'SNBY',
        description: 'Garden fresh seasonal vegetables and cottage cheese cooked in aromatic saffron dum',
        pricePaise: 27000,
        taxRatePercent: 5.0,
        isAvailable: true,
        isVeg: true,
        imageUrl: 'https://images.unsplash.com/photo-1642821373181-696a54913e93?auto=format&fit=crop&w=600&q=80',
        variants: [],
        addOns: [{ id: 'burani_raita', name: 'Garlic Burani Raita', pricePaise: 3500 }],
        sortOrder: 16,
      },
      {
        id: 'item_jeera_rice_dal',
        categoryId: 'cat_biryani',
        name: 'Jeera Rice & Yellow Dal Tadka',
        shortCode: 'JRDT',
        description: 'Fragrant cumin-tempered basmati rice served with garlic-tempered yellow lentils',
        pricePaise: 21000,
        taxRatePercent: 5.0,
        isAvailable: true,
        isVeg: true,
        imageUrl: 'https://images.unsplash.com/photo-1512058564366-18510be2db19?auto=format&fit=crop&w=600&q=80',
        variants: [],
        addOns: [],
        sortOrder: 17,
      },

      // Breads & Accompaniments
      {
        id: 'item_butter_naan',
        categoryId: 'cat_breads',
        name: 'Butter Garlic Naan',
        shortCode: 'BGN',
        description: 'Tandoor leavened flatbread brushed with aromatic garlic butter and herbs',
        pricePaise: 7000,
        taxRatePercent: 5.0,
        isAvailable: true,
        isVeg: true,
        imageUrl: 'https://images.unsplash.com/photo-1601050690597-df0568f70950?auto=format&fit=crop&w=600&q=80',
        variants: [],
        addOns: [],
        sortOrder: 18,
      },
      {
        id: 'item_tandoori_roti',
        categoryId: 'cat_breads',
        name: 'Tandoori Butter Roti',
        shortCode: 'TBR',
        description: 'Traditional whole wheat flatbread baked in clay oven and topped with fresh butter',
        pricePaise: 3500,
        taxRatePercent: 5.0,
        isAvailable: true,
        isVeg: true,
        imageUrl: 'https://images.unsplash.com/photo-1626777552726-4a6b54c97e46?auto=format&fit=crop&w=600&q=80',
        variants: [],
        addOns: [],
        sortOrder: 19,
      },
      {
        id: 'item_cheese_naan',
        categoryId: 'cat_breads',
        name: 'Cheese Chilli Garlic Naan',
        shortCode: 'CCN',
        description: 'Artisan naan stuffed with melted mozzarella cheese and chopped green chillies',
        pricePaise: 11000,
        taxRatePercent: 5.0,
        isAvailable: true,
        isVeg: true,
        imageUrl: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=600&q=80',
        variants: [],
        addOns: [],
        sortOrder: 20,
      },

      // Beverages & Coolers
      {
        id: 'item_mango_lassi',
        categoryId: 'cat_beverages',
        name: 'Royal Kesaria Mango Lassi',
        shortCode: 'RML',
        description: 'Thick churned sweet yogurt blended with Alphonso mango pulp and saffron',
        pricePaise: 12000,
        taxRatePercent: 5.0,
        isAvailable: true,
        isVeg: true,
        imageUrl: 'https://images.unsplash.com/photo-1553530666-ba11a7da3888?auto=format&fit=crop&w=600&q=80',
        variants: [],
        addOns: [],
        sortOrder: 21,
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
        imageUrl: 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?auto=format&fit=crop&w=600&q=80',
        variants: [],
        addOns: [],
        sortOrder: 22,
      },
      {
        id: 'item_lime_soda',
        categoryId: 'cat_beverages',
        name: 'Fresh Mint Lime Soda',
        shortCode: 'MLS',
        description: 'Sparkling soda with freshly squeezed lime, crushed mint leaves, and rock salt',
        pricePaise: 8000,
        taxRatePercent: 5.0,
        isAvailable: true,
        isVeg: true,
        imageUrl: 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?auto=format&fit=crop&w=600&q=80',
        variants: [
          { id: 'sweet', name: 'Sweet', pricePaise: 8000 },
          { id: 'salted', name: 'Salted', pricePaise: 8000 },
          { id: 'mixed', name: 'Sweet & Salt', pricePaise: 8000 },
        ],
        addOns: [],
        sortOrder: 23,
      },

      // Desserts
      {
        id: 'item_gulab_jamun',
        categoryId: 'cat_desserts',
        name: 'Gulab Jamun with Shahi Rabri',
        shortCode: 'GJR',
        description: 'Warm melt-in-mouth milk dumplings served over chilled thickened cardamom rabri',
        pricePaise: 15000,
        taxRatePercent: 5.0,
        isAvailable: true,
        isVeg: true,
        imageUrl: 'https://images.unsplash.com/photo-1541832676-9b763b0239ab?auto=format&fit=crop&w=600&q=80',
        variants: [],
        addOns: [],
        sortOrder: 24,
      },
      {
        id: 'item_matka_kulfi',
        categoryId: 'cat_desserts',
        name: 'Royal Matka Kesar Kulfi',
        shortCode: 'MKK',
        description: 'Traditional slow-reduced milk kulfi infused with saffron and crunchy pistachios',
        pricePaise: 13000,
        taxRatePercent: 5.0,
        isAvailable: true,
        isVeg: true,
        imageUrl: 'https://images.unsplash.com/photo-1505394033641-40c6ad1178d7?auto=format&fit=crop&w=600&q=80',
        variants: [],
        addOns: [],
        sortOrder: 25,
      },
      {
        id: 'item_elaneer_payasam',
        categoryId: 'cat_desserts',
        name: 'Elaneer Payasam (Tender Coconut)',
        shortCode: 'ENP',
        description: 'South Indian coastal specialty dessert made with fresh tender coconut pulp and condensed milk',
        pricePaise: 16000,
        taxRatePercent: 5.0,
        isAvailable: true,
        isVeg: true,
        imageUrl: 'https://images.unsplash.com/photo-1579954115545-a95591f28bfc?auto=format&fit=crop&w=600&q=80',
        variants: [],
        addOns: [],
        sortOrder: 26,
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
      discountPaise: 0,
      totalPaise: 43050,
      createdAt: new Date(Date.now() - 12 * 60 * 1000).toISOString(),
      updatedAt: new Date().toISOString(),
      items: [
        {
          id: 'item_rec_1',
          orderId: 'ord_live_101',
          menuItemId: 'item_chicken_ghee_roast',
          nameSnapshot: 'Kundapura Chicken Ghee Roast',
          pricePaiseSnapshot: 34000,
          taxRateSnapshot: 5.0,
          quantity: 1,
          selectedVariants: [],
          selectedAddons: [],
          status: 'preparing',
          createdAt: new Date(Date.now() - 12 * 60 * 1000).toISOString(),
          updatedAt: new Date().toISOString(),
        },
        {
          id: 'item_rec_2',
          orderId: 'ord_live_101',
          menuItemId: 'item_masala_chaas',
          nameSnapshot: 'Spiced Buttermilk (Neer Moru)',
          pricePaiseSnapshot: 6000,
          taxRateSnapshot: 5.0,
          quantity: 2,
          selectedVariants: [],
          selectedAddons: [],
          status: 'preparing',
          createdAt: new Date(Date.now() - 12 * 60 * 1000).toISOString(),
          updatedAt: new Date().toISOString(),
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
      discountPaise: 0,
      totalPaise: 126000,
      createdAt: new Date(Date.now() - 5 * 60 * 1000).toISOString(),
      updatedAt: new Date().toISOString(),
      items: [
        {
          id: 'item_rec_3',
          orderId: 'ord_live_102',
          menuItemId: 'item_chicken_biryani',
          nameSnapshot: 'Ambur Chicken Dum Biryani',
          pricePaiseSnapshot: 32000,
          taxRateSnapshot: 5.0,
          quantity: 2,
          selectedVariants: [],
          selectedAddons: [],
          status: 'preparing',
          createdAt: new Date(Date.now() - 5 * 60 * 1000).toISOString(),
          updatedAt: new Date().toISOString(),
        },
        {
          id: 'item_rec_4',
          orderId: 'ord_live_102',
          menuItemId: 'item_butter_naan',
          nameSnapshot: 'Butter Garlic Naan',
          pricePaiseSnapshot: 7000,
          taxRateSnapshot: 5.0,
          quantity: 4,
          selectedVariants: [],
          selectedAddons: [],
          status: 'preparing',
          createdAt: new Date(Date.now() - 5 * 60 * 1000).toISOString(),
          updatedAt: new Date().toISOString(),
        },
        {
          id: 'item_rec_5',
          orderId: 'ord_live_102',
          menuItemId: 'item_paneer_butter_masala',
          nameSnapshot: 'Paneer Butter Masala',
          pricePaiseSnapshot: 28000,
          taxRateSnapshot: 5.0,
          quantity: 1,
          selectedVariants: [],
          selectedAddons: [],
          status: 'preparing',
          createdAt: new Date(Date.now() - 5 * 60 * 1000).toISOString(),
          updatedAt: new Date().toISOString(),
        },
      ],
    };

    this.orders.set(order1.id, order1);
    this.orders.set(order2.id, order2);

    const t2 = this.tables.get('tab_t2');
    if (t2) {
      t2.status = 'occupied';
      t2.activeOrderId = order1.id;
    }
    const t4 = this.tables.get('tab_t4');
    if (t4) {
      t4.status = 'occupied';
      t4.activeOrderId = order2.id;
    }
  }
}

export const inMemoryStore = new InMemoryStore();
