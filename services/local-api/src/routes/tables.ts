import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { inMemoryStore } from '../db/inMemoryStore.js';
import { NotFoundError } from '../utils/errors.js';
import { authenticateDevice, requireRole } from '../middleware/auth.js';
import { validateBody } from '../middleware/validate.js';

export const tablesRouter = Router();

tablesRouter.use(authenticateDevice);

// GET /api/tables - List tables with live order metadata
tablesRouter.get('/', (req: Request, res: Response) => {
  const tables = Array.from(inMemoryStore.tables.values())
    .sort((a, b) => a.sortOrder - b.sortOrder)
    .map((table) => {
      let activeOrderSummary = null;
      if (table.activeOrderId) {
        const order = inMemoryStore.orders.get(table.activeOrderId);
        if (order && !['settled', 'cancelled'].includes(order.status)) {
          activeOrderSummary = {
            orderId: order.id,
            orderNumber: order.orderNumber,
            status: order.status,
            itemCount: order.items.filter((i) => i.status !== 'cancelled').length,
            totalPaise: order.totalPaise,
          };
        }
      }

      return {
        ...table,
        activeOrder: activeOrderSummary,
      };
    });

  res.json({
    success: true,
    data: {
      tables,
    },
  });
});

// GET /api/tables/:id - Get specific table details
tablesRouter.get('/:id', (req: Request, res: Response, next: NextFunction) => {
  try {
    const id = req.params.id as string;
    const table = inMemoryStore.tables.get(id);
    if (!table) {
      throw new NotFoundError('Table', id);
    }

    let activeOrder = null;
    if (table.activeOrderId) {
      activeOrder = inMemoryStore.orders.get(table.activeOrderId) || null;
    }

    res.json({
      success: true,
      data: {
        table,
        activeOrder,
      },
    });
  } catch (err) {
    next(err);
  }
});

const updateTableStatusSchema = z.object({
  status: z.enum(['available', 'occupied', 'billed', 'reserved', 'maintenance']),
});

// PATCH /api/tables/:id/status - Update table status (Counter / Admin only)
tablesRouter.patch(
  '/:id/status',
  requireRole('counter', 'admin'),
  validateBody(updateTableStatusSchema),
  (req: Request, res: Response, next: NextFunction) => {
    try {
      const id = req.params.id as string;
      const table = inMemoryStore.tables.get(id);
      if (!table) {
        throw new NotFoundError('Table', id);
      }

      table.status = req.body.status;
      if (table.status === 'available') {
        table.activeOrderId = null;
      }

      res.json({
        success: true,
        data: {
          table,
        },
      });
    } catch (err) {
      next(err);
    }
  }
);
