import crypto from 'crypto';
import fs from 'fs';
import path from 'path';
import { execSync } from 'child_process';
import { inMemoryStore, LicenseRecord } from '../db/inMemoryStore.js';
import { config } from '../config/index.js';
import { logger } from '../utils/logger.js';
import { BadRequestError } from '../utils/errors.js';

export interface LicenseStatusResult {
  isValid: boolean;
  status: 'active' | 'grace' | 'expired' | 'suspended';
  restaurantId: string;
  restaurantName: string;
  licenseKey: string;
  validFrom: string;
  validUntil: string;
  daysRemaining: number;
  isOfflineGraceActive: boolean;
  features: string[];
}

export class LicenseService {
  public static async loadLicenseFromDisk(): Promise<void> {
    const candidatePaths = [
      process.env.LICENSE_FILE_PATH,
      path.resolve(process.cwd(), 'license.json'),
      path.resolve(process.cwd(), 'config/license.json'),
      path.resolve(process.cwd(), '../config/license.json'),
      path.resolve(process.cwd(), '../../config/license.json'),
    ].filter(Boolean) as string[];

    let foundPath: string | null = null;
    for (const p of candidatePaths) {
      if (fs.existsSync(p)) {
        foundPath = p;
        break;
      }
    }

    // Auto-scan for downloaded license tokens like hinopt_license_<id>.json or *.license.json
    if (!foundPath) {
      const searchDirs = [
        process.cwd(),
        path.resolve(process.cwd(), 'config'),
        path.resolve(process.cwd(), '..'),
        path.resolve(process.cwd(), '../config'),
        path.resolve(process.cwd(), '../../'),
      ];
      for (const dir of searchDirs) {
        if (fs.existsSync(dir)) {
          const files = fs.readdirSync(dir);
          const licenseFile = files.find(f => f.toLowerCase().includes('license') && f.endsWith('.json'));
          if (licenseFile) {
            foundPath = path.join(dir, licenseFile);
            break;
          }
        }
      }
    }

    if (!foundPath) {
      logger.info('No license.json file found on disk. Using in-memory configuration.');
      return;
    }

    try {
      const content = fs.readFileSync(foundPath, 'utf-8');
      const data = JSON.parse(content);
      const payload = data.signedPayload || data;

      const restName = payload.restaurantName || payload.name || config.restaurantName;
      const restId = payload.restaurantId || payload.id || config.restaurantId;
      const hwid = payload.hardwareId || payload.hwid || '';
      const licenseKey = payload.licenseKey || payload.key || 'HINOPT-LIC-ACTIVE';
      const validFrom = payload.validFrom || payload.issuedAt || new Date().toISOString();
      const validUntil = payload.validUntil || payload.expiresAt || new Date(Date.now() + 365 * 86400000).toISOString();
      let status: 'active' | 'grace' | 'expired' | 'suspended' = (payload.status || 'active').toLowerCase();

      // Anti-Piracy Hardware ID check on Windows
      if (hwid && process.platform === 'win32') {
        try {
          const sysHwid = execSync('powershell -NoProfile -Command "(Get-CimInstance Win32_ComputerSystemProduct).UUID"').toString().trim();
          if (sysHwid && hwid.toUpperCase() !== sysHwid.toUpperCase()) {
            logger.warn(
              { expectedHwid: hwid, actualHwid: sysHwid },
              'Hardware ID mismatch! License is bound to a different machine motherboard.'
            );
            status = 'suspended';
          }
        } catch (_) {}
      }

      inMemoryStore.license = {
        id: 'disk_license',
        restaurantId: restId,
        restaurantName: restName,
        licenseKey: licenseKey,
        status: status,
        validFrom: validFrom,
        validUntil: validUntil,
        lastVerifiedAt: new Date().toISOString(),
        signature: data.signature || 'disk_sig',
        signedPayload: payload,
      };

      // Personalize restaurant profile dynamically so bills, KOTs, receipts use new client name
      inMemoryStore.settings.set('restaurant_profile', {
        restaurantId: restId,
        name: restName,
        tagline: payload.tagline || 'Fine Dining & Hospitality',
        address: payload.city || payload.address || 'Main Branch',
        phone: payload.phone || '+91 98490 00000',
        gstin: payload.gstin || '36AABCU9603R1ZM',
        currency: 'INR',
      });

      logger.info({ path: foundPath, restaurantName: restName, licenseKey, status }, 'Loaded personalized license from disk');
    } catch (err: any) {
      logger.error({ err }, 'Failed to parse license.json from disk');
    }
  }

  public static async getLicenseStatus(): Promise<LicenseStatusResult> {
    const license = inMemoryStore.license;
    if (!license) {
      return {
        isValid: false,
        status: 'expired',
        restaurantId: config.restaurantId,
        restaurantName: config.restaurantName,
        licenseKey: 'NONE',
        validFrom: new Date(0).toISOString(),
        validUntil: new Date(0).toISOString(),
        daysRemaining: 0,
        isOfflineGraceActive: false,
        features: [],
      };
    }

    const now = Date.now();
    const expiryTime = new Date(license.validUntil).getTime();
    const validFromTime = new Date(license.validFrom).getTime();

    // Anti-Tamper Check 1: System clock is set to before license issuance
    if (now < validFromTime) {
      logger.warn({ now: new Date(now).toISOString(), validFrom: license.validFrom }, 'Clock rollback detected before validFrom');
      return {
        isValid: false,
        status: 'suspended',
        restaurantId: license.restaurantId,
        restaurantName: license.restaurantName,
        licenseKey: license.licenseKey,
        validFrom: license.validFrom,
        validUntil: license.validUntil,
        daysRemaining: 0,
        isOfflineGraceActive: false,
        features: [],
      };
    }

    // Anti-Tamper Check 2: System clock is set backwards behind existing transactions
    let latestRecordedTimeMs = new Date(license.lastVerifiedAt).getTime();
    for (const order of inMemoryStore.orders.values()) {
      const orderTime = new Date(order.createdAt).getTime();
      if (orderTime > latestRecordedTimeMs) latestRecordedTimeMs = orderTime;
    }
    for (const bill of inMemoryStore.bills.values()) {
      const billTime = new Date(bill.createdAt).getTime();
      if (billTime > latestRecordedTimeMs) latestRecordedTimeMs = billTime;
    }

    if (now < latestRecordedTimeMs - 5 * 60 * 1000) {
      logger.warn(
        { now: new Date(now).toISOString(), latestRecordedTime: new Date(latestRecordedTimeMs).toISOString() },
        'System clock rollback detected! Local time is behind historical transactions.'
      );
      return {
        isValid: false,
        status: 'suspended',
        restaurantId: license.restaurantId,
        restaurantName: license.restaurantName,
        licenseKey: license.licenseKey,
        validFrom: license.validFrom,
        validUntil: license.validUntil,
        daysRemaining: 0,
        isOfflineGraceActive: false,
        features: [],
      };
    }

    const diffMs = expiryTime - now;
    const daysRemaining = Math.ceil(diffMs / (1000 * 60 * 60 * 24));

    let effectiveStatus: 'active' | 'grace' | 'expired' | 'suspended' = license.status;

    if (effectiveStatus !== 'suspended') {
      if (diffMs > 0) {
        effectiveStatus = 'active';
      } else {
        const graceMs = config.license.offlineGraceDays * 24 * 60 * 60 * 1000;
        if (Math.abs(diffMs) <= graceMs) {
          effectiveStatus = 'grace';
        } else {
          effectiveStatus = 'expired';
        }
      }
    }

    const isValid = effectiveStatus === 'active' || effectiveStatus === 'grace';

    return {
      isValid,
      status: effectiveStatus,
      restaurantId: license.restaurantId,
      restaurantName: license.restaurantName,
      licenseKey: license.licenseKey,
      validFrom: license.validFrom,
      validUntil: license.validUntil,
      daysRemaining: Math.max(0, daysRemaining),
      isOfflineGraceActive: effectiveStatus === 'grace',
      features: (license.signedPayload.features as string[]) || ['pos', 'kot', 'billing'],
    };
  }

  public static async verifyAndApplyLicense(
    signedPayloadBase64: string,
    signatureHex: string
  ): Promise<LicenseStatusResult> {
    let payloadJson: any;
    try {
      const decodedString = Buffer.from(signedPayloadBase64, 'base64').toString('utf-8');
      payloadJson = JSON.parse(decodedString);
    } catch {
      throw new BadRequestError('Invalid license payload format: not valid base64 JSON');
    }

    // Verify asymmetric signature with Hinopt Public Key if configured
    if (config.license.publicKeyPem) {
      try {
        const dataBuffer = Buffer.from(signedPayloadBase64);
        const signatureBuffer = Buffer.from(signatureHex, 'hex');

        let isSignatureValid = false;
        try {
          // Native Ed25519 verification (algorithm: null)
          isSignatureValid = crypto.verify(null, dataBuffer, config.license.publicKeyPem, signatureBuffer);
        } catch {
          // Fallback to SHA256 verification for RSA / ECDSA
          const verify = crypto.createVerify('SHA256');
          verify.update(signedPayloadBase64);
          verify.end();
          isSignatureValid = verify.verify(config.license.publicKeyPem, signatureBuffer);
        }

        if (!isSignatureValid) {
          throw new BadRequestError('Cryptographic license signature verification failed');
        }
      } catch (err: any) {
        logger.error({ err }, 'License verification cryptographic error');
        throw new BadRequestError(
          `License verification failed: ${err.message || 'Signature mismatch'}`
        );
      }
    } else {
      logger.warn('LICENSE_PUBLIC_KEY_PEM not set. Simulating verified license update.');
    }

    const updatedLicense: LicenseRecord = {
      id: 'current_license',
      restaurantId: payloadJson.restaurantId,
      restaurantName: payloadJson.restaurantName || config.restaurantName,
      licenseKey: payloadJson.licenseKey,
      status: payloadJson.status || 'active',
      validFrom: payloadJson.validFrom,
      validUntil: payloadJson.validUntil,
      lastVerifiedAt: new Date().toISOString(),
      signature: signatureHex,
      signedPayload: payloadJson,
    };

    inMemoryStore.license = updatedLicense;

    // Update restaurant profile name
    inMemoryStore.settings.set('restaurant_profile', {
      restaurantId: updatedLicense.restaurantId,
      name: updatedLicense.restaurantName,
      tagline: 'Fine Dining & Hospitality',
      address: payloadJson.city || 'Main Branch',
      phone: payloadJson.phone || '+91 98490 00000',
      gstin: '36AABCU9603R1ZM',
      currency: 'INR',
    });

    inMemoryStore.auditLogs.push({
      id: `audit_${Date.now()}`,
      eventType: 'license_verified_and_applied',
      entityType: 'license',
      entityId: updatedLicense.licenseKey,
      details: {
        restaurantId: updatedLicense.restaurantId,
        validUntil: updatedLicense.validUntil,
        status: updatedLicense.status,
      },
      createdAt: new Date().toISOString(),
    });

    return this.getLicenseStatus();
  }

  public static getSystemHardwareId(): string {
    if (process.platform === 'win32') {
      try {
        const out = execSync('powershell -NoProfile -Command "(Get-CimInstance Win32_ComputerSystemProduct).UUID"').toString().trim();
        if (out) return out;
      } catch (_) {}
    }
    return 'HWID-LOCAL-DEV-NODE';
  }

  public static async performHeartbeat(): Promise<{ online: boolean; status: string; message?: string }> {
    const license = inMemoryStore.license;
    if (!license) return { online: false, status: 'no_license' };

    const adminUrl = process.env.HINOPT_ADMIN_URL || 'http://127.0.0.1:5000';
    const hwid = this.getSystemHardwareId();

    try {
      const resp = await fetch(`${adminUrl}/api/license/heartbeat`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          licenseKey: license.licenseKey,
          hwid,
          timestamp: new Date().toISOString(),
        }),
      });

      if (resp.ok) {
        const data = (await resp.json()) as any;
        if (data.status === 'revoked') {
          license.status = 'suspended';
          inMemoryStore.saveToDisk();
          logger.error('CRITICAL: License revoked by Hinopt Cloud — Terminal deactivated');
          return { online: true, status: 'revoked', message: data.message };
        }

        inMemoryStore.settings.set('license_heartbeat', {
          lastOnlineAt: new Date().toISOString(),
          status: 'verified',
        });
        inMemoryStore.saveToDisk();
        return { online: true, status: 'active' };
      }
    } catch (_) {}

    return { online: false, status: license.status };
  }
}
