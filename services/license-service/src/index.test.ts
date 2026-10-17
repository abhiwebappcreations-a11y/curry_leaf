import { describe, it, expect } from 'vitest';
import { generateEd25519KeyPair, signLicense, verifyLicense } from './crypto.js';

describe('Hinopt Cloud — License Service Test Suite', () => {
  it('generateEd25519KeyPair - generates valid PEM key pair', () => {
    const keys = generateEd25519KeyPair();
    expect(keys.publicKeyPem).toContain('-----BEGIN PUBLIC KEY-----');
    expect(keys.publicKeyPem).toContain('-----END PUBLIC KEY-----');
    expect(keys.privateKeyPem).toContain('-----BEGIN PRIVATE KEY-----');
    expect(keys.privateKeyPem).toContain('-----END PRIVATE KEY-----');
  });

  it('signLicense & verifyLicense - successfully issues and verifies signed license', () => {
    const { publicKeyPem, privateKeyPem } = generateEd25519KeyPair();

    const payloadInput = {
      restaurantId: 'rest_curry_leaf_01',
      restaurantName: 'Curry Leaf Fine Dining',
      licenseKey: 'HINOPT-LIC-TEST-2026',
      validFrom: new Date().toISOString(),
      validUntil: new Date(Date.now() + 365 * 24 * 3600 * 1000).toISOString(),
      maxDevices: 12,
      features: ['pos', 'kot', 'billing', 'reports'],
      status: 'active' as const,
    };

    const token = signLicense(payloadInput, privateKeyPem);

    expect(token.signedPayloadBase64).toBeDefined();
    expect(token.signatureHex).toMatch(/^[0-9a-f]+$/i);
    expect(token.payload.restaurantId).toBe('rest_curry_leaf_01');

    // Verify with public key
    const verification = verifyLicense(token.signedPayloadBase64, token.signatureHex, publicKeyPem);
    expect(verification.isValid).toBe(true);
    expect(verification.payload?.licenseKey).toBe('HINOPT-LIC-TEST-2026');
    expect(verification.payload?.maxDevices).toBe(12);
  });

  it('verifyLicense - rejects tampered license payload', () => {
    const { publicKeyPem, privateKeyPem } = generateEd25519KeyPair();

    const token = signLicense(
      {
        restaurantId: 'rest_curry_leaf_01',
        restaurantName: 'Curry Leaf Fine Dining',
        licenseKey: 'HINOPT-LIC-ORIGINAL',
        validFrom: new Date().toISOString(),
        validUntil: new Date(Date.now() + 365 * 24 * 3600 * 1000).toISOString(),
      },
      privateKeyPem
    );

    // Tamper with base64 payload to extend expiry date or change restaurant
    const decoded = JSON.parse(Buffer.from(token.signedPayloadBase64, 'base64').toString('utf-8'));
    decoded.maxDevices = 999;
    const tamperedBase64 = Buffer.from(JSON.stringify(decoded), 'utf-8').toString('base64');

    const result = verifyLicense(tamperedBase64, token.signatureHex, publicKeyPem);
    expect(result.isValid).toBe(false);
  });

  it('verifyLicense - rejects signature from an untrusted private key', () => {
    const keysA = generateEd25519KeyPair();
    const keysB = generateEd25519KeyPair();

    // Signed with Private Key B
    const token = signLicense(
      {
        restaurantId: 'rest_curry_leaf_01',
        restaurantName: 'Curry Leaf',
        licenseKey: 'HINOPT-LIC-B',
        validFrom: new Date().toISOString(),
        validUntil: new Date(Date.now() + 365 * 24 * 3600 * 1000).toISOString(),
      },
      keysB.privateKeyPem
    );

    // Attempted verification with Public Key A
    const result = verifyLicense(token.signedPayloadBase64, token.signatureHex, keysA.publicKeyPem);
    expect(result.isValid).toBe(false);
  });
});
