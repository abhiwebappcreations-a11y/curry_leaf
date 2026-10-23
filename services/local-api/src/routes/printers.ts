import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { PrintService } from '../services/printService.js';
import { config } from '../config/index.js';
import { inMemoryStore } from '../db/inMemoryStore.js';
import { authenticateDevice, requireRole, requireActiveLicense } from '../middleware/auth.js';
import { validateBody } from '../middleware/validate.js';

export const printersRouter = Router();

printersRouter.use(authenticateDevice);

// GET /api/printers - List printer configurations
printersRouter.get('/', (req: Request, res: Response) => {
  res.json({
    success: true,
    data: {
      printers: [
        {
          id: 'counter_bill',
          name: 'Counter Bill Thermal Printer',
          target: config.printers.counterBill.target,
          paperWidth: config.printers.counterBill.paperWidth,
          connectionType: 'network',
          status: 'ready',
        },
        {
          id: 'kitchen_kot',
          name: 'Kitchen KOT Thermal Printer',
          target: config.printers.kitchenKot.target,
          paperWidth: config.printers.kitchenKot.paperWidth,
          connectionType: 'network',
          status: 'ready',
        },
      ],
    },
  });
});

const updatePrinterSchema = z.object({
  target: z.string().min(3),
  paperWidth: z.string().optional(),
});

// PATCH /api/printers/:id - Update printer target IP / port (Counter / Admin only)
printersRouter.patch(
  '/:id',
  requireActiveLicense,
  requireRole('counter', 'admin'),
  validateBody(updatePrinterSchema),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { id } = req.params;
      const { target, paperWidth } = req.body;

      if (id === 'counter_bill' || id.includes('bill') || id.includes('counter')) {
        config.printers.counterBill.target = target;
        if (paperWidth) config.printers.counterBill.paperWidth = paperWidth;
        inMemoryStore.settings.set('printer_counter_bill', { target, paperWidth });
      } else if (id === 'kitchen_kot' || id.includes('kot') || id.includes('kitchen')) {
        config.printers.kitchenKot.target = target;
        if (paperWidth) config.printers.kitchenKot.paperWidth = paperWidth;
        inMemoryStore.settings.set('printer_kitchen_kot', { target, paperWidth });
      }

      res.json({
        success: true,
        data: {
          id,
          target,
          paperWidth: paperWidth || '80mm',
          message: 'Printer target IP and configuration updated successfully',
        },
      });
    } catch (err) {
      next(err);
    }
  }
);

const testPrintSchema = z.object({
  targetPrinter: z.enum(['counter_bill', 'kitchen_kot']),
});

// POST /api/printers/test-print - Trigger test print (Counter / Admin only)
printersRouter.post(
  '/test-print',
  requireActiveLicense,
  requireRole('counter', 'admin'),
  validateBody(testPrintSchema),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const job = await PrintService.enqueueJob(
        req.body.targetPrinter,
        'test_print',
        undefined,
        {
          title: '*** PRINTER TEST SLIP ***',
          restaurant: config.restaurantName,
          printer: req.body.targetPrinter,
          triggeredAt: new Date().toISOString(),
          message: 'Local thermal print queue operational',
        },
        false
      );

      res.status(201).json({
        success: true,
        data: {
          job,
        },
      });
    } catch (err) {
      next(err);
    }
  }
);

// GET /api/printers/jobs - Inspect print queue jobs
printersRouter.get('/jobs', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { status } = req.query;
    const jobs = await PrintService.listJobs(
      typeof status === 'string' ? status : undefined
    );
    res.json({
      success: true,
      data: {
        jobs,
      },
    });
  } catch (err) {
    next(err);
  }
});

// POST /api/printers/jobs/:id/retry - Retry failed print job (Counter / Admin only)
printersRouter.post(
  '/jobs/:id/retry',
  requireActiveLicense,
  requireRole('counter', 'admin'),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const job = await PrintService.retryJob(req.params.id as string);
      res.json({
        success: true,
        data: {
          job,
        },
      });
    } catch (err) {
      next(err);
    }
  }
);
