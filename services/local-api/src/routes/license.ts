import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { LicenseService } from '../services/licenseService.js';
import { authenticateDevice, requireRole } from '../middleware/auth.js';
import { validateBody } from '../middleware/validate.js';

export const licenseRouter = Router();

licenseRouter.use(authenticateDevice);

// GET /api/license/hwid - Inspect local PC Hardware ID
licenseRouter.get('/hwid', async (req: Request, res: Response) => {
  const hwid = LicenseService.getSystemHardwareId();
  res.json({ success: true, data: { hwid } });
});

// POST /api/license/heartbeat - 30-Day Check-in & Cloud Revocation Check
licenseRouter.post('/heartbeat', async (req: Request, res: Response) => {
  const result = await LicenseService.performHeartbeat();
  res.json({ success: true, data: result });
});

// GET /api/license/status - Inspect local license verification status
licenseRouter.get('/status', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const status = await LicenseService.getLicenseStatus();
    res.json({
      success: true,
      data: {
        license: status,
      },
    });
  } catch (err) {
    next(err);
  }
});

const applyLicenseSchema = z.object({
  signedPayloadBase64: z.string().min(10),
  signatureHex: z.string().min(10),
});

const activateKeySchema = z.object({
  licenseKey: z.string().min(5),
});

// POST /api/license/activate-key - Activate or Renew directly by typing/pasting License Key
licenseRouter.post(
  '/activate-key',
  validateBody(activateKeySchema),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const result = await LicenseService.activateLicenseKey(req.body.licenseKey);
      res.json({
        success: true,
        data: {
          license: result,
        },
      });
    } catch (err) {
      next(err);
    }
  }
);

// POST /api/license/verify - Apply renewed / updated license from Hinopt Cloud (Admin only)
licenseRouter.post(
  '/verify',
  requireRole('admin'),
  validateBody(applyLicenseSchema),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const result = await LicenseService.verifyAndApplyLicense(
        req.body.signedPayloadBase64,
        req.body.signatureHex
      );
      res.json({
        success: true,
        data: {
          license: result,
        },
      });
    } catch (err) {
      next(err);
    }
  }
);
