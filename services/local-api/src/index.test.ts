import { describe, it, expect, beforeAll } from 'vitest';
import request from 'supertest';
import { app } from './app.js';
import { inMemoryStore } from './db/inMemoryStore.js';

describe('Hinopt Restaurant POS - Local API Integration Suite', () => {
  beforeAll(() => {
    inMemoryStore.seed();
  });

  it('GET /api/health - returns 200 and healthy component metrics', async () => {
    const res = await request(app).get('/api/health');
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.status).toBe('healthy');
    expect(res.body.data.restaurant.name).toBe('Curry Leaf Fine Dining');
    expect(res.body.data.components.apiServer.status).toBe('online');
    expect(res.body.data.components.license.isValid).toBe(true);
  });

  it('GET /api/tables - returns tables with active order status', async () => {
    const res = await request(app)
      .get('/api/tables')
      .set('X-Device-Id', 'dev_captain_01')
      .set('X-Api-Key', 'captain_dev_token_01');

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(Array.isArray(res.body.data.tables)).toBe(true);
    expect(res.body.data.tables.length).toBeGreaterThan(0);
    expect(res.body.data.tables[0]).toHaveProperty('tableNumber');
  });

  it('GET /api/menu - returns hierarchical menu with variants & addons', async () => {
    const res = await request(app)
      .get('/api/menu')
      .set('X-Device-Id', 'dev_captain_01')
      .set('X-Api-Key', 'captain_dev_token_01');

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(Array.isArray(res.body.data.menu)).toBe(true);
    const starterCategory = res.body.data.menu.find((c: any) => c.id === 'cat_starters');
    expect(starterCategory).toBeDefined();
    expect(starterCategory.items.length).toBeGreaterThan(0);
    expect(starterCategory.items[0].pricePaise).toBeGreaterThan(0);
  });

  let createdOrderId: string;
  let draftItemId: string;

  it('POST /api/orders - Captain creates order with draft items on Table 1', async () => {
    const res = await request(app)
      .post('/api/orders')
      .set('X-Device-Id', 'dev_captain_01')
      .set('X-Api-Key', 'captain_dev_token_01')
      .send({
        tableId: 'tab_t1',
        customerNotes: 'Diner requested less spicy',
        guestCount: 2,
        items: [
          {
            menuItemId: 'item_paneer_65',
            quantity: 2,
            itemNotes: 'Extra crispy',
            selectedVariants: [{ id: 'full', name: 'Full', pricePaise: 24000 }],
            selectedAddons: [{ id: 'extra_chilli_dip', name: 'Extra Chilli Dip', pricePaise: 3000 }],
          },
          {
            menuItemId: 'item_butter_naan',
            quantity: 3,
          },
        ],
      });

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data.order.orderNumber).toMatch(/^ORD-\d+-\d+$/);
    expect(res.body.data.order.items.length).toBe(2);
    expect(res.body.data.order.items[0].status).toBe('draft');
    expect(res.body.data.order.totalPaise).toBeGreaterThan(0);

    createdOrderId = res.body.data.order.id;
    draftItemId = res.body.data.order.items[0].id;
  });

  let createdKotId: string;

  it('POST /api/orders/:id/kot - sends draft items to kitchen, queues print job', async () => {
    const res = await request(app)
      .post(`/api/orders/${createdOrderId}/kot`)
      .set('X-Device-Id', 'dev_captain_01')
      .set('X-Api-Key', 'captain_dev_token_01');

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data.kot.kotNumber).toMatch(/^KOT-\d+-\d+$/);
    expect(res.body.data.order.status).toBe('preparing');
    expect(res.body.data.order.items[0].status).toBe('sent_to_kitchen');

    createdKotId = res.body.data.kot.id;
  });

  it('POST /api/orders/:id/items/:itemId/cancel - auditable cancellation of submitted item', async () => {
    // Add another item and send to kitchen first
    await request(app)
      .post(`/api/orders/${createdOrderId}/items`)
      .set('X-Device-Id', 'dev_captain_01')
      .set('X-Api-Key', 'captain_dev_token_01')
      .send({
        items: [{ menuItemId: 'item_masala_chaas', quantity: 1 }],
      });

    await request(app)
      .post(`/api/orders/${createdOrderId}/kot`)
      .set('X-Device-Id', 'dev_captain_01')
      .set('X-Api-Key', 'captain_dev_token_01');

    const updatedOrder = await request(app)
      .get(`/api/orders/${createdOrderId}`)
      .set('X-Device-Id', 'dev_counter_01');

    const buttermilkItem = updatedOrder.body.data.order.items.find(
      (i: any) => i.menuItemId === 'item_masala_chaas'
    );

    const cancelRes = await request(app)
      .post(`/api/orders/${createdOrderId}/items/${buttermilkItem.id}/cancel`)
      .set('X-Device-Id', 'dev_counter_01')
      .set('X-Api-Key', 'counter_dev_token')
      .send({ reason: 'Guest changed their mind to lime soda' });

    expect(cancelRes.status).toBe(200);
    expect(cancelRes.body.success).toBe(true);
    expect(cancelRes.body.data.cancelledItem).toBe('Spiced Buttermilk (Neer Moru)');
  });

  let finalizedBillId: string;

  it('POST /api/billing/orders/:id/bill - Cashier finalizes bill with price snapshots', async () => {
    const res = await request(app)
      .post(`/api/billing/orders/${createdOrderId}/bill`)
      .set('X-Device-Id', 'dev_counter_01')
      .set('X-Api-Key', 'counter_dev_token')
      .send({ discountPaise: 0 });

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data.bill.billNumber).toMatch(/^BILL-\d+-\d+$/);
    expect(res.body.data.bill.status).toBe('finalized');
    expect(res.body.data.bill.totalPaise).toBeGreaterThan(0);
    expect(res.body.data.bill.items.length).toBeGreaterThan(0);

    finalizedBillId = res.body.data.bill.id;
  });

  it('POST /api/billing/bills/:id/reprint - Safe reprint with REPRINT watermark', async () => {
    const res = await request(app)
      .post(`/api/billing/bills/${finalizedBillId}/reprint`)
      .set('X-Device-Id', 'dev_counter_01')
      .set('X-Api-Key', 'counter_dev_token');

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.bill.printCount).toBe(2);
    expect(res.body.data.printJobId).toBeDefined();
  });

  it('POST /api/billing/bills/:id/payments - Settle payment with idempotency key', async () => {
    const billDetails = await request(app)
      .get(`/api/billing/bills/${finalizedBillId}`)
      .set('X-Device-Id', 'dev_counter_01');

    const totalToPay = billDetails.body.data.bill.totalPaise;
    const idempotencyKey = `idem_pay_test_${Date.now()}`;

    const res = await request(app)
      .post(`/api/billing/bills/${finalizedBillId}/payments`)
      .set('X-Device-Id', 'dev_counter_01')
      .set('X-Api-Key', 'counter_dev_token')
      .send({
        amountPaise: totalToPay,
        paymentMethod: 'upi',
        idempotencyKey,
        referenceNumber: 'UPI/1234567890/test',
        notes: 'Paid via PhonePe QR',
      });

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data.payment.status).toBe('completed');
    expect(res.body.data.bill.status).toBe('settled');

    // Verify table is freed and available
    const tableRes = await request(app)
      .get('/api/tables/tab_t1')
      .set('X-Device-Id', 'dev_counter_01');
    expect(tableRes.body.data.table.status).toBe('available');
    expect(tableRes.body.data.table.activeOrderId).toBeNull();

    // Verify idempotency: duplicate call with same idempotencyKey returns existing without double charge
    const dupRes = await request(app)
      .post(`/api/billing/bills/${finalizedBillId}/payments`)
      .set('X-Device-Id', 'dev_counter_01')
      .set('X-Api-Key', 'counter_dev_token')
      .send({
        amountPaise: totalToPay,
        paymentMethod: 'upi',
        idempotencyKey,
      });

    expect(dupRes.status).toBe(201);
    expect(dupRes.body.data.payment.id).toBe(res.body.data.payment.id);
  });

  it('GET /api/reports/daily-summary - Daily sales and breakdown in integer paise', async () => {
    const res = await request(app)
      .get('/api/reports/daily-summary')
      .set('X-Device-Id', 'dev_counter_01')
      .set('X-Api-Key', 'counter_dev_token');

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.summary.settledBillsCount).toBeGreaterThan(0);
    expect(res.body.data.summary.totalSalesPaise).toBeGreaterThan(0);
    expect(res.body.data.summary.paymentBreakdown.upi).toBeGreaterThan(0);
  });
});
