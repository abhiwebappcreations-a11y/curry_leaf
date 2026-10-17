import crypto from 'crypto';
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
}
