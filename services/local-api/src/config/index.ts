import dotenv from 'dotenv';
import path from 'path';

// Load .env from local directory or root
dotenv.config();
dotenv.config({ path: path.resolve(__dirname, '../../../.env') });

export interface AppConfig {
  env: string;
  port: number;
  host: string;
  restaurantId: string;
  restaurantName: string;
  database: {
    url: string;
    host: string;
    port: number;
    name: string;
    user: string;
    password?: string;
    maxConnections: number;
  };
  jwt: {
    secret: string;
    expiresIn: string;
  };
  license: {
    publicKeyPem: string;
    offlineGraceDays: number;
  };
  printers: {
    servicePort: number;
    counterBill: {
      target: string;
      paperWidth: string;
    };
    kitchenKot: {
      target: string;
      paperWidth: string;
    };
    printerMode: 'single' | 'double';
  };
  logLevel: string;
}

export const config: AppConfig = {
  env: process.env.NODE_ENV || 'development',
  port: parseInt(process.env.PORT || '4000', 10),
  host: process.env.HOST || '0.0.0.0',
  restaurantId: process.env.RESTAURANT_ID || 'rest_curry_leaf_01',
  restaurantName: process.env.RESTAURANT_NAME || 'Curry Leaf Fine Dining',
  database: {
    url: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/curry_leaf_pos',
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '5432', 10),
    name: process.env.DB_NAME || 'curry_leaf_pos',
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || 'postgres',
    maxConnections: parseInt(process.env.DB_MAX_CONNECTIONS || '20', 10),
  },
  jwt: {
    secret: process.env.JWT_SECRET || 'dev_secret_key_minimum_32_characters_long_for_security',
    expiresIn: process.env.JWT_EXPIRES_IN || '30d',
  },
  license: {
    publicKeyPem: process.env.LICENSE_PUBLIC_KEY_PEM || '',
    offlineGraceDays: parseInt(process.env.LICENSE_OFFLINE_GRACE_DAYS || '7', 10),
  },
  printers: {
    servicePort: parseInt(process.env.PRINT_SERVICE_PORT || '4001', 10),
    counterBill: {
      // USB: use Windows printer name (e.g. 'EPSON TM-T82X Receipt')
      // Ethernet: use 'host:port' format (e.g. '192.168.1.200:9100')
      target: process.env.BILL_PRINTER_TARGET || 'EPSON TM-T82X Receipt',
      paperWidth: process.env.BILL_PRINTER_PAPER_WIDTH || '80mm',
    },
    printerMode: (process.env.PRINTER_MODE as 'single' | 'double') || 'single',
    kitchenKot: {
      // USB: use Windows printer name (e.g. 'EPSON TM-T82X Receipt6')
      // Ethernet: use 'host:port' format (e.g. '192.168.1.201:9100')
      target: process.env.KOT_PRINTER_TARGET || 'EPSON TM-T82X Receipt6',
      paperWidth: process.env.KOT_PRINTER_PAPER_WIDTH || '80mm',
    },
  },
  logLevel: process.env.LOG_LEVEL || 'info',
};
