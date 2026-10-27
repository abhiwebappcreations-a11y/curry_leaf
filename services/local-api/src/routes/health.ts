import { Router, Request, Response } from 'express';
import { db } from '../db/index.js';
import { inMemoryStore } from '../db/inMemoryStore.js';
import { LicenseService } from '../services/licenseService.js';
import { config } from '../config/index.js';

export const healthRouter = Router();

healthRouter.get('/', async (req: Request, res: Response) => {
  const isPgConnected = await db.checkConnection();
  const license = await LicenseService.getLicenseStatus();

  const printJobs = Array.from(inMemoryStore.printJobs.values());
  const pendingJobs = printJobs.filter((j) => j.status === 'queued' || j.status === 'processing').length;
  const failedJobs = printJobs.filter((j) => j.status === 'failed').length;

  const uptimeSeconds = Math.floor(process.uptime());
  const gstSettings = (inMemoryStore.settings.get('gst_settings') as any) || { enabled: false, ratePercent: 5.0 };

  res.json({
    success: true,
    data: {
      status: 'healthy',
      service: 'hinopt-local-api',
      version: '1.0.0',
      timestamp: new Date().toISOString(),
      uptimeSeconds,
      restaurant: {
        id: license.restaurantId || config.restaurantId,
        name: license.restaurantName || config.restaurantName,
        ownerName: license.ownerName || (inMemoryStore.settings.get('restaurant_profile') as any)?.ownerName || '',
        phone: license.phone || (inMemoryStore.settings.get('restaurant_profile') as any)?.phone || '',
        city: license.city || (inMemoryStore.settings.get('restaurant_profile') as any)?.address || '',
        hwid: license.hwid || license.hardwareId || LicenseService.getSystemHardwareId(),
      },
      gst: {
        enabled: gstSettings.enabled !== false,
        ratePercent: gstSettings.ratePercent ?? 5.0,
        cgstRate: gstSettings.cgstRate ?? 2.5,
        sgstRate: gstSettings.sgstRate ?? 2.5,
        gstin: gstSettings.gstin || '',
      },
      components: {
        apiServer: {
          status: 'online',
          port: config.port,
        },
        database: {
          type: isPgConnected ? 'postgresql' : 'in-memory-operational',
          status: 'connected',
          isPostgreSQL: isPgConnected,
        },
        printers: {
          counterBill: {
            configured: true,
            target: config.printers.counterBill.target,
            paperWidth: config.printers.counterBill.paperWidth,
          },
          kitchenKot: {
            configured: true,
            target: config.printers.kitchenKot.target,
            paperWidth: config.printers.kitchenKot.paperWidth,
          },
          queue: {
            pendingJobs,
            failedJobs,
          },
        },
        license: {
          status: license.status,
          daysRemaining: license.daysRemaining,
          limits: license.limits,
          usage: license.usage,
        },
      },
    },
  });
});
