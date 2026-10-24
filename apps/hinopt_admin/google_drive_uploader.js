import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const CREDENTIALS_PATH = path.join(__dirname, 'google_drive_credentials.json');

/**
 * Lightweight Google Cloud Service Account JWT Uploader
 * (Does not require heavy external SDKs; uses pure Node.js crypto and fetch)
 */
export class GoogleDriveUploader {
  static isConfigured() {
    return fs.existsSync(CREDENTIALS_PATH);
  }

  static getCredentials() {
    if (!this.isConfigured()) return null;
    try {
      return JSON.parse(fs.readFileSync(CREDENTIALS_PATH, 'utf-8'));
    } catch (_) {
      return null;
    }
  }

  static async getAccessToken(credentials) {
    const now = Math.floor(Date.now() / 1000);
    const header = { alg: 'RS256', typ: 'JWT' };
    const claimSet = {
      iss: credentials.client_email,
      scope: 'https://www.googleapis.com/auth/drive.file',
      aud: 'https://oauth2.googleapis.com/token',
      exp: now + 3600,
      iat: now,
    };

    const encodeBase64Url = (obj) =>
      Buffer.from(JSON.stringify(obj))
        .toString('base64')
        .replace(/=/g, '')
        .replace(/\+/g, '-')
        .replace(/\//g, '_');

    const encodedHeader = encodeBase64Url(header);
    const encodedClaim = encodeBase64Url(claimSet);
    const signInput = `${encodedHeader}.${encodedClaim}`;

    const signer = crypto.createSign('RSA-SHA256');
    signer.update(signInput);
    const signature = signer
      .sign(credentials.private_key, 'base64')
      .replace(/=/g, '')
      .replace(/\+/g, '-')
      .replace(/\//g, '_');

    const jwt = `${signInput}.${signature}`;

    const resp = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: jwt,
      }),
    });

    if (!resp.ok) {
      throw new Error(`Google OAuth Token request failed: ${resp.statusText}`);
    }

    const data = await resp.json();
    return data.access_token;
  }

  /**
   * Upload an encrypted backup file to Hinopt Google Drive
   */
  static async uploadEncryptedBackup({ fileName, fileContent, folderId }) {
    if (!this.isConfigured()) {
      return { success: false, reason: 'credentials_missing' };
    }

    const creds = this.getCredentials();
    const token = await this.getAccessToken(creds);

    const metadata = {
      name: fileName,
      mimeType: 'application/octet-stream',
    };

    if (folderId) {
      metadata.parents = [folderId];
    }

    const boundary = '-------314159265358979323846';
    const delimiter = `\r\n--${boundary}\r\n`;
    const closeDelimiter = `\r\n--${boundary}--`;

    const multipartRequestBody =
      delimiter +
      'Content-Type: application/json; charset=UTF-8\r\n\r\n' +
      JSON.stringify(metadata) +
      delimiter +
      'Content-Type: application/octet-stream\r\n\r\n' +
      fileContent +
      closeDelimiter;

    const resp = await fetch(
      'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart',
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': `multipart/related; boundary=${boundary}`,
        },
        body: multipartRequestBody,
      }
    );

    if (!resp.ok) {
      const err = await resp.text();
      throw new Error(`Google Drive Upload failed: ${err}`);
    }

    const fileData = await resp.json();
    return {
      success: true,
      fileId: fileData.id,
      fileName: fileData.name,
      link: `https://drive.google.com/file/d/${fileData.id}/view`,
    };
  }
}
