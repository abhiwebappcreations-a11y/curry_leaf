import { inMemoryStore, KotRecord } from '../db/inMemoryStore.js';
import { NotFoundError, BadRequestError } from '../utils/errors.js';
import { OrderService } from './orderService.js';
import { PrintService } from './printService.js';

let kotCounter = 2000;

export class KotService {
  public static generateKotNumber(): string {
    const today = new Date().toISOString().slice(2, 10).replace(/-/g, '');
    kotCounter += 1;
    return `KOT-${today}-${kotCounter}`;
  }

  public static async sendToKitchen(orderId: string, deviceId?: string): Promise<KotRecord> {
    const order = await OrderService.getOrderById(orderId);
    const table = inMemoryStore.tables.get(order.tableId);

    if (['billed', 'settled', 'cancelled'].includes(order.status)) {
      throw new BadRequestError(`Cannot send KOT for order in '${order.status}' status`);
    }

    // Find all items currently in 'draft' status
    const draftItems = order.items.filter((item) => item.status === 'draft');
    if (draftItems.length === 0) {
      throw new BadRequestError('No new draft items found to send to kitchen');
    }

    const kotId = `kot_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const kotNumber = this.generateKotNumber();
    const now = new Date().toISOString();

    // Transition all draft items to 'sent_to_kitchen'
    for (const item of draftItems) {
      item.status = 'sent_to_kitchen';
      item.kotId = kotId;
      item.updatedAt = now;
    }

    const kot: KotRecord = {
      id: kotId,
      kotNumber,
      orderId: order.id,
      tableId: order.tableId,
      status: 'queued',
      printCount: 1,
      items: draftItems.map((i) => ({ ...i })),
      createdAt: now,
    };

    inMemoryStore.kots.set(kot.id, kot);

    // Update order status to preparing
    order.status = 'preparing';
    order.updatedAt = now;

    if (table) {
      table.status = 'occupied';
    }

    // Persist records before enqueuing print job
    await PrintService.enqueueJob(
      'kitchen_kot',
      'kot',
      kot.id,
      {
        kotNumber: kot.kotNumber,
        tableNumber: table ? table.tableNumber : 'Unknown',
        orderNumber: order.orderNumber,
        items: draftItems.map((i) => ({
          name: i.nameSnapshot,
          quantity: i.quantity,
          notes: i.itemNotes,
          variants: i.selectedVariants,
          addons: i.selectedAddons,
        })),
        customerNotes: order.customerNotes,
        sentByDeviceId: deviceId,
      },
      false
    );

    return kot;
  }

  public static async cancelSubmittedItem(
    orderId: string,
    itemId: string,
    reason: string,
    deviceId?: string
  ): Promise<{ message: string; cancelledItem: string }> {
    const order = await OrderService.getOrderById(orderId);
    const item = order.items.find((i) => i.id === itemId);

    if (!item) {
      throw new NotFoundError('Order Item', itemId);
    }

    if (item.status === 'cancelled') {
      throw new BadRequestError('Item is already cancelled');
    }

    if (item.status === 'draft') {
      throw new BadRequestError(
        'Item is still in draft. Remove or update draft directly rather than submitting cancellation.'
      );
    }

    const table = inMemoryStore.tables.get(order.tableId);
    const now = new Date().toISOString();

    item.status = 'cancelled';
    item.cancellationReason = reason;
    item.cancelledByDeviceId = deviceId;
    item.updatedAt = now;

    // Recalculate order totals after cancellation
    OrderService.recalculateOrderTotals(order);
    order.updatedAt = now;

    // Enqueue a cancellation slip to the kitchen thermal printer so chefs know immediately!
    await PrintService.enqueueJob(
      'kitchen_kot',
      'kot',
      order.id,
      {
        title: '*** ITEM CANCELLED ***',
        tableNumber: table ? table.tableNumber : 'Unknown',
        orderNumber: order.orderNumber,
        cancelledItem: {
          name: item.nameSnapshot,
          quantity: item.quantity,
          reason,
        },
        cancelledByDeviceId: deviceId,
      },
      false
    );

    // Record audit event
    inMemoryStore.auditLogs.push({
      id: `audit_${Date.now()}`,
      eventType: 'order_item_cancelled',
      entityType: 'order_item',
      entityId: item.id,
      actorDeviceId: deviceId,
      reason,
      details: {
        orderId: order.id,
        orderNumber: order.orderNumber,
        itemName: item.nameSnapshot,
        quantity: item.quantity,
      },
      createdAt: now,
    });

    return {
      message: `Item '${item.nameSnapshot}' was successfully cancelled and kitchen was notified`,
      cancelledItem: item.nameSnapshot,
    };
  }

  public static async getKotById(kotId: string): Promise<KotRecord> {
    const kot = inMemoryStore.kots.get(kotId);
    if (!kot) {
      throw new NotFoundError('KOT', kotId);
    }
    return kot;
  }

  public static async listKotsForOrder(orderId: string): Promise<KotRecord[]> {
    return Array.from(inMemoryStore.kots.values())
      .filter((k) => k.orderId === orderId)
      .sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime());
  }
}
