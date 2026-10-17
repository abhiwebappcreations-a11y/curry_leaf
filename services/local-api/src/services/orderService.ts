import { inMemoryStore, OrderRecord, OrderItemRecord } from '../db/inMemoryStore.js';
import { NotFoundError, BadRequestError, ConflictError } from '../utils/errors.js';
import { calculateTaxPaise } from '../utils/money.js';

let orderCounter = 1000;

export interface CreateOrderItemInput {
  menuItemId: string;
  quantity: number;
  itemNotes?: string;
  selectedVariants?: Array<{ id: string; name: string; pricePaise: number }>;
  selectedAddons?: Array<{ id: string; name: string; pricePaise: number }>;
}

export interface CreateOrderInput {
  tableId: string;
  customerNotes?: string;
  guestCount?: number;
  items?: CreateOrderItemInput[];
}

export class OrderService {
  public static generateOrderNumber(): string {
    const today = new Date().toISOString().slice(2, 10).replace(/-/g, '');
    orderCounter += 1;
    return `ORD-${today}-${orderCounter}`;
  }

  public static async createOrder(input: CreateOrderInput, deviceId?: string): Promise<OrderRecord> {
    const table = inMemoryStore.tables.get(input.tableId);
    if (!table) {
      throw new NotFoundError('Table', input.tableId);
    }

    // Check if table already has an active open order
    if (table.activeOrderId) {
      const existing = inMemoryStore.orders.get(table.activeOrderId);
      if (existing && !['settled', 'cancelled'].includes(existing.status)) {
        throw new ConflictError(
          'TABLE_ALREADY_OCCUPIED',
          `Table ${table.tableNumber} already has active order ${existing.orderNumber}`,
          { activeOrderId: existing.id }
        );
      }
    }

    const orderId = `ord_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const now = new Date().toISOString();

    const order: OrderRecord = {
      id: orderId,
      orderNumber: this.generateOrderNumber(),
      tableId: table.id,
      captainDeviceId: deviceId,
      status: 'active',
      customerNotes: input.customerNotes,
      guestCount: input.guestCount || 1,
      subtotalPaise: 0,
      taxPaise: 0,
      discountPaise: 0,
      totalPaise: 0,
      items: [],
      createdAt: now,
      updatedAt: now,
    };

    if (input.items && input.items.length > 0) {
      for (const itemInput of input.items) {
        this.appendItemToOrder(order, itemInput);
      }
    }

    this.recalculateOrderTotals(order);

    inMemoryStore.orders.set(order.id, order);
    table.activeOrderId = order.id;
    table.status = 'occupied';

    return order;
  }

  public static async getOrderById(orderId: string): Promise<OrderRecord> {
    const order = inMemoryStore.orders.get(orderId);
    if (!order) {
      throw new NotFoundError('Order', orderId);
    }
    return order;
  }

  public static async listOrders(status?: string, tableId?: string): Promise<OrderRecord[]> {
    let list = Array.from(inMemoryStore.orders.values());
    if (status) {
      list = list.filter((o) => o.status === status);
    }
    if (tableId) {
      list = list.filter((o) => o.tableId === tableId);
    }
    return list.sort(
      (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
    );
  }

  public static async addItemsToOrder(
    orderId: string,
    items: CreateOrderItemInput[]
  ): Promise<OrderRecord> {
    const order = await this.getOrderById(orderId);

    if (['billed', 'settled', 'cancelled'].includes(order.status)) {
      throw new BadRequestError(`Cannot add items to order in '${order.status}' status`);
    }

    for (const itemInput of items) {
      this.appendItemToOrder(order, itemInput);
    }

    this.recalculateOrderTotals(order);
    order.updatedAt = new Date().toISOString();

    return order;
  }

  public static async updateDraftItem(
    orderId: string,
    itemId: string,
    quantity: number,
    itemNotes?: string
  ): Promise<OrderRecord> {
    const order = await this.getOrderById(orderId);
    const item = order.items.find((i) => i.id === itemId);

    if (!item) {
      throw new NotFoundError('Order Item', itemId);
    }

    if (item.status !== 'draft') {
      throw new BadRequestError(
        'Only draft items can be modified directly. For sent items, use the cancellation workflow.'
      );
    }

    if (quantity <= 0) {
      // Remove unsent draft item
      order.items = order.items.filter((i) => i.id !== itemId);
    } else {
      item.quantity = quantity;
      if (itemNotes !== undefined) {
        item.itemNotes = itemNotes;
      }
      item.updatedAt = new Date().toISOString();
    }

    this.recalculateOrderTotals(order);
    order.updatedAt = new Date().toISOString();
    return order;
  }

  private static appendItemToOrder(order: OrderRecord, input: CreateOrderItemInput) {
    const menuItem = inMemoryStore.menuItems.get(input.menuItemId);
    if (!menuItem) {
      throw new NotFoundError('Menu Item', input.menuItemId);
    }
    if (!menuItem.isAvailable) {
      throw new BadRequestError(`Menu item '${menuItem.name}' is currently unavailable`);
    }

    let unitPrice = menuItem.pricePaise;

    // Check selected variant
    if (input.selectedVariants && input.selectedVariants.length > 0) {
      const selected = input.selectedVariants[0];
      const match = menuItem.variants.find((v) => v.id === selected.id);
      if (match) {
        unitPrice = match.pricePaise;
      }
    }

    // Add add-ons prices
    if (input.selectedAddons && input.selectedAddons.length > 0) {
      for (const addon of input.selectedAddons) {
        const match = menuItem.addOns.find((a) => a.id === addon.id);
        if (match) {
          unitPrice += match.pricePaise;
        }
      }
    }

    const orderItemId = `oi_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`;
    const now = new Date().toISOString();

    const orderItem: OrderItemRecord = {
      id: orderItemId,
      orderId: order.id,
      menuItemId: menuItem.id,
      nameSnapshot: menuItem.name,
      pricePaiseSnapshot: unitPrice,
      taxRateSnapshot: menuItem.taxRatePercent,
      quantity: input.quantity,
      itemNotes: input.itemNotes,
      selectedVariants: input.selectedVariants || [],
      selectedAddons: input.selectedAddons || [],
      status: 'draft',
      createdAt: now,
      updatedAt: now,
    };

    order.items.push(orderItem);
  }

  public static recalculateOrderTotals(order: OrderRecord) {
    let subtotal = 0;
    let tax = 0;

    for (const item of order.items) {
      if (item.status !== 'cancelled') {
        const itemTotal = item.pricePaiseSnapshot * item.quantity;
        subtotal += itemTotal;
        tax += calculateTaxPaise(itemTotal, item.taxRateSnapshot);
      }
    }

    order.subtotalPaise = subtotal;
    order.taxPaise = tax;
    order.totalPaise = Math.max(0, subtotal + tax - order.discountPaise);
  }
}
