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

  static async findSharedFolderId(token, folderName = 'Hinopt_POS_Backups') {
    const creds = this.getCredentials();
    if (creds?.folder_id) return creds.folder_id;
    if (process.env.GOOGLE_DRIVE_FOLDER_ID) return process.env.GOOGLE_DRIVE_FOLDER_ID;

    try {
      // 1. Search for designated folderName shared with the bot
      const q = encodeURIComponent(`name = '${folderName}' and mimeType = 'application/vnd.google-apps.folder' and trashed = false`);
      const res = await fetch(`https://www.googleapis.com/drive/v3/files?q=${q}&fields=files(id,name)&supportsAllDrives=true&includeItemsFromAllDrives=true`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (res.ok) {
        const data = await res.json();
        if (data.files && data.files.length > 0) {
          return data.files[0].id;
        }
      }

      // 2. Fallback: Search for ANY folder shared with the bot
      const anyFolderQ = encodeURIComponent(`mimeType = 'application/vnd.google-apps.folder' and trashed = false`);
      const anyRes = await fetch(`https://www.googleapis.com/drive/v3/files?q=${anyFolderQ}&fields=files(id,name)&supportsAllDrives=true&includeItemsFromAllDrives=true`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (anyRes.ok) {
        const anyData = await anyRes.json();
        if (anyData.files && anyData.files.length > 0) {
          return anyData.files[0].id;
        }
      }
    } catch (_) {}
    return null;
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

    let targetFolderId = folderId;
    if (!targetFolderId) {
      targetFolderId = await this.findSharedFolderId(token);
    }

    if (!targetFolderId) {
      return {
        success: false,
        reason: 'no_shared_folder',
        clientEmail: creds.client_email,
        message: `No Google Drive folder has been shared with service account '${creds.client_email}'. Please create a folder in your Google Drive and share it with this email as Editor.`,
      };
    }

    const metadata = {
      name: fileName,
      mimeType: 'application/octet-stream',
      parents: [targetFolderId],
    };

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
      'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&supportsAllDrives=true',
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
