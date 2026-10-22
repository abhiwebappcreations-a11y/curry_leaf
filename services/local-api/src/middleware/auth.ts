import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { config } from '../config/index.js';
import { UnauthorizedError, ForbiddenError, LicenseExpiredError } from '../utils/errors.js';
import { LicenseService } from '../services/licenseService.js';
import { inMemoryStore, DeviceRecord } from '../db/inMemoryStore.js';

export interface AuthenticatedDevice {
  id: string;
  name: string;
  role: 'captain' | 'counter' | 'admin';
}

declare global {
  namespace Express {
    interface Request {
      device?: AuthenticatedDevice;
    }
  }
}

export function authenticateDevice(req: Request, res: Response, next: NextFunction) {
  const authHeader = req.headers.authorization;
  const deviceIdHeader = req.headers['x-device-id'] as string;
  const apiKeyHeader = req.headers['x-api-key'] as string;

  // 1. Check Bearer JWT token if provided
  if (authHeader && authHeader.startsWith('Bearer ')) {
    const token = authHeader.substring(7);
    try {
      const decoded = jwt.verify(token, config.jwt.secret) as {
        deviceId: string;
        name: string;
        role: 'captain' | 'counter' | 'admin';
      };
      req.device = {
        id: decoded.deviceId,
        name: decoded.name,
        role: decoded.role,
      };
      return next();
    } catch {
      return next(new UnauthorizedError('Invalid or expired authentication token'));
    }
  }

  // 2. Check Device ID + API key headers for direct LAN device calls
  if (deviceIdHeader) {
    const device = inMemoryStore.devices.get(deviceIdHeader);
    if (!device || !device.isActive) {
      return next(new UnauthorizedError('Device is not registered or is deactivated'));
    }

    if (apiKeyHeader && device.apiKeyHash !== apiKeyHeader) {
      return next(new UnauthorizedError('Invalid device credentials'));
    }

    req.device = {
      id: device.id,
      name: device.deviceName,
      role: device.role,
    };
    return next();
  }

  // 3. In development mode, allow default counter identification if no headers provided
  if (config.env === 'development') {
    const defaultDev = inMemoryStore.devices.get('dev_counter_01');
    if (defaultDev) {
      req.device = {
        id: defaultDev.id,
        name: defaultDev.deviceName,
        role: defaultDev.role,
      };
      return next();
    }
  }

  return next(new UnauthorizedError('Authentication required: provide Bearer token or X-Device-Id'));
}

export function requireRole(...allowedRoles: Array<'captain' | 'counter' | 'admin'>) {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!req.device) {
      return next(new UnauthorizedError());
    }

    if (!allowedRoles.includes(req.device.role)) {
      return next(
        new ForbiddenError(`Device role '${req.device.role}' is not authorized for this operation`)
      );
    }

    next();
  };
}


export async function requireActiveLicense(req: Request, res: Response, next: NextFunction) {
  try {
    const licenseStatus = await LicenseService.getLicenseStatus();
    if (!licenseStatus.isValid) {
      const msg = licenseStatus.status === 'suspended'
        ? 'Hinopt POS subscription is suspended. KOT, billing, and ordering are disabled.'
        : 'Hinopt POS subscription has expired. KOT, billing, and ordering are disabled. Please renew with Hinopt Admin.';
      return next(new LicenseExpiredError(msg));
    }
    next();
  } catch (err) {
    next(err);
  }
}
