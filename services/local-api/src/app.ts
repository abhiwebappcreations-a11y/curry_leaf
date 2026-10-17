import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
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

export const app = express();

// Security and utility middleware
app.use(helmet());
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

// Mount API routes
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

// 404 handler
app.use((req, res, next) => {
  next(new NotFoundError('API Route', req.originalUrl));
});

// Centralized error handler
app.use(errorHandler);
