import pg from 'pg';
import { config } from '../config/index.js';
import { logger } from '../utils/logger.js';
import { inMemoryStore } from './inMemoryStore.js';

const { Pool } = pg;

export class DatabaseService {
  private pool: pg.Pool | null = null;
  private isPostgresConnected = false;

  constructor() {
    this.initPool();
  }

  private initPool() {
    try {
      this.pool = new Pool({
        connectionString: config.database.url,
        max: config.database.maxConnections,
        connectionTimeoutMillis: 3000,
      });

      this.pool.on('error', (err) => {
        logger.warn({ err }, 'PostgreSQL Pool error. Operating in local store mode.');
        this.isPostgresConnected = false;
      });
    } catch (err) {
      logger.warn({ err }, 'Failed to initialize PostgreSQL pool. Using in-memory fallback.');
      this.isPostgresConnected = false;
    }
  }

  public async checkConnection(): Promise<boolean> {
    if (!this.pool) return false;
    try {
      const client = await this.pool.connect();
      await client.query('SELECT 1');
      client.release();
      this.isPostgresConnected = true;
      return true;
    } catch {
      this.isPostgresConnected = false;
      return false;
    }
  }

  public isConnectedToPostgres(): boolean {
    return this.isPostgresConnected;
  }

  public getStore() {
    return inMemoryStore;
  }

  public async query<T extends pg.QueryResultRow = any>(text: string, params?: any[]): Promise<pg.QueryResult<T>> {
    if (this.isPostgresConnected && this.pool) {
      return this.pool.query<T>(text, params);
    }
    throw new Error('PostgreSQL database not connected');
  }

  public async close(): Promise<void> {
    if (this.pool) {
      await this.pool.end();
    }
  }
}

export const db = new DatabaseService();
