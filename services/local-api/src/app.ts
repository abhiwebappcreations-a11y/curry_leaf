import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import path from 'path';
import fs from 'fs';
import { logger } from './utils/logger.js';
import { errorHandler } from './middleware/errorHandler.js';
import { NotFoundError } from './utils/errors.js';

// Route handlers
import { healthRouter } from './routes/health.js';
import { authRouter } from './routes/auth.js';
import { tablesRouter } from './routes/tables.js';
import { menuRouter } from './routes/menu.js';
import { ordersRouter } from './routes/orders.js';
import { billingRouter } from './routes/billing.js';
import { printersRouter } from './routes/printers.js';
import { licenseRouter } from './routes/license.js';
import { reportsRouter } from './routes/reports.js';
import { backupRouter } from './routes/backup.js';
import { devicesRouter } from './routes/devices.js';
import { onlineOrderRouter } from './routes/onlineOrder.js';

const publicOrdersDir = fs.existsSync(path.resolve(__dirname, '../public/orders'))
  ? path.resolve(__dirname, '../public/orders')
  : (fs.existsSync(path.resolve(__dirname, 'public/orders'))
      ? path.resolve(__dirname, 'public/orders')
      : path.resolve(process.cwd(), 'public/orders'));

export const app = express();

// Security and utility middleware
app.use(
  helmet({
    contentSecurityPolicy: false, // Enable frontend HTML5/CSS/JS execution for storefront
  })
);
app.use(
  cors({
    origin: '*',
    methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Device-Id', 'X-Api-Key', 'Idempotency-Key'],
  })
);
app.use(express.json());

// Request logging
app.use((req, res, next) => {
  logger.debug({ method: req.method, path: req.path }, 'Incoming LAN request');
  next();
});

// Mount Public Storefront API
app.use('/api/public', onlineOrderRouter);

// Serve lightweight customer storefront
app.use('/orders', express.static(publicOrdersDir));
app.use('/delivery', express.static(publicOrdersDir));

// Mount Internal POS API routes
app.use('/api/health', healthRouter);
app.use('/api/auth', authRouter);
app.use('/api/tables', tablesRouter);
app.use('/api/menu', menuRouter);
app.use('/api/orders', ordersRouter);
app.use('/api/billing', billingRouter);
app.use('/api/bills', billingRouter);
app.use('/api/printers', printersRouter);
app.use('/api/license', licenseRouter);
app.use('/api/reports', reportsRouter);
app.use('/api/backup', backupRouter);
app.use('/api/devices', devicesRouter);

// SPA fallback for /orders
app.get(['/orders/*', '/delivery/*'], (req, res) => {
  res.sendFile(path.join(publicOrdersDir, 'index.html'));
});

// 404 handler
app.use((req, res, next) => {
  next(new NotFoundError('API Route', req.originalUrl));
});

// Centralized error handler
app.use(errorHandler);
