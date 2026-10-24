import { Router, Request, Response, NextFunction } from 'express';
import fs from 'fs';
import path from 'path';
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
