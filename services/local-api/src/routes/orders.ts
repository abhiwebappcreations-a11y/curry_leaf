import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { inMemoryStore } from '../db/inMemoryStore.js';
import { OrderService } from '../services/orderService.js';
import { KotService } from '../services/kotService.js';
import { BillingService } from '../services/billingService.js';
import { authenticateDevice, requireRole } from '../middleware/auth.js';
import { validateBody } from '../middleware/validate.js';

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
ordersRouter.post('/:id/bill', requireRole('counter', 'admin'), async (req: Request, res: Response, next: NextFunction) => {
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
ordersRouter.post('/:id/kot', async (req: Request, res: Response, next: NextFunction) => {
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

// POST /api/orders/:id/items/:itemId/cancel - Auditable cancellation workflow
ordersRouter.post(
  '/:id/items/:itemId/cancel',
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
