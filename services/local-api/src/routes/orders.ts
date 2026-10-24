import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { inMemoryStore } from '../db/inMemoryStore.js';
import { OrderService } from '../services/orderService.js';
import { KotService } from '../services/kotService.js';
import { BillingService } from '../services/billingService.js';
import { authenticateDevice, requireRole, requireActiveLicense } from '../middleware/auth.js';
import { validateBody } from '../middleware/validate.js';
import { PrintService } from '../services/printService.js';
import { NotFoundError } from '../utils/errors.js';

export const ordersRouter = Router();

ordersRouter.use(authenticateDevice);

const createOrderItemSchema = z.object({
  menuItemId: z.string().min(1),
  quantity: z.number().int().positive(),
  itemNotes: z.string().optional(),
  selectedVariants: z
    .array(z.object({ id: z.string(), name: z.string(), pricePaise: z.number().int() }))
    .optional(),
  selectedAddons: z
    .array(z.object({ id: z.string(), name: z.string(), pricePaise: z.number().int() }))
    .optional(),
});

const createOrderSchema = z.object({
  tableId: z.string().min(1),
  customerNotes: z.string().optional(),
  guestCount: z.number().int().positive().optional(),
  items: z.array(createOrderItemSchema).optional(),
});

// POST /api/orders - Create new order
ordersRouter.post(
  '/',
  requireActiveLicense,
  validateBody(createOrderSchema),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const order = await OrderService.createOrder(req.body, req.device?.id);
      res.status(201).json({
        success: true,
        data: {
          order,
        },
      });
    } catch (err) {
      next(err);
    }
  }
);

// GET /api/orders - List orders
ordersRouter.get('/', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { status, tableId } = req.query;
    const orders = await OrderService.listOrders(
      typeof status === 'string' ? status : undefined,
      typeof tableId === 'string' ? tableId : undefined
    );

    res.json({
      success: true,
      data: {
        orders,
      },
    });
  } catch (err) {
    next(err);
  }
});

// GET /api/orders/:id - Get specific order details
ordersRouter.get('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const order = await OrderService.getOrderById(req.params.id as string);
    const kots = await KotService.listKotsForOrder(order.id);

    res.json({
      success: true,
      data: {
        order,
        kots,
      },
    });
  } catch (err) {
    next(err);
  }
});

// POST /api/orders/:id/bill - Generate or update bill for order
ordersRouter.post('/:id/bill', requireActiveLicense, requireRole('counter', 'admin'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const bill = await BillingService.finalizeBill(req.params.id as string, req.body, req.device?.id);
    res.status(201).json({
      success: true,
      data: {
        bill,
      },
    });
  } catch (err) {
    next(err);
  }
});

const addItemsSchema = z.object({
  items: z.array(createOrderItemSchema).min(1),
});

// POST /api/orders/:id/items - Append new items
ordersRouter.post(
  '/:id/items',
  requireActiveLicense,
  validateBody(addItemsSchema),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const order = await OrderService.addItemsToOrder(req.params.id as string, req.body.items);
      res.json({
        success: true,
        data: {
          order,
        },
      });
    } catch (err) {
      next(err);
    }
  }
);

const updateDraftItemSchema = z.object({
  quantity: z.number().int().min(0),
  itemNotes: z.string().optional(),
});

// PATCH /api/orders/:id/items/:itemId - Update draft item
ordersRouter.patch(
  '/:id/items/:itemId',
  requireActiveLicense,
  validateBody(updateDraftItemSchema),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const order = await OrderService.updateDraftItem(
        req.params.id as string,
        req.params.itemId as string,
        req.body.quantity,
        req.body.itemNotes
      );
      res.json({
        success: true,
        data: {
          order,
        },
      });
    } catch (err) {
      next(err);
    }
  }
);

// POST /api/orders/:id/kot - Send draft items to kitchen (triggers KOT generation & print)
ordersRouter.post('/:id/kot', requireActiveLicense, async (req: Request, res: Response, next: NextFunction) => {
  try {
    let orderId = req.params.id as string;
    let order = inMemoryStore.orders.get(orderId);

    // If order is not found by ID, but tableId is provided, check active order or auto-create
    if (!order && req.body?.tableId) {
      const table = inMemoryStore.tables.get(req.body.tableId);
      if (table?.activeOrderId && inMemoryStore.orders.has(table.activeOrderId)) {
        orderId = table.activeOrderId;
        order = inMemoryStore.orders.get(orderId);
      } else {
        const newOrder = await OrderService.createOrder(
          {
            tableId: req.body.tableId,
            items: req.body.items,
          },
          req.device?.id
        );
        orderId = newOrder.id;
        order = newOrder;
      }
    }

    // If items were passed in body and order already exists, ensure draft items are appended
    if (order && req.body?.items && Array.isArray(req.body.items) && req.body.items.length > 0) {
      const hasDrafts = order.items.some((i) => i.status === 'draft');
      if (!hasDrafts) {
        await OrderService.addItemsToOrder(orderId, req.body.items);
      }
    }

    const kot = await KotService.sendToKitchen(orderId, req.device?.id);
    const updatedOrder = await OrderService.getOrderById(orderId);

    res.status(201).json({
      success: true,
      data: {
        kot,
        order: updatedOrder,
      },
    });
  } catch (err) {
    next(err);
  }
});

const cancelItemSchema = z.object({
  reason: z.string().min(3),
});

const cancelOrderSchema = z.object({
  reason: z.string().min(2),
});

// POST /api/orders/:id/cancel - Instant Order Void / Cancellation Workflow (Petpooja style)
ordersRouter.post(
  '/:id/cancel',
  requireActiveLicense,
  requireRole('counter', 'admin', 'captain'),
  validateBody(cancelOrderSchema),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const id = req.params.id as string;
      const { reason } = req.body;

      const order = inMemoryStore.orders.get(id);
      if (!order) {
        throw new NotFoundError('Order', id);
      }

      order.status = 'cancelled';
      order.customerNotes = (order.customerNotes ? order.customerNotes + ' | ' : '') + `Cancelled: ${reason}`;
      order.updatedAt = new Date().toISOString();

      // Free the table immediately
      const table = inMemoryStore.tables.get(order.tableId);
      if (table) {
        table.status = 'available';
        table.activeOrderId = null;
      }

      // Void any active bill for this order
      for (const bill of inMemoryStore.bills.values()) {
        if (bill.orderId === id && bill.status !== 'settled') {
          bill.status = 'voided';
          bill.voidReason = reason;
        }
      }

      // Enqueue Kitchen Cancellation Alert KOT to thermal printer so chef stops cooking!
      await PrintService.enqueueJob(
        'kitchen_kot',
        'kot',
        order.id,
        {
          kotNumber: 'CANCEL',
          title: '*** ORDER CANCELLED ***',
          tableName: table ? table.displayName || table.tableNumber : 'Table',
          orderNumber: order.orderNumber,
          reason,
          items: order.items.map((i) => ({
            name: `[CANCELLED] ${i.nameSnapshot}`,
            quantity: i.quantity,
            itemNotes: `REASON: ${reason}`,
          })),
        }
      );

      inMemoryStore.saveToDisk();

      res.json({
        success: true,
        data: {
          message: 'Order cancelled, table released, and kitchen alert dispatched.',
          order,
        },
      });
    } catch (err) {
      next(err);
    }
  }
);

// POST /api/orders/:id/items/:itemId/cancel - Auditable cancellation workflow
ordersRouter.post(
  '/:id/items/:itemId/cancel',
  requireActiveLicense,
  requireRole('counter', 'admin'),
  validateBody(cancelItemSchema),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const result = await KotService.cancelSubmittedItem(
        req.params.id as string,
        req.params.itemId as string,
        req.body.reason,
        req.device?.id
      );
      const order = await OrderService.getOrderById(req.params.id as string);

      res.json({
        success: true,
        data: {
          ...result,
          order,
        },
      });
    } catch (err) {
      next(err);
    }
  }
);

const cancelRequestSchema = z.object({
  itemId: z.string().optional(),
  reason: z.string().min(2),
});

// POST /api/orders/:id/cancel-request - Captain or Counter submits cancellation request
ordersRouter.post(
  '/:id/cancel-request',
  requireActiveLicense,
  requireRole('captain', 'counter', 'admin'),
  validateBody(cancelRequestSchema),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const orderId = req.params.id as string;
      const order = inMemoryStore.orders.get(orderId);
      if (!order) {
        throw new NotFoundError('Order', orderId);
      }

      const table = inMemoryStore.tables.get(order.tableId);
      let itemName: string | undefined;
      let itemQuantity: number | undefined;

      if (req.body.itemId) {
        const item = order.items.find((i) => i.id === req.body.itemId);
        if (item) {
          itemName = item.nameSnapshot;
          itemQuantity = item.quantity;
        }
      }

      const cancelReq = {
        id: `creq_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
        orderId: order.id,
        orderNumber: order.orderNumber,
        tableId: order.tableId,
        tableName: table ? (table.displayName || table.tableNumber) : 'Table',
        itemId: req.body.itemId,
        itemName,
        itemQuantity,
        reason: req.body.reason,
        requestedByDeviceId: req.device?.id,
        status: 'pending' as const,
        createdAt: new Date().toISOString(),
      };

      inMemoryStore.cancelRequests.set(cancelReq.id, cancelReq);
      inMemoryStore.saveToDisk();

      res.status(201).json({
        success: true,
        data: {
          message: 'Cancellation request sent to Counter Manager for approval.',
          request: cancelReq,
        },
      });
    } catch (err) {
      next(err);
    }
  }
);

// GET /api/orders/cancel-requests/pending - Fetch active cancellation requests awaiting Counter approval
ordersRouter.get(
  ['/cancel-requests/pending', '/cancel-requests'],
  requireActiveLicense,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const pending = Array.from(inMemoryStore.cancelRequests.values()).filter(
        (r) => r.status === 'pending'
      );
      res.json({
        success: true,
        data: {
          requests: pending,
        },
      });
    } catch (err) {
      next(err);
    }
  }
);

// POST /api/orders/cancel-requests/:requestId/approve - Counter Manager approves cancellation
ordersRouter.post(
  '/cancel-requests/:requestId/approve',
  requireActiveLicense,
  requireRole('counter', 'admin'),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const requestId = req.params.requestId as string;
      const cancelReq = inMemoryStore.cancelRequests.get(requestId);
      if (!cancelReq) {
        throw new NotFoundError('Cancellation Request', requestId);
      }

      const order = inMemoryStore.orders.get(cancelReq.orderId);
      if (!order) {
        throw new NotFoundError('Order', cancelReq.orderId);
      }

      const table = inMemoryStore.tables.get(cancelReq.tableId);

      if (cancelReq.itemId) {
        // Cancel single line item and print Kitchen Cancellation Slip
        await KotService.cancelSubmittedItem(
          cancelReq.orderId,
          cancelReq.itemId,
          cancelReq.reason,
          req.device?.id
        );
      } else {
        // Cancel entire order, free table, and print Kitchen Cancellation Ticket
        order.status = 'cancelled';
        order.customerNotes = (order.customerNotes ? order.customerNotes + ' | ' : '') + `Cancelled: ${cancelReq.reason}`;
        order.updatedAt = new Date().toISOString();

        if (table) {
          table.status = 'available';
          table.activeOrderId = null;
        }

        for (const bill of inMemoryStore.bills.values()) {
          if (bill.orderId === order.id && bill.status !== 'settled') {
            bill.status = 'voided';
            bill.voidReason = cancelReq.reason;
          }
        }

        await PrintService.enqueueJob(
          'kitchen_kot',
          'kot',
          order.id,
          {
            kotNumber: 'CANCEL',
            title: '*** ORDER CANCELLED ***',
            tableName: table ? table.displayName || table.tableNumber : 'Table',
            orderNumber: order.orderNumber,
            reason: cancelReq.reason,
            items: order.items.map((i) => ({
              name: `[CANCELLED] ${i.nameSnapshot}`,
              quantity: i.quantity,
              itemNotes: `REASON: ${cancelReq.reason}`,
            })),
          }
        );
      }

      cancelReq.status = 'approved';
      cancelReq.resolvedAt = new Date().toISOString();
      inMemoryStore.saveToDisk();

      res.json({
        success: true,
        data: {
          message: 'Cancellation approved. Order updated and Kitchen Cancellation KOT dispatched.',
          request: cancelReq,
        },
      });
    } catch (err) {
      next(err);
    }
  }
);

// POST /api/orders/cancel-requests/:requestId/reject - Counter Manager rejects cancellation
ordersRouter.post(
  '/cancel-requests/:requestId/reject',
  requireActiveLicense,
  requireRole('counter', 'admin'),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const requestId = req.params.requestId as string;
      const cancelReq = inMemoryStore.cancelRequests.get(requestId);
      if (!cancelReq) {
        throw new NotFoundError('Cancellation Request', requestId);
      }

      cancelReq.status = 'rejected';
      cancelReq.resolvedAt = new Date().toISOString();
      inMemoryStore.saveToDisk();

      res.json({
        success: true,
        data: {
          message: 'Cancellation request rejected.',
          request: cancelReq,
        },
      });
    } catch (err) {
      next(err);
    }
  }
);
