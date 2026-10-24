import {
  inMemoryStore,
  BillRecord,
  BillItemRecord,
  PaymentRecord,
} from '../db/inMemoryStore.js';
import { NotFoundError, BadRequestError, ConflictError } from '../utils/errors.js';
import { OrderService } from './orderService.js';
import { PrintService } from './printService.js';
import { calculateTaxPaise } from '../utils/money.js';

let billCounter = 3000;

export interface FinalizeBillInput {
  discountPaise?: number;
  voidReason?: string;
}

export interface SettlePaymentInput {
  amountPaise: number;
  paymentMethod: 'cash' | 'upi' | 'card' | 'split' | 'other';
  idempotencyKey: string;
  orderId?: string;
  referenceNumber?: string;
  notes?: string;
}

export class BillingService {
  public static generateBillNumber(): string {
    const today = new Date().toISOString().slice(2, 10).replace(/-/g, '');
    billCounter += 1;
    return `BILL-${today}-${billCounter}`;
  }

  public static async finalizeBill(
    orderId: string,
    input: FinalizeBillInput = {},
    deviceId?: string
  ): Promise<BillRecord> {
    const order = await OrderService.getOrderById(orderId);
    const table = inMemoryStore.tables.get(order.tableId);

    if (order.status === 'settled') {
      throw new ConflictError('ORDER_ALREADY_SETTLED', 'This order is already settled and closed');
    }
    if (order.status === 'cancelled') {
      throw new BadRequestError('Cannot generate bill for a cancelled order');
    }

    // Active items only
    const billableItems = order.items.filter((i) => i.status !== 'cancelled');
    if (billableItems.length === 0) {
      throw new BadRequestError('No active billable items in this order');
    }

    // Check if a bill already exists for this order
    const existingBill = Array.from(inMemoryStore.bills.values()).find(
      (b) => b.orderId === order.id && b.status !== 'voided'
    );
    if (existingBill) {
      if (existingBill.status === 'settled') {
        return existingBill;
      }
      // If the bill is not yet settled, update it with latest order items & discount
      const discountPaise = input.discountPaise !== undefined ? input.discountPaise : existingBill.discountPaise;
      let subtotalPaise = 0;
      let taxPaise = 0;
      const now = new Date().toISOString();
      const updatedItems: BillItemRecord[] = billableItems.map((item) => {
        const itemTotal = item.pricePaiseSnapshot * item.quantity;
        const itemTax = calculateTaxPaise(itemTotal, item.taxRateSnapshot);
        subtotalPaise += itemTotal;
        taxPaise += itemTax;

        return {
          id: `bi_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
          billId: existingBill.id,
          menuItemId: item.menuItemId,
          nameSnapshot: item.nameSnapshot,
          unitPricePaise: item.pricePaiseSnapshot,
          quantity: item.quantity,
          totalPaise: itemTotal,
          taxPaise: itemTax,
          optionsSnapshot: {
            variants: item.selectedVariants,
            addons: item.selectedAddons,
          },
          createdAt: now,
        };
      });

      existingBill.items = updatedItems;
      existingBill.subtotalPaise = subtotalPaise;
      existingBill.taxPaise = taxPaise;
      existingBill.discountPaise = discountPaise;
      existingBill.totalPaise = Math.max(0, subtotalPaise + taxPaise - discountPaise);
      existingBill.finalizedAt = now;

      order.subtotalPaise = subtotalPaise;
      order.taxPaise = taxPaise;
      order.discountPaise = discountPaise;
      order.totalPaise = existingBill.totalPaise;
      order.updatedAt = now;

      return existingBill;
    }

    const billId = `bill_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const billNumber = this.generateBillNumber();
    const now = new Date().toISOString();

    let subtotalPaise = 0;
    let taxPaise = 0;

    const immutableBillItems: BillItemRecord[] = billableItems.map((item) => {
      const itemTotal = item.pricePaiseSnapshot * item.quantity;
      const itemTax = calculateTaxPaise(itemTotal, item.taxRateSnapshot);
      subtotalPaise += itemTotal;
      taxPaise += itemTax;

      return {
        id: `bi_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
        billId,
        menuItemId: item.menuItemId,
        nameSnapshot: item.nameSnapshot,
        unitPricePaise: item.pricePaiseSnapshot,
        quantity: item.quantity,
        totalPaise: itemTotal,
        taxPaise: itemTax,
        optionsSnapshot: {
          variants: item.selectedVariants,
          addons: item.selectedAddons,
        },
        createdAt: now,
      };
    });

    const discountPaise = input.discountPaise || 0;
    const totalPaise = Math.max(0, subtotalPaise + taxPaise - discountPaise);

    const bill: BillRecord = {
      id: billId,
      billNumber,
      orderId: order.id,
      tableId: order.tableId,
      subtotalPaise,
      taxPaise,
      discountPaise,
      totalPaise,
      status: 'finalized',
      printStatus: 'pending',
      printCount: 1,
      createdByDeviceId: deviceId,
      items: immutableBillItems,
      finalizedAt: now,
      createdAt: now,
    };

    inMemoryStore.bills.set(bill.id, bill);

    // Update order status and table status
    order.status = 'billed';
    order.subtotalPaise = subtotalPaise;
    order.taxPaise = taxPaise;
    order.discountPaise = discountPaise;
    order.totalPaise = totalPaise;
    order.updatedAt = now;

    if (table) {
      table.status = 'billed';
    }

    // Note: finalizeBill prepares the bill record without auto-printing. Printing occurs on settlement or explicit print request.

    return bill;
  }

  public static async settlePayment(
    billIdOrOrderId: string,
    input: SettlePaymentInput,
    deviceId?: string
  ): Promise<{ payment: PaymentRecord; bill: BillRecord }> {
    let bill = inMemoryStore.bills.get(billIdOrOrderId);
    if (!bill) {
      bill = Array.from(inMemoryStore.bills.values()).find(
        (b) => b.orderId === billIdOrOrderId || b.billNumber === billIdOrOrderId
      );
    }
    if (!bill) {
      let order = inMemoryStore.orders.get(billIdOrOrderId);
      if (!order && input.orderId) {
        order = inMemoryStore.orders.get(input.orderId);
      }
      if (!order) {
        order = Array.from(inMemoryStore.orders.values()).find(
          (o) => o.status === 'active' || o.status === 'billed'
        );
      }
      if (order) {
        bill = await this.finalizeBill(order.id, { discountPaise: 0 }, deviceId);
      }
    }
    if (!bill) {
      throw new NotFoundError('Bill', billIdOrOrderId);
    }

    if (bill.status === 'voided') {
      throw new BadRequestError('Cannot settle a voided bill');
    }

    // Idempotency check: if payment with this key already exists, return existing
    const existingPayment = Array.from(inMemoryStore.payments.values()).find(
      (p) => p.idempotencyKey === input.idempotencyKey
    );
    if (existingPayment) {
      return { payment: existingPayment, bill };
    }

    if (bill.status === 'settled') {
      throw new ConflictError('BILL_ALREADY_SETTLED', 'This bill has already been settled in full');
    }

    const now = new Date().toISOString();
    const paymentId = `pay_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;

    const payment: PaymentRecord = {
      id: paymentId,
      billId: bill.id,
      amountPaise: input.amountPaise,
      paymentMethod: input.paymentMethod,
      referenceNumber: input.referenceNumber,
      status: 'completed',
      idempotencyKey: input.idempotencyKey,
      settledByDeviceId: deviceId,
      notes: input.notes,
      createdAt: now,
    };

    inMemoryStore.payments.set(payment.id, payment);

    bill.status = 'settled';
    bill.settledAt = now;

    // Update order status to settled
    const order = inMemoryStore.orders.get(bill.orderId);
    if (order) {
      order.status = 'settled';
      order.updatedAt = now;
    }

    // Free the table for new diners
    const table = inMemoryStore.tables.get(bill.tableId);
    if (table) {
      table.status = 'available';
      table.activeOrderId = null;
    }

    // Automatically enqueue Customer Bill receipt to Counter Printer upon settlement
    try {
      await PrintService.enqueueJob(
        'counter_bill',
        'bill',
        bill.id,
        {
          billNumber: bill.billNumber,
          orderNumber: order ? order.orderNumber : undefined,
          tableNumber: table ? (table.displayName || table.tableNumber) : 'Counter',
          items: bill.items.map((bi) => ({
            name: bi.nameSnapshot,
            quantity: bi.quantity,
            total: bi.totalPaise,
            unitPrice: bi.unitPricePaise,
          })),
          subtotalPaise: bill.subtotalPaise,
          taxPaise: bill.taxPaise,
          discountPaise: bill.discountPaise,
          totalPaise: bill.totalPaise,
          paymentMethod: input.paymentMethod,
          restaurantName: (inMemoryStore.settings.get('restaurant_profile') as any)?.name || 'Curry Leaf Fine Dining',
        }
      );
    } catch (printErr) {
      console.error('[BillingService] Failed to enqueue customer bill receipt:', printErr);
    }

    // Audit log
    inMemoryStore.auditLogs.push({
      id: `audit_${Date.now()}`,
      eventType: 'payment_settled',
      entityType: 'bill',
      entityId: bill.id,
      actorDeviceId: deviceId,
      details: {
        billNumber: bill.billNumber,
        amountPaise: input.amountPaise,
        method: input.paymentMethod,
        idempotencyKey: input.idempotencyKey,
      },
      createdAt: now,
    });

    return { payment, bill };
  }

  public static async reprintBill(
    billId: string,
    deviceId?: string
  ): Promise<{ bill: BillRecord; printJobId: string }> {
    const bill = inMemoryStore.bills.get(billId);
    if (!bill) {
      throw new NotFoundError('Bill', billId);
    }

    bill.printCount += 1;
    const table = inMemoryStore.tables.get(bill.tableId);

    const job = await PrintService.enqueueJob(
      'counter_bill',
      'reprint_bill',
      bill.id,
      {
        billNumber: bill.billNumber,
        tableNumber: table ? table.tableNumber : 'Unknown',
        items: bill.items,
        totalPaise: bill.totalPaise,
        reprintCount: bill.printCount,
      },
      true
    );

    inMemoryStore.auditLogs.push({
      id: `audit_${Date.now()}`,
      eventType: 'bill_reprinted',
      entityType: 'bill',
      entityId: bill.id,
      actorDeviceId: deviceId,
      details: {
        billNumber: bill.billNumber,
        printCount: bill.printCount,
      },
      createdAt: new Date().toISOString(),
    });

    return { bill, printJobId: job.id };
  }

  public static async voidBill(
    billId: string,
    reason: string,
    deviceId?: string
  ): Promise<BillRecord> {
    const bill = inMemoryStore.bills.get(billId);
    if (!bill) {
      throw new NotFoundError('Bill', billId);
    }

    if (bill.status === 'settled') {
      throw new BadRequestError('Cannot void a settled bill. Process a refund instead.');
    }

    bill.status = 'voided';
    bill.voidReason = reason;

    // Reset order status back to active so it can be re-billed or corrected
    const order = inMemoryStore.orders.get(bill.orderId);
    if (order) {
      order.status = 'active';
      order.updatedAt = new Date().toISOString();
    }

    inMemoryStore.auditLogs.push({
      id: `audit_${Date.now()}`,
      eventType: 'bill_voided',
      entityType: 'bill',
      entityId: bill.id,
      actorDeviceId: deviceId,
      reason,
      details: {
        billNumber: bill.billNumber,
        totalPaise: bill.totalPaise,
      },
      createdAt: new Date().toISOString(),
    });

    return bill;
  }

  public static async getBillById(billId: string): Promise<BillRecord> {
    const bill = inMemoryStore.bills.get(billId);
    if (!bill) {
      throw new NotFoundError('Bill', billId);
    }
    return bill;
  }

  public static async listBills(status?: string): Promise<BillRecord[]> {
    let bills = Array.from(inMemoryStore.bills.values());
    if (status) {
      bills = bills.filter((b) => b.status === status);
    }
    return bills.sort(
      (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
    );
  }
  public static async printBill(
    billIdOrOrderId: string,
    isReprint = false
  ): Promise<BillRecord> {
    let bill = inMemoryStore.bills.get(billIdOrOrderId);
    if (!bill) {
      bill = Array.from(inMemoryStore.bills.values()).find(
        (b) => b.orderId === billIdOrOrderId || b.billNumber === billIdOrOrderId
      );
    }
    if (!bill) {
      let order = inMemoryStore.orders.get(billIdOrOrderId);
      if (!order) {
        order = Array.from(inMemoryStore.orders.values()).find(
          (o) => o.status === 'active' || o.status === 'billed'
        );
      }
      if (order) {
        bill = await this.finalizeBill(order.id, { discountPaise: 0 });
      }
    }
    if (!bill) {
      throw new NotFoundError('Bill', billIdOrOrderId);
    }

    const table = inMemoryStore.tables.get(bill.tableId);
    const order = inMemoryStore.orders.get(bill.orderId);
    await PrintService.enqueueJob(
      'counter_bill',
      isReprint ? 'reprint_bill' : 'bill',
      bill.id,
      {
        billNumber: bill.billNumber,
        orderNumber: order ? order.orderNumber : undefined,
        tableNumber: table ? (table.displayName || table.tableNumber) : 'Counter',
        items: bill.items.map((bi) => ({
          name: bi.nameSnapshot,
          quantity: bi.quantity,
          total: bi.totalPaise,
          unitPrice: bi.unitPricePaise,
        })),
        subtotalPaise: bill.subtotalPaise,
        taxPaise: bill.taxPaise,
        discountPaise: bill.discountPaise,
        totalPaise: bill.totalPaise,
        paymentMethod: 'Cash / Card / UPI',
        restaurantName: (inMemoryStore.settings.get('restaurant_profile') as any)?.name || 'Curry Leaf Fine Dining',
      },
      isReprint
    );

    return bill;
  }

}
