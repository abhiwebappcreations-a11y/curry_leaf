import crypto from 'crypto';
import { z } from 'zod';

export const LicensePayloadSchema = z.object({
  restaurantId: z.string().min(1),
  restaurantName: z.string().min(1),
  licenseKey: z.string().min(1),
  status: z.enum(['active', 'grace', 'expired', 'suspended']).default('active'),
  validFrom: z.string().datetime(),
  validUntil: z.string().datetime(),
  maxDevices: z.number().int().positive().default(10),
  features: z.array(z.string()).default(['pos', 'kot', 'billing', 'reports', 'thermal_printing']),
  issuedAt: z.string().datetime().default(() => new Date().toISOString()),
});

export type LicensePayload = z.infer<typeof LicensePayloadSchema>;

export interface SignedLicenseToken {
  signedPayloadBase64: string;
  signatureHex: string;
  payload: LicensePayload;
}

export interface KeyPairResult {
  publicKeyPem: string;
  privateKeyPem: string;
}

/**
 * Generates an asymmetric Ed25519 Key Pair in PKCS#8 / SPKI PEM format.
 * Private key stays securely on Hinopt Cloud.
 * Public key is distributed to restaurant Counter PCs in .env.
 */
export function generateEd25519KeyPair(): KeyPairResult {
  const { publicKey, privateKey } = crypto.generateKeyPairSync('ed25519', {
    publicKeyEncoding: { type: 'spki', format: 'pem' },
    privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
  });

  return {
    publicKeyPem: publicKey,
    privateKeyPem: privateKey,
  };
}

/**
 * Signs a canonical license payload using the Hinopt Cloud Private Key.
 */
export function signLicense(
  payloadInput: z.input<typeof LicensePayloadSchema>,
  privateKeyPem: string
): SignedLicenseToken {
  const validatedPayload = LicensePayloadSchema.parse(payloadInput);
  const jsonString = JSON.stringify(validatedPayload);
  const signedPayloadBase64 = Buffer.from(jsonString, 'utf-8').toString('base64');

  const dataBuffer = Buffer.from(signedPayloadBase64);
  const signatureBuffer = crypto.sign(null, dataBuffer, privateKeyPem);
  const signatureHex = signatureBuffer.toString('hex');

  return {
    signedPayloadBase64,
    signatureHex,
    payload: validatedPayload,
  };
}

/**
 * Cryptographically verifies a signed license payload against the Hinopt Public Key.
 */
export function verifyLicense(
  signedPayloadBase64: string,
  signatureHex: string,
  publicKeyPem: string
): { isValid: boolean; payload?: LicensePayload; error?: string } {
  try {
    const dataBuffer = Buffer.from(signedPayloadBase64);
    const signatureBuffer = Buffer.from(signatureHex, 'hex');

    const isValid = crypto.verify(null, dataBuffer, publicKeyPem, signatureBuffer);
    if (!isValid) {
      return { isValid: false, error: 'Cryptographic signature mismatch or tampered payload' };
    }

    const jsonString = Buffer.from(signedPayloadBase64, 'base64').toString('utf-8');
    const parsed = JSON.parse(jsonString);
    const payload = LicensePayloadSchema.parse(parsed);

    return { isValid: true, payload };
  } catch (err: any) {
    return { isValid: false, error: err.message || 'Verification exception' };
  }
}
