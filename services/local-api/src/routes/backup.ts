import { Router, Request, Response, NextFunction } from 'express';
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { inMemoryStore } from '../db/inMemoryStore.js';
import { authenticateDevice, requireRole } from '../middleware/auth.js';
import { logger } from '../utils/logger.js';

export const backupRouter = Router();
backupRouter.use(authenticateDevice);

function getBackupDir(): string {
  const dir = path.resolve(process.cwd(), 'data', 'backups');
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
  return dir;
}

function getCloudBackupDir(): string {
  const dir = path.resolve(process.cwd(), 'data', 'cloud_backups');
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
  return dir;
}

// AES-256-GCM Client-Side Encryption
function getEncryptionKey(): Buffer {
  const licenseKey = inMemoryStore.license?.licenseKey || process.env.LICENSE_KEY || 'hinopt_default_restaurant_key_2026';
  return crypto.createHash('sha256').update(licenseKey).digest();
}

function encryptBackupPayload(data: Record<string, unknown>): {
  encryptedPayload: string;
  iv: string;
  authTag: string;
  algorithm: string;
} {
  const key = getEncryptionKey();
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  const jsonStr = JSON.stringify(data);
  let encrypted = cipher.update(jsonStr, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  const authTag = cipher.getAuthTag().toString('hex');

  return {
    encryptedPayload: encrypted,
    iv: iv.toString('hex'),
    authTag,
    algorithm: 'aes-256-gcm',
  };
}

function decryptBackupPayload(encryptedHex: string, ivHex: string, authTagHex: string): Record<string, unknown> {
  const key = getEncryptionKey();
  const iv = Buffer.from(ivHex, 'hex');
  const authTag = Buffer.from(authTagHex, 'hex');
  const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
  decipher.setAuthTag(authTag);
  let decrypted = decipher.update(encryptedHex, 'hex', 'utf8');
  decrypted += decipher.final('utf8');
  return JSON.parse(decrypted);
}

// GET /api/backup/export - Export full JSON snapshot for USB / Cloud
backupRouter.get(
  '/export',
  requireRole('counter', 'admin'),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = inMemoryStore.exportBackupData();

      // Auto-save a timestamped local snapshot
      const backupDir = getBackupDir();
      const dateStr = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
      const fileName = `pos_backup_${dateStr}.json`;
      const fullPath = path.join(backupDir, fileName);

      fs.writeFileSync(fullPath, JSON.stringify(data, null, 2), 'utf-8');
      logger.info({ fileName }, 'Automated backup snapshot created');

      res.setHeader('Content-Disposition', `attachment; filename="${fileName}"`);
      res.setHeader('Content-Type', 'application/json');

      res.json({
        success: true,
        data: {
          fileName,
          snapshotPath: fullPath,
          backup: data,
        },
      });
    } catch (err) {
      next(err);
    }
  }
);

// POST /api/backup/restore - Restore from USB / JSON Payload
backupRouter.post(
  '/restore',
  requireRole('counter', 'admin'),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { backupData } = req.body;
      if (!backupData) {
        res.status(400).json({
          success: false,
          error: {
            code: 'INVALID_PAYLOAD',
            message: 'Field "backupData" is required in request body.',
          },
        });
        return;
      }

      const stats = inMemoryStore.restoreBackupData(backupData);
      logger.info(stats, 'Database restored from backup payload');

      res.json({
        success: true,
        data: {
          message: 'POS database restored successfully from backup!',
          stats,
        },
      });
    } catch (err: any) {
      res.status(400).json({
        success: false,
        error: {
          code: 'RESTORE_FAILED',
          message: err?.message || 'Failed to restore database from provided backup.',
        },
      });
    }
  }
);

// GET /api/backup/snapshots - List local available snapshots
backupRouter.get(
  '/snapshots',
  requireRole('counter', 'admin'),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const backupDir = getBackupDir();
      const files = fs.readdirSync(backupDir).filter((f) => f.endsWith('.json'));

      const snapshots = files
        .map((name) => {
          const stat = fs.statSync(path.join(backupDir, name));
          return {
            name,
            sizeKb: Math.round(stat.size / 1024),
            createdAt: stat.mtime.toISOString(),
          };
        })
        .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());

      res.json({
        success: true,
        data: snapshots,
      });
    } catch (err) {
      next(err);
    }
  }
);

// POST /api/backup/restore-snapshot - Restore from an existing local snapshot
backupRouter.post(
  '/restore-snapshot',
  requireRole('counter', 'admin'),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { fileName } = req.body;
      if (!fileName) {
        res.status(400).json({
          success: false,
          error: { code: 'MISSING_FILE_NAME', message: 'fileName is required' },
        });
        return;
      }

      const backupDir = getBackupDir();
      const filePath = path.join(backupDir, path.basename(fileName));

      if (!fs.existsSync(filePath)) {
        res.status(404).json({
          success: false,
          error: { code: 'FILE_NOT_FOUND', message: 'Snapshot file not found on disk' },
        });
        return;
      }

      const content = fs.readFileSync(filePath, 'utf-8');
      const data = JSON.parse(content);
      const backupPayload = data.backup || data;

      const stats = inMemoryStore.restoreBackupData(backupPayload);
      logger.info(stats, `Restored database from snapshot ${fileName}`);

      res.json({
        success: true,
        data: {
          message: `Restored successfully from snapshot "${fileName}"!`,
          stats,
        },
      });
    } catch (err: any) {
      res.status(400).json({
        success: false,
        error: {
          code: 'RESTORE_FAILED',
          message: err?.message || 'Failed to restore snapshot.',
        },
      });
    }
  }
);

// POST /api/backup/cloud-sync - Encrypt with AES-256-GCM and Sync to Cloud / Google Drive
backupRouter.post(
  '/cloud-sync',
  requireRole('counter', 'admin'),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const rawData = inMemoryStore.exportBackupData();
      const encryptedBundle = encryptBackupPayload(rawData);

      const dateStr = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
      const fileName = `pos_cloud_${dateStr}.enc`;
      const cloudDir = getCloudBackupDir();
      const localCloudFile = path.join(cloudDir, fileName);

      const syncPayload = {
        restaurantId: (rawData.settings as any)?.restaurant_profile?.restaurantId || 'rest_curry_leaf_01',
        restaurantName: rawData.restaurantName,
        fileName,
        timestamp: new Date().toISOString(),
        encryption: 'AES-256-GCM',
        ...encryptedBundle,
      };

      // 1. Save local encrypted copy
      fs.writeFileSync(localCloudFile, JSON.stringify(syncPayload, null, 2), 'utf-8');

      // 2. Transmit to Hinopt Central Cloud (Google Drive bridge) if reachable
      let cloudSynced = false;
      const adminCloudUrl = process.env.HINOPT_ADMIN_URL || 'http://127.0.0.1:5000';
      try {
        const cloudResp = await fetch(`${adminCloudUrl}/api/cloud-backups/upload`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(syncPayload),
        });
        if (cloudResp.ok) {
          cloudSynced = true;
          logger.info('Backup successfully synced to Hinopt Central Google Drive bridge');
        }
      } catch (_) {
        logger.warn('Central Admin Cloud unreachable; saved AES-256-GCM encrypted backup locally');
      }

      inMemoryStore.settings.set('cloud_backup_meta', {
        lastSyncedAt: new Date().toISOString(),
        fileName,
        cloudSynced,
        sizeBytes: fs.statSync(localCloudFile).size,
        provider: 'Hinopt Google Drive (AES-256-GCM Encrypted)',
      });

      inMemoryStore.saveToDisk();

      res.json({
        success: true,
        data: {
          message: 'Backup encrypted with AES-256-GCM and synchronized to cloud!',
          fileName,
          cloudSynced,
          sizeBytes: fs.statSync(localCloudFile).size,
          lastSyncedAt: new Date().toISOString(),
          provider: 'Hinopt Google Drive',
        },
      });
    } catch (err: any) {
      res.status(500).json({
        success: false,
        error: {
          code: 'CLOUD_SYNC_FAILED',
          message: err?.message || 'Failed to encrypt and sync backup.',
        },
      });
    }
  }
);

// GET /api/backup/cloud-status - Check Cloud Backup Sync State
backupRouter.get(
  '/cloud-status',
  requireRole('counter', 'admin'),
  async (req: Request, res: Response) => {
    const meta = inMemoryStore.settings.get('cloud_backup_meta') as any;
    res.json({
      success: true,
      data: {
        isConfigured: true,
        provider: 'Hinopt Google Drive (AES-256-GCM Encrypted)',
        lastSyncedAt: meta?.lastSyncedAt || null,
        fileName: meta?.fileName || null,
        cloudSynced: meta?.cloudSynced ?? false,
        sizeBytes: meta?.sizeBytes || 0,
      },
    });
  }
);

// POST /api/backup/cloud-restore - 1-Click Restore from Latest Encrypted Cloud Backup
backupRouter.post(
  '/cloud-restore',
  requireRole('counter', 'admin'),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      let encryptedData: any = null;

      // 1. Try pulling latest from Hinopt Central Cloud (Google Drive)
      const adminCloudUrl = process.env.HINOPT_ADMIN_URL || 'http://127.0.0.1:5000';
      const restaurantId = (inMemoryStore.settings.get('restaurant_profile') as any)?.restaurantId || 'rest_curry_leaf_01';
      try {
        const resp = await fetch(`${adminCloudUrl}/api/cloud-backups/latest/${restaurantId}`);
        if (resp.ok) {
          const json = (await resp.json()) as any;
          if (json.success && json.data) {
            encryptedData = json.data;
          }
        }
      } catch (_) {}

      // 2. Fallback to latest local cloud encrypted file
      if (!encryptedData) {
        const cloudDir = getCloudBackupDir();
        const files = fs.readdirSync(cloudDir).filter((f) => f.endsWith('.enc'));
        if (files.length > 0) {
          files.sort((a, b) => fs.statSync(path.join(cloudDir, b)).mtimeMs - fs.statSync(path.join(cloudDir, a)).mtimeMs);
          const latestFile = path.join(cloudDir, files[0]);
          encryptedData = JSON.parse(fs.readFileSync(latestFile, 'utf-8'));
        }
      }

      if (!encryptedData) {
        res.status(404).json({
          success: false,
          error: {
            code: 'NO_CLOUD_BACKUP',
            message: 'No encrypted cloud backup found on Hinopt Drive or local cache.',
          },
        });
        return;
      }

      // 3. Decrypt with local AES-256-GCM key
      const decryptedBackup = decryptBackupPayload(
        encryptedData.encryptedPayload,
        encryptedData.iv,
        encryptedData.authTag
      );

      // 4. Restore store
      const stats = inMemoryStore.restoreBackupData(decryptedBackup);
      logger.info(stats, 'Database restored successfully from AES-256 encrypted Cloud Backup');

      res.json({
        success: true,
        data: {
          message: 'POS successfully restored from Hinopt Cloud Backup!',
          stats,
        },
      });
    } catch (err: any) {
      res.status(400).json({
        success: false,
        error: {
          code: 'CLOUD_RESTORE_FAILED',
          message: err?.message || 'Failed to decrypt and restore cloud backup.',
        },
      });
    }
  }
);
