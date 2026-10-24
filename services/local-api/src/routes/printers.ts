import { execSync } from 'child_process';
import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { PrintService } from '../services/printService.js';
import { config } from '../config/index.js';
import { inMemoryStore } from '../db/inMemoryStore.js';
import { authenticateDevice, requireRole, requireActiveLicense } from '../middleware/auth.js';
import { validateBody } from '../middleware/validate.js';

export const printersRouter = Router();

printersRouter.use(authenticateDevice);

// GET /api/printers/system-devices - Detect installed Windows USB printers
printersRouter.get('/system-devices', (req: Request, res: Response) => {
  let devices: string[] = [];
  try {
    if (process.platform === 'win32') {
      const output = execSync('powershell -NoProfile -Command "(Get-CimInstance Win32_Printer).Name"').toString();
      devices = output
        .split(/\r?\n/)
        .map((s) => s.trim())
        .filter((s) => s.length > 0);
    }
  } catch (_) {}

  res.json({
    success: true,
    data: {
      devices,
    },
  });
});

// GET /api/printers - List printer configurations
printersRouter.get('/', (req: Request, res: Response) => {
  // Connection type detection:
  //   target contains ':' => 'host:port' Ethernet (e.g. '192.168.1.200:9100')
  //   target has no ':'  => Windows printer name (e.g. 'EPSON TM-T82X Receipt')
  const getConnType = (target: string) => target.includes(':') ? 'network' : 'usb';



  res.json({
    success: true,
    data: {
      printerMode: config.printers.printerMode || 'single',
      printers: [
        {
          id: 'counter_bill',
          name: 'Counter Bill Thermal Printer',
          target: config.printers.counterBill.target,
          paperWidth: config.printers.counterBill.paperWidth,
          connectionType: getConnType(config.printers.counterBill.target),
          status: 'ready',
        },
        {
          id: 'kitchen_kot',
          name: 'Kitchen KOT Thermal Printer',
          target: config.printers.kitchenKot.target,
          paperWidth: config.printers.kitchenKot.paperWidth,
          connectionType: getConnType(config.printers.kitchenKot.target),
          status: 'ready',
        },
      ],
    },
  });
});


const updateModeSchema = z.object({
  mode: z.enum(['single', 'double']),
});

// POST /api/printers/mode - Toggle between Single vs Double printer mode
printersRouter.post(
  '/mode',
  requireActiveLicense,
  requireRole('counter', 'admin'),
  validateBody(updateModeSchema),
  (req: Request, res: Response) => {
    const { mode } = req.body;
    config.printers.printerMode = mode;
    if (mode === 'single') {
      config.printers.kitchenKot.target = config.printers.counterBill.target;
      config.printers.kitchenKot.paperWidth = config.printers.counterBill.paperWidth;
    }
    inMemoryStore.settings.set('printer_settings', {
      mode,
      counterBill: config.printers.counterBill,
      kitchenKot: config.printers.kitchenKot,
    });
    inMemoryStore.saveToDisk();

    res.json({
      success: true,
      data: {
        printerMode: config.printers.printerMode,
      },
    });
  }
);

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
