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


const createTableSchema = z.object({
  tableNumber: z.string().min(1),
  displayName: z.string().optional(),
  section: z.string().min(1).default('Main Dining'),
  capacity: z.number().int().min(1).default(4),
  sortOrder: z.number().int().optional(),
});

// POST /api/tables - Create a new custom table
tablesRouter.post(
  '/',
  requireRole('counter', 'admin'),
  validateBody(createTableSchema),
  (req: Request, res: Response, next: NextFunction) => {
    try {
      const { tableNumber, displayName, section, capacity, sortOrder } = req.body;
      const id = 'tab_' + Date.now() + '_' + Math.floor(Math.random() * 1000);
      const newTable = {
        id,
        tableNumber: tableNumber.trim(),
        displayName: displayName ? displayName.trim() : 'Table ' + tableNumber.trim(),
        section: section.trim(),
        capacity: capacity || 4,
        status: 'available' as const,
        activeOrderId: null,
        sortOrder: sortOrder || (inMemoryStore.tables.size + 1),
      };

      inMemoryStore.tables.set(id, newTable);
      inMemoryStore.saveToDisk();

      res.status(201).json({
        success: true,
        data: {
          table: newTable,
        },
      });
    } catch (err) {
      next(err);
    }
  }
);

const updateTableSchema = z.object({
  tableNumber: z.string().min(1).optional(),
  displayName: z.string().optional(),
  section: z.string().min(1).optional(),
  capacity: z.number().int().min(1).optional(),
  sortOrder: z.number().int().optional(),
});

// PUT /api/tables/:id - Update table details
tablesRouter.put(
  '/:id',
  requireRole('counter', 'admin'),
  validateBody(updateTableSchema),
  (req: Request, res: Response, next: NextFunction) => {
    try {
      const id = req.params.id as string;
      const table = inMemoryStore.tables.get(id);
      if (!table) {
        throw new NotFoundError('Table', id);
      }

      if (req.body.tableNumber) table.tableNumber = req.body.tableNumber.trim();
      if (req.body.displayName) table.displayName = req.body.displayName.trim();
      if (req.body.section) table.section = req.body.section.trim();
      if (req.body.capacity) table.capacity = req.body.capacity;
      if (req.body.sortOrder !== undefined) table.sortOrder = req.body.sortOrder;

      inMemoryStore.saveToDisk();

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

// DELETE /api/tables/all/wipe - Complete Fresh Client Onboarding Wipe
tablesRouter.delete(
  '/all/wipe',
  requireRole('counter', 'admin'),
  (req: Request, res: Response, next: NextFunction) => {
    try {
      inMemoryStore.orders.clear();
      inMemoryStore.bills.clear();
      inMemoryStore.kots.clear();
      inMemoryStore.payments.clear();
      inMemoryStore.printJobs.clear();
      inMemoryStore.tables.clear();

      inMemoryStore.saveToDisk();

      res.json({
        success: true,
        data: {
          message: 'All demo tables, orders, and bills wiped cleanly. Ready for new client floor plan setup.',
          tableCount: 0,
        },
      });
    } catch (err) {
      next(err);
    }
  }
);

// DELETE /api/tables/demo/clear - Clear all demo tables
tablesRouter.delete(
  '/demo/clear',
  requireRole('counter', 'admin'),
  (req: Request, res: Response, next: NextFunction) => {
    try {
      const demoIds = ['tab_t1', 'tab_t2', 'tab_t3', 'tab_t4', 'tab_t5', 'tab_p1', 'tab_p2', 'tab_ac1'];
      let clearedCount = 0;
      for (const id of demoIds) {
        const table = inMemoryStore.tables.get(id);
        if (table) {
          // If demo table has active order, cancel the demo order
          if (table.activeOrderId) {
            const order = inMemoryStore.orders.get(table.activeOrderId);
            if (order) order.status = 'cancelled';
          }
          inMemoryStore.tables.delete(id);
          clearedCount++;
        }
      }

      inMemoryStore.saveToDisk();

      res.json({
        success: true,
        data: {
          clearedCount,
          remainingCount: inMemoryStore.tables.size,
        },
      });
    } catch (err) {
      next(err);
    }
  }
);

// DELETE /api/tables/:id - Delete a table
tablesRouter.delete(
  '/:id',
  requireRole('counter', 'admin'),
  (req: Request, res: Response, next: NextFunction) => {
    try {
      const id = req.params.id as string;
      const table = inMemoryStore.tables.get(id);
      if (!table) {
        throw new NotFoundError('Table', id);
      }

      // Detach or cancel any active order on this table so it can be deleted cleanly
      if (table.activeOrderId) {
        const order = inMemoryStore.orders.get(table.activeOrderId);
        if (order) {
          order.status = 'cancelled';
        }
      }

      inMemoryStore.tables.delete(id);
      inMemoryStore.saveToDisk();

      res.json({
        success: true,
        data: {
          message: 'Table deleted successfully',
        },
      });
    } catch (err) {
      next(err);
    }
  }
);
