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
          isValid: license.isValid,
          status: license.status,
          daysRemaining: license.daysRemaining,
          isOfflineGraceActive: license.isOfflineGraceActive,
          restaurantName: license.restaurantName,
          licenseKey: license.licenseKey,
        },
      },
    },
  });
});
