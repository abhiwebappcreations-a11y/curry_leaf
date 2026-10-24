import { app } from './app.js';
import { config } from './config/index.js';
import { logger } from './utils/logger.js';
import { db } from './db/index.js';
import { LicenseService } from './services/licenseService.js';
import { DiscoveryService } from './services/discoveryService.js';

async function bootstrap() {
  logger.info(
    { env: config.env, port: config.port, host: config.host },
    `Starting Hinopt Restaurant POS Local API for '${config.restaurantName}'`
  );

  // 1. Check local database connection
  const isPostgresReady = await db.checkConnection();
  if (isPostgresReady) {
    logger.info('Connected to PostgreSQL local database on Counter PC');
  } else {
    logger.warn('PostgreSQL not detected. Running with in-memory resilient operational store');
  }

  // 2. Load personalized client license if present on disk
  await LicenseService.loadLicenseFromDisk();

  // 3. Validate license state on boot
  const license = await LicenseService.getLicenseStatus();
  if (!license.isValid) {
    logger.warn(
      { status: license.status, daysRemaining: license.daysRemaining },
      'License is inactive or expired'
    );
  } else {
    logger.info(
      {
        status: license.status,
        daysRemaining: license.daysRemaining,
        isGrace: license.isOfflineGraceActive,
      },
      'Hinopt POS license is valid'
    );
  }

  // 4. Start HTTP server
  const server = app.listen(config.port, config.host, () => {
    logger.info(
      `Hinopt POS Local Server is listening on http://${config.host}:${config.port}`
    );
    logger.info(`Health check endpoint: http://localhost:${config.port}/api/health`);

    // Start UDP Wi-Fi Auto-Discovery Beacon
    DiscoveryService.start();
  });

  // Graceful shutdown
  const shutdown = async (signal: string) => {
    logger.info({ signal }, 'Shutting down Hinopt Local API server gracefully...');
    DiscoveryService.stop();
    server.close(async () => {
      await db.close();
      logger.info('Server closed. Operational state preserved.');
      process.exit(0);
    });
  };

  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGTERM', () => shutdown('SIGTERM'));
}

bootstrap().catch((err) => {
  logger.fatal({ err }, 'Failed to start Hinopt Local API server');
  process.exit(1);
});
