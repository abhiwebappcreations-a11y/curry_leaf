import os from 'os';
import net from 'net';
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

// GET /api/printers/discover-all - Auto-discover both Windows Spooler USB printers & LAN Wi-Fi Port 9100 printers
printersRouter.get('/discover-all', async (req: Request, res: Response) => {
  const discovered: Array<{ name: string; target: string; type: 'usb' | 'network'; description: string }> = [];
  const discoveredTargets = new Set<string>();

  // 1. Windows Spooler Printers (USB / Driver)
  if (process.platform === 'win32') {
    try {
      const output = execSync('powershell -NoProfile -Command "(Get-CimInstance Win32_Printer).Name"').toString();
      const winPrinters = output
        .split(/\r?\n/)
        .map((s) => s.trim())
        .filter((s) => s.length > 0 && !s.includes('OneNote') && !s.includes('Fax') && !s.includes('XPS Document'));
      for (const p of winPrinters) {
        if (!discoveredTargets.has(p)) {
          discoveredTargets.add(p);
          discovered.push({
            name: p,
            target: p,
            type: 'usb',
            description: `USB / Windows Driver (${p})`,
          });
        }
      }
    } catch (_) {}
  }

  // 2. Wi-Fi / Ethernet Network Scan (Port 9100 - RAW Thermal ESC/POS)
  try {
    const candidateIps = new Set<string>();

    // A. Read active ARP cache (instant list of alive devices on the LAN)
    if (process.platform === 'win32') {
      try {
        const arpOutput = execSync('arp -a', { timeout: 1500 }).toString();
        const ipRegex = /\b(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\b/g;
        let match;
        while ((match = ipRegex.exec(arpOutput)) !== null) {
          const ip = match[1];
          if (
            !ip.startsWith('127.') &&
            !ip.startsWith('169.254.') &&
            !ip.startsWith('224.') &&
            !ip.startsWith('239.') &&
            !ip.endsWith('.255') &&
            ip !== '255.255.255.255'
          ) {
            candidateIps.add(ip);
          }
        }
      } catch (_) {}
    }

    // B. Known default static IPs for Ethernet thermal printers (Epson, Posiflex, Rongta, Everycom, TVS, Xprinter)
    const factoryDefaultIps = [
      '192.168.1.45',    // Epson TM-T82X active static IP
      '192.168.192.168', // Epson TM-T82 / TM-T88 default static
      '192.168.1.200',   // Rongta / Xprinter / Everycom default static
      '192.168.1.100',   // Citizen / Posiflex default static
      '192.168.1.87',    // Hoin default static
      '192.168.0.200',
      '192.168.0.100',
      '192.168.123.100',
    ];
    for (const fIp of factoryDefaultIps) {
      candidateIps.add(fIp);
    }

    // C. All active IPv4 network interface subnets (Wi-Fi, Ethernet)
    const ifaces = os.networkInterfaces();
    const activeSubnets = new Set<string>();
    for (const name of Object.keys(ifaces)) {
      for (const iface of ifaces[name] || []) {
        if (iface.family === 'IPv4' && !iface.internal) {
          const ip = iface.address;
          if (!ip.startsWith('127.') && !ip.startsWith('169.254.')) {
            const parts = ip.split('.');
            activeSubnets.add(parts.slice(0, 3).join('.'));
          }
        }
      }
    }

    // Helper to probe an IP on port 9100 with timeout
    const probeIp = (ip: string, timeoutMs = 700): Promise<boolean> => {
      return new Promise((resolve) => {
        const s = new net.Socket();
        let resolved = false;

        const done = (success: boolean) => {
          if (!resolved) {
            resolved = true;
            s.destroy();
            resolve(success);
          }
        };

        s.setTimeout(timeoutMs);
        s.once('connect', () => done(true));
        s.once('timeout', () => done(false));
        s.once('error', () => done(false));

        try {
          s.connect(9100, ip);
        } catch (_) {
          done(false);
        }
      });
    };

    // Phase 1: Rapidly probe high-priority ARP and factory default IPs
    const priorityIps = Array.from(candidateIps);
    const priorityResults = await Promise.all(
      priorityIps.map(async (ip) => {
        const ok = await probeIp(ip, 800);
        return { ip, ok };
      })
    );

    for (const res of priorityResults) {
      if (res.ok) {
        const target = `${res.ip}:9100`;
        if (!discoveredTargets.has(target)) {
          discoveredTargets.add(target);
          discovered.push({
            name: `Wi-Fi / Ethernet Printer (${res.ip})`,
            target,
            type: 'network',
            description: `Network ESC/POS Printer (${res.ip}:9100)`,
          });
        }
      }
    }

    // Phase 2: If no network printer found in priority list, sweep full active subnets in chunks
    if (discovered.filter((d) => d.type === 'network').length === 0) {
      for (const subnet of activeSubnets) {
        const subnetIps: string[] = [];
        for (let i = 1; i <= 254; i++) {
          const ip = `${subnet}.${i}`;
          if (!candidateIps.has(ip)) {
            subnetIps.push(ip);
          }
        }

        // Run in batches of 32 to respect Windows socket queue
        const chunkSize = 32;
        for (let i = 0; i < subnetIps.length; i += chunkSize) {
          const chunk = subnetIps.slice(i, i + chunkSize);
          const chunkResults = await Promise.all(
            chunk.map(async (ip) => {
              const ok = await probeIp(ip, 650);
              return { ip, ok };
            })
          );
          for (const res of chunkResults) {
            if (res.ok) {
              const target = `${res.ip}:9100`;
              if (!discoveredTargets.has(target)) {
                discoveredTargets.add(target);
                discovered.push({
                  name: `Wi-Fi / Ethernet Printer (${res.ip})`,
                  target,
                  type: 'network',
                  description: `Network ESC/POS Printer (${res.ip}:9100)`,
                });
              }
            }
          }
          if (discovered.filter((d) => d.type === 'network').length > 0) {
            break; // Found printer, stop further subnet scanning
          }
        }
      }
    }
  } catch (_) {}

  res.json({
    success: true,
    data: {
      discovered,
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
    } else {
      // In 2-printer mode, ensure kitchenKot is not pointing to an invalid dead IP
      if (!config.printers.kitchenKot.target || config.printers.kitchenKot.target === '192.168.1.201:9100') {
        config.printers.kitchenKot.target = config.printers.counterBill.target;
      }
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
