import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { inMemoryStore, DeviceRecord } from '../db/inMemoryStore.js';
import { NotFoundError } from '../utils/errors.js';
import { authenticateDevice, requireRole } from '../middleware/auth.js';
import { validateBody } from '../middleware/validate.js';
import { getLanIpv4Address } from '../services/discoveryService.js';
import { config } from '../config/index.js';

export const devicesRouter = Router();

// GET /api/devices/lan-info - Counter Wi-Fi LAN IP & Pairing QR info
devicesRouter.get('/lan-info', (req: Request, res: Response) => {
  const host = getLanIpv4Address();
  const port = config.port || 4000;
  const restaurantName = config.restaurantName || 'Curry Leaf Fine Dining';

  res.json({
    success: true,
    data: {
      host,
      port,
      restaurantName,
      apiUrl: `http://${host}:${port}/api`,
      qrData: JSON.stringify({
        type: 'hinopt_counter_pos',
        host,
        port,
        restaurantName,
      }),
    },
  });
});

const pairRequestSchema = z.object({
  deviceId: z.string().min(1),
  deviceName: z.string().min(1),
  deviceRole: z.enum(['captain', 'counter', 'admin']).default('captain'),
  deviceFingerprint: z.string().optional(),
});

// POST /api/devices/pair-request - Captain phones call this to request pairing with Counter
devicesRouter.post(
  '/pair-request',
  validateBody(pairRequestSchema),
  (req: Request, res: Response, next: NextFunction) => {
    try {
      const { deviceId, deviceName, deviceRole, deviceFingerprint } = req.body;
      const clientIp = (req.headers['x-forwarded-for'] as string) || req.socket.remoteAddress || '';

      const existing = inMemoryStore.devices.get(deviceId);
      if (existing) {
        if (existing.status === 'approved' || existing.isActive) {
          existing.lastSeenAt = new Date().toISOString();
          existing.deviceIp = clientIp;
          inMemoryStore.saveToDisk();

          return res.json({
            success: true,
            data: {
              status: 'approved',
              deviceId: existing.id,
              deviceName: existing.deviceName,
              apiKey: existing.apiKeyHash,
              message: 'Device already approved.',
            },
          });
        }

        if (existing.status === 'rejected') {
          return res.json({
            success: true,
            data: {
              status: 'rejected',
              deviceId: existing.id,
              message: 'This device was declined by the Counter manager.',
            },
          });
        }

        // Still pending
        existing.deviceName = deviceName;
        existing.deviceIp = clientIp;
        inMemoryStore.saveToDisk();

        return res.json({
          success: true,
          data: {
            status: 'pending',
            deviceId: existing.id,
            message: 'Waiting for Counter Manager approval on Counter POS screen.',
          },
        });
      }

      // Create new pending device record
      const token = `cap_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
      const newDevice: DeviceRecord = {
        id: deviceId,
        deviceName,
        role: deviceRole,
        deviceFingerprint: deviceFingerprint || `fp_${Date.now()}`,
        apiKeyHash: token,
        isActive: false,
        status: 'pending',
        deviceIp: clientIp,
        registeredAt: new Date().toISOString(),
        lastSeenAt: new Date().toISOString(),
      };

      inMemoryStore.devices.set(newDevice.id, newDevice);
      inMemoryStore.saveToDisk();

      res.status(202).json({
        success: true,
        data: {
          status: 'pending',
          deviceId: newDevice.id,
          message: 'Pairing request registered. Waiting for Counter Manager approval on Counter POS screen.',
        },
      });
    } catch (err) {
      next(err);
    }
  }
);

// GET /api/devices/pair-status/:deviceId - Captain phone polls this while waiting for Counter approval
devicesRouter.get('/pair-status/:deviceId', (req: Request, res: Response, next: NextFunction) => {
  try {
    const deviceId = req.params.deviceId as string;
    const device = inMemoryStore.devices.get(deviceId);

    if (!device) {
      return res.json({
        success: true,
        data: {
          status: 'unknown',
          message: 'Device not registered yet.',
        },
      });
    }

    res.json({
      success: true,
      data: {
        status: device.status || (device.isActive ? 'approved' : 'pending'),
        apiKey: device.isActive ? device.apiKeyHash : null,
        deviceName: device.deviceName,
      },
    });
  } catch (err) {
    next(err);
  }
});

// Protected routes below (Counter POS management)
devicesRouter.use(authenticateDevice);

// GET /api/devices/pending - Counter POS polls this to detect new pairing requests
devicesRouter.get('/pending', requireRole('counter', 'admin'), (req: Request, res: Response) => {
  const pending = Array.from(inMemoryStore.devices.values()).filter(
    (d) => d.status === 'pending' && !d.isActive
  );

  res.json({
    success: true,
    data: {
      devices: pending,
      count: pending.length,
    },
  });
});

// POST /api/devices/:id/approve - Counter POS manager approves Captain device
devicesRouter.post('/:id/approve', requireRole('counter', 'admin'), (req: Request, res: Response, next: NextFunction) => {
  try {
    const id = req.params.id as string;
    const device = inMemoryStore.devices.get(id);
    if (!device) {
      throw new NotFoundError('Device', id);
    }

    device.isActive = true;
    device.status = 'approved';
    device.lastSeenAt = new Date().toISOString();
    inMemoryStore.saveToDisk();

    res.json({
      success: true,
      data: {
        message: `Device "${device.deviceName}" approved successfully.`,
        device,
      },
    });
  } catch (err) {
    next(err);
  }
});

// POST /api/devices/:id/reject - Counter POS manager rejects Captain device
devicesRouter.post('/:id/reject', requireRole('counter', 'admin'), (req: Request, res: Response, next: NextFunction) => {
  try {
    const id = req.params.id as string;
    const device = inMemoryStore.devices.get(id);
    if (!device) {
      throw new NotFoundError('Device', id);
    }

    device.isActive = false;
    device.status = 'rejected';
    inMemoryStore.saveToDisk();

    res.json({
      success: true,
      data: {
        message: `Device "${device.deviceName}" rejected.`,
      },
    });
  } catch (err) {
    next(err);
  }
});

// GET /api/devices - List all registered devices
devicesRouter.get('/', requireRole('counter', 'admin'), (req: Request, res: Response) => {
  const allDevices = Array.from(inMemoryStore.devices.values());
  res.json({
    success: true,
    data: {
      devices: allDevices,
    },
  });
});

// DELETE /api/devices/:id - Revoke and remove a device
devicesRouter.delete('/:id', requireRole('counter', 'admin'), (req: Request, res: Response, next: NextFunction) => {
  try {
    const id = req.params.id as string;
    inMemoryStore.devices.delete(id);
    inMemoryStore.saveToDisk();

    res.json({
      success: true,
      data: {
        message: `Device ${id} deleted successfully.`,
      },
    });
  } catch (err) {
    next(err);
  }
});
