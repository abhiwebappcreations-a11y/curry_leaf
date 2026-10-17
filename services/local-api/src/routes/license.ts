import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { LicenseService } from '../services/licenseService.js';
import { authenticateDevice, requireRole } from '../middleware/auth.js';
import { validateBody } from '../middleware/validate.js';

export const licenseRouter = Router();

licenseRouter.use(authenticateDevice);

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
