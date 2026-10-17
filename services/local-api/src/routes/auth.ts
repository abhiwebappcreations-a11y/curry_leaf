import { Router, Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { z } from 'zod';
import { inMemoryStore, DeviceRecord } from '../db/inMemoryStore.js';
import { config } from '../config/index.js';
import { UnauthorizedError, BadRequestError } from '../utils/errors.js';
import { validateBody } from '../middleware/validate.js';
import { authenticateDevice, requireRole } from '../middleware/auth.js';

export const authRouter = Router();

const tokenSchema = z.object({
  deviceId: z.string().min(1),
  apiKey: z.string().min(1),
});

const registerDeviceSchema = z.object({
  deviceId: z.string().min(3),
  deviceName: z.string().min(2),
  role: z.enum(['captain', 'counter', 'admin']),
  deviceFingerprint: z.string().min(3),
  apiKey: z.string().min(8),
});

// Exchange device ID & key for JWT
authRouter.post(
  '/token',
  validateBody(tokenSchema),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { deviceId, apiKey } = req.body;
      const device = inMemoryStore.devices.get(deviceId);

      if (!device || !device.isActive) {
        throw new UnauthorizedError('Device is not registered or is deactivated');
      }

      if (device.apiKeyHash !== apiKey) {
        throw new UnauthorizedError('Invalid device credentials');
      }

      const token = jwt.sign(
        {
          deviceId: device.id,
          name: device.deviceName,
          role: device.role,
        },
        config.jwt.secret,
        { expiresIn: config.jwt.expiresIn as any }
      );

      device.lastSeenAt = new Date().toISOString();

      res.json({
        success: true,
        data: {
          token,
          device: {
            id: device.id,
            name: device.deviceName,
            role: device.role,
          },
        },
      });
    } catch (err) {
      next(err);
    }
  }
);

// Get current device identity
authRouter.get('/me', authenticateDevice, (req: Request, res: Response) => {
  res.json({
    success: true,
    data: {
      device: req.device,
    },
  });
});

// Register a new device (Admin only)
authRouter.post(
  '/register-device',
  authenticateDevice,
  requireRole('admin'),
  validateBody(registerDeviceSchema),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { deviceId, deviceName, role, deviceFingerprint, apiKey } = req.body;

      if (inMemoryStore.devices.has(deviceId)) {
        throw new BadRequestError(`Device with ID '${deviceId}' already exists`);
      }

      const newDevice: DeviceRecord = {
        id: deviceId,
        deviceName,
        role,
        deviceFingerprint,
        apiKeyHash: apiKey,
        isActive: true,
        registeredAt: new Date().toISOString(),
      };

      inMemoryStore.devices.set(newDevice.id, newDevice);

      res.status(201).json({
        success: true,
        data: {
          device: {
            id: newDevice.id,
            name: newDevice.deviceName,
            role: newDevice.role,
          },
        },
      });
    } catch (err) {
      next(err);
    }
  }
);
