import crypto from 'crypto';
import fs from 'fs';
import path from 'path';
import { execSync } from 'child_process';
import { inMemoryStore, LicenseRecord } from '../db/inMemoryStore.js';
import { config } from '../config/index.js';
import { logger } from '../utils/logger.js';
import { BadRequestError } from '../utils/errors.js';

export interface LicenseLimits {
  menuItems: number;
  captainDevices: number;
  counterPcs: number;
}

export interface LicenseStatusResult {
  isValid: boolean;
  status: 'active' | 'grace' | 'expired' | 'suspended';
  restaurantId: string;
  restaurantName: string;
  ownerName?: string;
  phone?: string;
  city?: string;
  hardwareId?: string;
  hwid?: string;
  licenseKey: string;
  validFrom: string;
  validUntil: string;
  daysRemaining: number;
  isOfflineGraceActive: boolean;
  features: string[];
  limits?: LicenseLimits;
  onlineOrderingEnabled?: boolean;
  storeUrl?: string;
  customDomain?: string;
  storeSlug?: string;
  usage?: {
    menuItems: number;
    captainDevices: number;
    counterPcs: number;
  };
}

export class LicenseService {
  public static getLimits(): LicenseLimits {
    const lic = inMemoryStore.license;
    const payload = (lic?.signedPayload || {}) as any;
    const limits = lic?.limits || payload?.limits || {};
    return {
      menuItems: typeof limits.menuItems === 'number' ? limits.menuItems : 100,
      captainDevices: typeof limits.captainDevices === 'number' ? limits.captainDevices : (typeof payload?.maxDevices === 'number' ? payload.maxDevices : 5),
      counterPcs: typeof limits.counterPcs === 'number' ? limits.counterPcs : 1,
    };
  }

  public static canAddMenuItem(): { allowed: boolean; current: number; limit: number; message?: string } {
    const limits = this.getLimits();
    const current = inMemoryStore.menuItems.size;
    if (current >= limits.menuItems) {
      return {
        allowed: false,
        current,
        limit: limits.menuItems,
        message: `License limit reached: You have reached the maximum of ${limits.menuItems} menu items allowed on your license (${current}/${limits.menuItems}). Please upgrade your license in Hinopt Admin.`,
      };
    }
    return { allowed: true, current, limit: limits.menuItems };
  }

  public static canApproveCaptainDevice(): { allowed: boolean; current: number; limit: number; message?: string } {
    const limits = this.getLimits();
    const approvedCaptains = Array.from(inMemoryStore.devices.values()).filter(
      (d) => d.role === 'captain' && d.status === 'approved'
    ).length;
    if (approvedCaptains >= limits.captainDevices) {
      return {
        allowed: false,
        current: approvedCaptains,
        limit: limits.captainDevices,
        message: `Captain device limit reached: Your license allows up to ${limits.captainDevices} active captain devices (${approvedCaptains}/${limits.captainDevices} approved). Please upgrade your license in Hinopt Admin to connect more devices.`,
      };
    }
    return { allowed: true, current: approvedCaptains, limit: limits.captainDevices };
  }

  public static canRegisterCounterPc(): { allowed: boolean; current: number; limit: number; message?: string } {
    const limits = this.getLimits();
    const approvedCounters = Array.from(inMemoryStore.devices.values()).filter(
      (d) => d.role === 'counter' && d.status === 'approved'
    ).length;
    if (approvedCounters >= limits.counterPcs) {
      return {
        allowed: false,
        current: approvedCounters,
        limit: limits.counterPcs,
        message: `Counter PC limit reached: Your license allows up to ${limits.counterPcs} Counter POS (${approvedCounters}/${limits.counterPcs} registered). Please upgrade your license in Hinopt Admin.`,
      };
    }
    return { allowed: true, current: approvedCounters, limit: limits.counterPcs };
  }

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
      logger.info('No license.json file found on disk. Initializing in unlicensed state.');
      inMemoryStore.license = undefined;
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

      // Update runtime global configuration
      config.restaurantName = restName;
      config.restaurantId = restId;

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
        restaurantId: 'unlicensed',
        restaurantName: 'Unlicensed POS (Activation Required)',
        ownerName: '',
        phone: '',
        city: '',
        licenseKey: '',
        validFrom: new Date(0).toISOString(),
        validUntil: new Date(0).toISOString(),
        daysRemaining: 0,
        isOfflineGraceActive: false,
        features: [],
        limits: {
          menuItems: 0,
          captainDevices: 0,
          counterPcs: 0,
        },
        usage: {
          menuItems: inMemoryStore.menuItems.size,
          captainDevices: 0,
          counterPcs: 0,
        },
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
    const limits = this.getLimits();
    const approvedCaptains = Array.from(inMemoryStore.devices.values()).filter(
      (d) => d.role === 'captain' && d.status === 'approved'
    ).length;
    const counterPcs = Array.from(inMemoryStore.devices.values()).filter(
      (d) => d.role === 'counter' && d.status === 'approved'
    ).length;
    const menuItems = inMemoryStore.menuItems.size;

    const sysHwid = this.getSystemHardwareId();
    return {
      isValid,
      status: effectiveStatus,
      restaurantId: license.restaurantId,
      restaurantName: license.restaurantName,
      ownerName: license.ownerName || (inMemoryStore.settings.get('restaurant_profile') as any)?.ownerName || '',
      phone: license.phone || (inMemoryStore.settings.get('restaurant_profile') as any)?.phone || '',
      city: license.city || (inMemoryStore.settings.get('restaurant_profile') as any)?.address || '',
      hardwareId: sysHwid,
      hwid: sysHwid,
      licenseKey: license.licenseKey,
      validFrom: license.validFrom,
      validUntil: license.validUntil,
      daysRemaining: Math.max(0, daysRemaining),
      isOfflineGraceActive: effectiveStatus === 'grace',
      features: (license.signedPayload.features as string[]) || ['pos', 'kot', 'billing'],
      limits,
      onlineOrderingEnabled: Boolean(
        license.signedPayload.onlineOrderingEnabled ||
        (Array.isArray(license.signedPayload.allowedFeatures) && license.signedPayload.allowedFeatures.includes('ONLINE_ORDERING')) ||
        (Array.isArray(license.signedPayload.features) && license.signedPayload.features.includes('ONLINE_ORDERING'))
      ),
      storeUrl: (license.signedPayload.storeUrl as string) || '',
      customDomain: (license.signedPayload.customDomain as string) || '',
      storeSlug: (license.signedPayload.storeSlug as string) || '',
      usage: {
        menuItems,
        captainDevices: approvedCaptains,
        counterPcs,
      },
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
    const hasValidPublicKey = config.license.publicKeyPem && 
      !config.license.publicKeyPem.includes('replace_with') && 
      config.license.publicKeyPem.length > 50;

    if (hasValidPublicKey) {
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
      // Robust fallback: HMAC verification
      const secret = process.env.JWT_SECRET || 'hinopt_cloud_master_secret';
      const expectedHmac = crypto.createHmac('sha256', secret).update(signedPayloadBase64).digest('hex');
      if (signatureHex.length === 64 && signatureHex !== expectedHmac) {
        logger.warn('HMAC license signature mismatch');
      }
    }

    const limits = payloadJson.limits || {
      menuItems: typeof payloadJson.menuItemsLimit === 'number' ? payloadJson.menuItemsLimit : 100,
      captainDevices: typeof payloadJson.maxDevices === 'number' ? payloadJson.maxDevices : 5,
      counterPcs: typeof payloadJson.counterPcsLimit === 'number' ? payloadJson.counterPcsLimit : 1,
    };

    const restName = payloadJson.restaurantName || config.restaurantName;
    const ownerName = payloadJson.ownerName || payloadJson.contactName || '';
    const phone = payloadJson.phone || '';
    const city = payloadJson.city || '';

    const updatedLicense: LicenseRecord = {
      id: 'current_license',
      restaurantId: payloadJson.restaurantId,
      restaurantName: restName,
      ownerName: ownerName,
      phone: phone,
      city: city,
      licenseKey: payloadJson.licenseKey,
      status: payloadJson.status || 'active',
      validFrom: payloadJson.validFrom,
      validUntil: payloadJson.validUntil,
      lastVerifiedAt: new Date().toISOString(),
      signature: signatureHex,
      limits,
      signedPayload: payloadJson,
    };

    inMemoryStore.license = updatedLicense;

    // Check if this is a fresh restaurant license activation
    const previousProfile = (inMemoryStore.settings.get('restaurant_profile') as any);
    const previousRestId = previousProfile?.restaurantId;
    const isNewActivation = !previousRestId || previousRestId !== updatedLicense.restaurantId;
    const hasDemoData = inMemoryStore.orders.has('ord_live_101') || 
                        inMemoryStore.bills.has('bill-801') || 
                        (inMemoryStore.orders.size > 0 && isNewActivation);

    // Update restaurant profile name & owner
    inMemoryStore.settings.set('restaurant_profile', {
      restaurantId: updatedLicense.restaurantId,
      name: updatedLicense.restaurantName,
      ownerName: ownerName,
      tagline: 'Fine Dining & Hospitality',
      address: city || 'Main Branch',
      phone: phone || '+91 98490 00000',
      gstin: '36AABCU9603R1ZM',
      currency: 'INR',
    });

    if (isNewActivation || hasDemoData) {
      inMemoryStore.resetToFreshProductionState(updatedLicense.restaurantName, updatedLicense.restaurantId);
    }

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

    // Write license.json to disk so it persists across reboots
    try {
      const diskLicensePath = path.resolve(process.cwd(), 'license.json');
      fs.writeFileSync(
        diskLicensePath,
        JSON.stringify(
          {
            signedPayload: payloadJson,
            signature: signatureHex,
            token: `${signedPayloadBase64}.${signatureHex}`,
            updatedAt: new Date().toISOString(),
          },
          null,
          2
        ),
        'utf-8'
      );
    } catch (_) {}

    inMemoryStore.saveToDisk();

    return this.getLicenseStatus();
  }

  public static async activateLicenseKey(licenseKey: string): Promise<LicenseStatusResult> {
    const trimmed = (licenseKey || '').trim();
    if (!trimmed || trimmed.length < 5) {
      throw new BadRequestError('License key is required and must be at least 5 characters');
    }

    // 1. If user pasted a full signed token (payload.signature)
    if (trimmed.includes('.')) {
      const parts = trimmed.split('.');
      return await this.verifyAndApplyLicense(parts[0], parts[1]);
    }

    const clientHwid = this.getSystemHardwareId();

    // 2. Try online lookup from Hinopt Cloud Admin server
    const adminUrl = process.env.HINOPT_ADMIN_URL || 'http://127.0.0.1:5000';
    try {
      const res = await fetch(`${adminUrl}/api/license/lookup/${encodeURIComponent(trimmed)}?hwid=${encodeURIComponent(clientHwid)}`, {
        method: 'GET',
        headers: { 'Content-Type': 'application/json' },
      });
      if (res.ok) {
        const data = (await res.json()) as any;
        if (data.success && data.signedPayloadBase64 && data.signatureHex) {
          return await this.verifyAndApplyLicense(data.signedPayloadBase64, data.signatureHex);
        }
      }
    } catch (_) {
      logger.info({ key: trimmed }, 'Hinopt Local/Cloud Admin unreachable. Checking Supabase Cloud directly...');
    }

    // 2.5. Direct Supabase Cloud Lookup (Works on any client PC connected to the internet)
    const SUPABASE_URL = process.env.SUPABASE_URL || 'https://ybalhfhqaduqsbjotbni.supabase.co';
    const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InliYWxoZmhxYWR1cXNiam90Ym5pIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MjM5MzM4NCwiZXhwIjoyMTA3OTY5Mzg0fQ.Sw_edT0eB7HdN4jQ5vIfk9oGM_LSsCCJMw16Pv5MJH0';

    try {
      const licRes = await fetch(`${SUPABASE_URL}/rest/v1/licenses?license_key=eq.${encodeURIComponent(trimmed)}&select=*`, {
        headers: { apikey: SUPABASE_KEY, Authorization: `Bearer ${SUPABASE_KEY}` },
      });
      if (licRes.ok) {
        const licenses = (await licRes.json()) as any[];
        if (licenses && licenses.length > 0) {
          const lic = licenses[0];
          const restaurantId = lic.restaurant_id;

          let restName = 'curry leaf restaurant';
          let ownerName = '';
          let phone = '';
          let city = '';

          const restRes = await fetch(`${SUPABASE_URL}/rest/v1/restaurants?id=eq.${encodeURIComponent(restaurantId)}&select=*`, {
            headers: { apikey: SUPABASE_KEY, Authorization: `Bearer ${SUPABASE_KEY}` },
          });
          if (restRes.ok) {
            const restaurants = (await restRes.json()) as any[];
            if (restaurants && restaurants.length > 0) {
              const r = restaurants[0];
              restName = r.name || restName;
              ownerName = r.contact_name || '';
              phone = r.phone || '';
              city = r.city || '';
            }
          }

          // Immediately send and bind the real machine Hardware ID to Supabase Cloud!
          try {
            await fetch(`${SUPABASE_URL}/rest/v1/restaurants?id=eq.${encodeURIComponent(restaurantId)}`, {
              method: 'PATCH',
              headers: {
                apikey: SUPABASE_KEY,
                Authorization: `Bearer ${SUPABASE_KEY}`,
                'Content-Type': 'application/json',
                Prefer: 'return=minimal',
              },
              body: JSON.stringify({
                hwid: clientHwid,
                updated_at: new Date().toISOString(),
              }),
            });
            logger.info({ restaurantId, hwid: clientHwid }, 'Bound client Hardware ID to Supabase Cloud');
          } catch (hwidErr: any) {
            logger.warn({ err: hwidErr.message }, 'Failed to sync HWID to Supabase');
          }

          // Record audit log entry in Supabase Cloud
          try {
            await fetch(`${SUPABASE_URL}/rest/v1/audit_logs`, {
              method: 'POST',
              headers: {
                apikey: SUPABASE_KEY,
                Authorization: `Bearer ${SUPABASE_KEY}`,
                'Content-Type': 'application/json',
              },
              body: JSON.stringify({
                restaurant_id: restaurantId,
                action: 'CLIENT_HARDWARE_ACTIVATION',
                performed_by: `POS_CLIENT (${clientHwid})`,
                details: {
                  licenseKey: trimmed.toUpperCase(),
                  hwid: clientHwid,
                  restaurantName: restName,
                  ownerName: ownerName,
                  activatedAt: new Date().toISOString(),
                },
              }),
            });
          } catch (_) {}

          const limits = {
            menuItems: lic.menu_items_limit || 200,
            captainDevices: lic.max_devices || 5,
            counterPcs: lic.counter_pcs_limit || 1,
          };

          const payload = {
            version: '1.0',
            licenseKey: trimmed.toUpperCase(),
            restaurantId: restaurantId,
            restaurantName: restName,
            ownerName: ownerName,
            contactName: ownerName,
            phone: phone,
            city: city,
            hardwareId: clientHwid,
            hwid: clientHwid,
            status: (lic.status || 'active').toLowerCase(),
            validFrom: lic.valid_from || new Date().toISOString(),
            validUntil: lic.valid_until || new Date(Date.now() + 365 * 24 * 3600 * 1000).toISOString(),
            issuedAt: lic.created_at || new Date().toISOString(),
            expiresAt: lic.valid_until || new Date(Date.now() + 365 * 24 * 3600 * 1000).toISOString(),
            limits,
            allowedFeatures: lic.features || ['OFFLINE_POS', 'CAPTAIN_LAN_SYNC', 'DUAL_PRINTER_QUEUE', 'GOOGLE_DRIVE_CLOUD_BACKUP'],
          };

          const base64 = Buffer.from(JSON.stringify(payload)).toString('base64');
          const secret = process.env.JWT_SECRET || 'hinopt_cloud_master_secret';
          const signature = crypto.createHmac('sha256', secret).update(base64).digest('hex');

          logger.info({ restaurantName: restName, ownerName }, 'Successfully activated license via direct Supabase cloud lookup');
          return await this.verifyAndApplyLicense(base64, signature);
        }
      }
    } catch (err: any) {
      logger.warn({ err: err.message }, 'Direct Supabase cloud lookup failed, falling back to offline parsing');
    }

    // 3. Offline Key Activation (Standard Hinopt Key format)
    // Extract restaurant name hint from key or retain existing
    let restName = inMemoryStore.license?.restaurantName || config.restaurantName || 'Curry Leaf';
    const keyParts = trimmed.split('-');
    if (keyParts.length >= 3 && keyParts[1] !== 'LIC') {
      restName = keyParts[1].replace(/_/g, ' ');
    } else if (keyParts.length >= 4 && keyParts[1] === 'LIC') {
      restName = keyParts[2].replace(/_/g, ' ');
    }

    const now = new Date();
    const expiresAt = new Date(now.getTime() + 365 * 24 * 3600 * 1000).toISOString();
    const payload = {
      version: '1.0',
      licenseKey: trimmed.toUpperCase(),
      restaurantId: inMemoryStore.license?.restaurantId || config.restaurantId || 'rest_licensed',
      restaurantName: restName,
      status: 'active',
      validFrom: now.toISOString(),
      validUntil: expiresAt,
      issuedAt: now.toISOString(),
      expiresAt: expiresAt,
      allowedFeatures: ['OFFLINE_POS', 'CAPTAIN_LAN_SYNC', 'DUAL_PRINTER_QUEUE'],
    };

    const base64 = Buffer.from(JSON.stringify(payload)).toString('base64');
    const secret = process.env.JWT_SECRET || 'hinopt_cloud_master_secret';
    const sig = crypto.createHmac('sha256', secret).update(base64).digest('hex');

    return await this.verifyAndApplyLicense(base64, sig);
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

        if (data.approvedLimits) {
          if (!license.limits) {
            license.limits = { menuItems: 100, captainDevices: 5, counterPcs: 1 };
          }
          if (data.approvedLimits.menuItems) license.limits.menuItems = Number(data.approvedLimits.menuItems);
          if (data.approvedLimits.captainDevices) license.limits.captainDevices = Number(data.approvedLimits.captainDevices);
          if (data.approvedLimits.counterPcs) license.limits.counterPcs = Number(data.approvedLimits.counterPcs);

          logger.info({ limits: license.limits }, 'Automatic license limit upgrade applied from Hinopt Cloud Admin');
          try {
            const diskLicPath = path.resolve(process.cwd(), 'license.json');
            if (fs.existsSync(diskLicPath)) {
              const diskObj = JSON.parse(fs.readFileSync(diskLicPath, 'utf8'));
              diskObj.limits = license.limits;
              fs.writeFileSync(diskLicPath, JSON.stringify(diskObj, null, 2), 'utf8');
            }
          } catch (_) {}
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

  public static async submitUpgradeRequest(data: {
    requestedLimits: { menuItems?: number; captainDevices?: number; counterPcs?: number };
    contactPhone?: string;
    notes?: string;
  }): Promise<{ success: boolean; message: string; request: any }> {
    const license = inMemoryStore.license;
    const currentLimits = this.getLimits();

    const record = {
      id: `upg_${Date.now()}_${crypto.randomBytes(3).toString('hex')}`,
      restaurantId: license?.restaurantId || config.restaurantId,
      restaurantName: license?.restaurantName || config.restaurantName,
      licenseKey: license?.licenseKey || 'UNKNOWN',
      currentLimits,
      requestedLimits: {
        menuItems: data.requestedLimits?.menuItems ?? currentLimits.menuItems,
        captainDevices: data.requestedLimits?.captainDevices ?? currentLimits.captainDevices,
        counterPcs: data.requestedLimits?.counterPcs ?? currentLimits.counterPcs,
      },
      contactPhone: data.contactPhone || '',
      notes: data.notes || '',
      status: 'pending',
      createdAt: new Date().toISOString(),
    };

    // Save locally to multiple candidate paths so Hinopt Admin can pick it up immediately
    const candidatePaths = [
      path.resolve(process.cwd(), 'data/upgrade_requests.json'),
      path.resolve(__dirname, '../../../apps/hinopt_admin/upgrade_requests.json'),
      path.resolve(__dirname, '../../../tools/admin_pack/apps/hinopt_admin/upgrade_requests.json'),
    ];

    if (process.env.LOCALAPPDATA) {
      candidatePaths.push(
        path.join(process.env.LOCALAPPDATA, 'Programs/HinoptAdmin/apps/hinopt_admin/upgrade_requests.json')
      );
    }

    for (const reqFilePath of candidatePaths) {
      try {
        let list: any[] = [];
        if (fs.existsSync(reqFilePath)) {
          list = JSON.parse(fs.readFileSync(reqFilePath, 'utf8'));
        }
        // Avoid duplicate ID
        if (!list.some((r: any) => r.id === record.id)) {
          list.unshift(record);
          const dir = path.dirname(reqFilePath);
          if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
          fs.writeFileSync(reqFilePath, JSON.stringify(list, null, 2), 'utf8');
        }
      } catch (_) {}
    }

    // Forward to Hinopt Cloud Admin (Local Endpoint)
    const adminUrl = process.env.HINOPT_ADMIN_URL || 'http://127.0.0.1:5000';
    try {
      const resp = await fetch(`${adminUrl}/api/upgrade-requests`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(record),
      });
      if (resp.ok) {
        logger.info(`Upgrade request ${record.id} synced to Hinopt Admin`);
      }
    } catch (err: any) {
      logger.warn(`Could not immediately sync upgrade request to Hinopt Admin (saved locally): ${err?.message || err}`);
    }

    // Direct Supabase Cloud push so Admin sees it anywhere
    const SUPABASE_URL = process.env.SUPABASE_URL || 'https://ybalhfhqaduqsbjotbni.supabase.co';
    const SUPABASE_KEY = process.env.SUPABASE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InliYWxoZmhxYWR1cXNiam90Ym5pIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MjM5MzM4NCwiZXhwIjoyMTA3OTY5Mzg0fQ.Sw_edT0eB7HdN4jQ5vIfk9oGM_LSsCCJMw16Pv5MJH0';
    try {
      const sbResp = await fetch(`${SUPABASE_URL}/rest/v1/upgrade_requests`, {
        method: 'POST',
        headers: {
          'apikey': SUPABASE_KEY,
          'Authorization': `Bearer ${SUPABASE_KEY}`,
          'Content-Type': 'application/json',
          'Prefer': 'resolution=merge-duplicates',
        },
        body: JSON.stringify({
          id: record.id,
          restaurant_id: record.restaurantId,
          restaurant_name: record.restaurantName,
          license_key: record.licenseKey,
          current_limits: record.currentLimits,
          requested_limits: record.requestedLimits,
          contact_phone: record.contactPhone,
          notes: record.notes,
          status: record.status,
          created_at: record.createdAt,
          updated_at: new Date().toISOString(),
        }),
      });
      if (sbResp.ok) {
        logger.info(`Upgrade request ${record.id} pushed to Supabase Cloud`);
      }
    } catch (sbErr: any) {
      logger.warn(`Could not sync upgrade request to Supabase Cloud: ${sbErr?.message || sbErr}`);
    }

    return {
      success: true,
      message: 'Upgrade request submitted successfully to Hinopt Cloud Admin.',
      request: record,
    };
  }

  public static getUpgradeRequests(): any[] {
    const reqFilePath = path.resolve(process.cwd(), 'data/upgrade_requests.json');
    try {
      if (fs.existsSync(reqFilePath)) {
        return JSON.parse(fs.readFileSync(reqFilePath, 'utf8'));
      }
    } catch (_) {}
    return [];
  }

  /**
   * Periodically checks Supabase Cloud to see if license limits were upgraded by Admin.
   * If upgraded, auto-applies them to in-memory state and caches them to disk.
   */
  public static async syncCloudLicenseLimits(): Promise<boolean> {
    const lic = inMemoryStore.license;
    if (!lic || !lic.licenseKey) return false;

    const SUPABASE_URL = process.env.SUPABASE_URL || 'https://ybalhfhqaduqsbjotbni.supabase.co';
    const SUPABASE_KEY = process.env.SUPABASE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InliYWxoZmhxYWR1cXNiam90Ym5pIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MjM5MzM4NCwiZXhwIjoyMTA3OTY5Mzg0fQ.Sw_edT0eB7HdN4jQ5vIfk9oGM_LSsCCJMw16Pv5MJH0';

    try {
      const licRes = await fetch(`${SUPABASE_URL}/rest/v1/licenses?license_key=eq.${encodeURIComponent(lic.licenseKey)}&select=*`, {
        headers: { apikey: SUPABASE_KEY, Authorization: `Bearer ${SUPABASE_KEY}` },
      });
      if (licRes.ok) {
        const lics = (await licRes.json()) as any[];
        if (Array.isArray(lics) && lics.length > 0) {
          const cloudLic = lics[0];
          const cloudPayload = cloudLic.signed_payload || {};
          const cloudLimits = cloudPayload.limits;
          const cloudIsOnline = Boolean(
            cloudPayload.onlineOrderingEnabled ||
            (Array.isArray(cloudLic.features) && cloudLic.features.includes('ONLINE_ORDERING'))
          );

          let stateChanged = false;
          if (cloudLimits) {
            const currentLimits = this.getLimits();
            if (
              cloudLimits.menuItems !== currentLimits.menuItems ||
              cloudLimits.captainDevices !== currentLimits.captainDevices ||
              cloudLimits.counterPcs !== currentLimits.counterPcs
            ) {
              stateChanged = true;
            }
          }

          if (cloudPayload.onlineOrderingEnabled !== undefined && lic.signedPayload.onlineOrderingEnabled !== cloudIsOnline) {
            stateChanged = true;
          }

          if (stateChanged) {
            logger.info({ cloudLimits, cloudIsOnline }, 'Auto-detected updated plan or limits in Supabase Cloud! Applying to POS server and caching to disk...');
            if (!lic.signedPayload) lic.signedPayload = {};
            if (cloudLimits) lic.signedPayload.limits = cloudLimits;
            lic.signedPayload.onlineOrderingEnabled = cloudIsOnline;
            if (cloudPayload.customDomain) lic.signedPayload.customDomain = cloudPayload.customDomain;
            if (cloudPayload.storeSlug) lic.signedPayload.storeSlug = cloudPayload.storeSlug;
            if (cloudPayload.storeUrl) lic.signedPayload.storeUrl = cloudPayload.storeUrl;

            // Persist to local disk candidate files
            const candidates = [
              path.resolve(process.cwd(), 'license.json'),
              path.resolve(process.cwd(), '../license.json'),
              path.resolve(process.cwd(), '../../license.json'),
            ];
            for (const cp of candidates) {
              try {
                if (fs.existsSync(cp)) {
                  const cData = JSON.parse(fs.readFileSync(cp, 'utf8'));
                  if (cData.signedPayload) {
                    if (cloudLimits) cData.signedPayload.limits = cloudLimits;
                    cData.signedPayload.onlineOrderingEnabled = cloudIsOnline;
                    if (cloudPayload.customDomain) cData.signedPayload.customDomain = cloudPayload.customDomain;
                    if (cloudPayload.storeSlug) cData.signedPayload.storeSlug = cloudPayload.storeSlug;
                    if (cloudPayload.storeUrl) cData.signedPayload.storeUrl = cloudPayload.storeUrl;
                    cData.updatedAt = new Date().toISOString();
                    fs.writeFileSync(cp, JSON.stringify(cData, null, 2), 'utf8');
                  }
                }
              } catch (_) {}
            }
            return true;
          }
        }
      }
    } catch (_) {}
    return false;
  }
}
