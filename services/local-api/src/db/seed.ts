import fs from 'fs';
import path from 'path';
import pg from 'pg';
import { fileURLToPath } from 'url';
import { config } from '../config/index.js';
import { logger } from '../utils/logger.js';

const { Client } = pg;

function getSeedFile(): string {
  const candidate1 = path.resolve(process.cwd(), 'database/local-migrations/002_seed_data.sql');
  const candidate2 = path.resolve(process.cwd(), '../../database/local-migrations/002_seed_data.sql');
  if (fs.existsSync(candidate1)) return candidate1;
  if (fs.existsSync(candidate2)) return candidate2;
  return candidate1;
}

const SEED_FILE = getSeedFile();

export async function runSeeds() {
  logger.info({ db: config.database.name }, 'Starting PostgreSQL seed data runner...');

  const client = new Client({
    connectionString: config.database.url,
    connectionTimeoutMillis: 5000,
  });

  try {
    await client.connect();
    logger.info(`Connected to PostgreSQL database '${config.database.name}'`);

    if (!fs.existsSync(SEED_FILE)) {
      throw new Error(`Seed file not found at: ${SEED_FILE}`);
    }

    const sql = fs.readFileSync(SEED_FILE, 'utf-8');

    await client.query('BEGIN');
    try {
      await client.query(sql);
      await client.query('COMMIT');
      logger.info('Development seed data applied successfully.');
    } catch (seedErr) {
      await client.query('ROLLBACK');
      logger.error({ error: seedErr }, 'Seed runner failed, rolled back.');
      throw seedErr;
    }
  } catch (err: any) {
    logger.error({ error: err.message }, 'Failed to connect or apply seed data.');
    throw err;
  } finally {
    try {
      await client.end();
    } catch {}
  }
}

// Allow direct CLI invocation: tsx src/db/seed.ts
if (process.argv[1] && process.argv[1].replace(/\\/g, '/').endsWith('seed.ts')) {
  runSeeds()
    .then(() => process.exit(0))
    .catch(() => process.exit(1));
}
