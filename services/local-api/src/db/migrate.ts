import fs from 'fs';
import path from 'path';
import pg from 'pg';
import { fileURLToPath } from 'url';
import { config } from '../config/index.js';
import { logger } from '../utils/logger.js';

const { Client } = pg;

// Resolve migrations path relative to workspace or cwd
function getMigrationsDir(): string {
  const candidate1 = path.resolve(process.cwd(), 'database/local-migrations');
  const candidate2 = path.resolve(process.cwd(), '../../database/local-migrations');
  if (fs.existsSync(candidate1)) return candidate1;
  if (fs.existsSync(candidate2)) return candidate2;
  return candidate1;
}

const MIGRATIONS_DIR = getMigrationsDir();

export async function runMigrations() {
  logger.info({ host: config.database.host, port: config.database.port, db: config.database.name }, 'Starting PostgreSQL migration runner...');

  // 1. Ensure the target database exists; if not, create it
  const adminClient = new Client({
    host: config.database.host,
    port: config.database.port,
    user: config.database.user,
    password: config.database.password,
    database: 'postgres',
    connectionTimeoutMillis: 5000,
  });

  try {
    await adminClient.connect();
    const res = await adminClient.query(
      `SELECT 1 FROM pg_database WHERE datname = $1`,
      [config.database.name]
    );

    if (res.rowCount === 0) {
      logger.info(`Database '${config.database.name}' does not exist. Creating...`);
      await adminClient.query(`CREATE DATABASE "${config.database.name}"`);
      logger.info(`Database '${config.database.name}' created successfully.`);
    }
  } catch (err: any) {
    logger.warn({ error: err.message }, 'Unable to verify/create database via admin connection. Proceeding directly to target DB.');
  } finally {
    try {
      await adminClient.end();
    } catch {}
  }

  // 2. Connect to the operational database
  const client = new Client({
    connectionString: config.database.url,
    connectionTimeoutMillis: 5000,
  });

  try {
    await client.connect();
    logger.info(`Connected to PostgreSQL database '${config.database.name}'`);

    // 3. Ensure schema_migrations table exists
    await client.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) NOT NULL UNIQUE,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
      );
    `);

    // 4. Read migration files
    if (!fs.existsSync(MIGRATIONS_DIR)) {
      throw new Error(`Migrations directory not found at: ${MIGRATIONS_DIR}`);
    }

    const files = fs
      .readdirSync(MIGRATIONS_DIR)
      .filter((f) => f.endsWith('.sql'))
      .sort();

    const appliedRes = await client.query(`SELECT name FROM schema_migrations`);
    const appliedSet = new Set(appliedRes.rows.map((r) => r.name));

    let appliedCount = 0;

    for (const file of files) {
      if (appliedSet.has(file)) {
        logger.info({ migration: file }, 'Migration already applied, skipping.');
        continue;
      }

      logger.info({ migration: file }, 'Applying migration...');
      const filePath = path.join(MIGRATIONS_DIR, file);
      const sql = fs.readFileSync(filePath, 'utf-8');

      await client.query('BEGIN');
      try {
        await client.query(sql);
        await client.query(
          `INSERT INTO schema_migrations (name) VALUES ($1)`,
          [file]
        );
        await client.query('COMMIT');
        appliedCount += 1;
        logger.info({ migration: file }, 'Migration successfully applied.');
      } catch (migrationErr) {
        await client.query('ROLLBACK');
        logger.error({ migration: file, error: migrationErr }, 'Migration failed, transaction rolled back.');
        throw migrationErr;
      }
    }

    logger.info(`Migration runner completed. Applied ${appliedCount} new migration(s).`);
  } catch (err: any) {
    logger.error({ error: err.message }, 'Migration runner failed.');
    throw err;
  } finally {
    try {
      await client.end();
    } catch {}
  }
}

// Allow direct CLI invocation: tsx src/db/migrate.ts
if (process.argv[1] && process.argv[1].replace(/\\/g, '/').endsWith('migrate.ts')) {
  runMigrations()
    .then(() => process.exit(0))
    .catch(() => process.exit(1));
}
