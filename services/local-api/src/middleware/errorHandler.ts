import { Request, Response, NextFunction } from 'express';
import { AppError } from '../utils/errors.js';
import { logger } from '../utils/logger.js';
import { config } from '../config/index.js';

export function errorHandler(
  err: Error,
  req: Request,
  res: Response,
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  next: NextFunction
) {
  if (err instanceof AppError) {
    logger.warn(
      {
        path: req.path,
        method: req.method,
        code: err.code,
        statusCode: err.statusCode,
        message: err.message,
      },
      'Application handled error'
    );

    return res.status(err.statusCode).json({
      success: false,
      error: {
        code: err.code,
        message: err.message,
        details: err.details,
      },
    });
  }

  logger.error(
    {
      path: req.path,
      method: req.method,
      error: err.message,
      stack: err.stack,
    },
    'Unhandled server exception'
  );

  return res.status(500).json({
    success: false,
    error: {
      code: 'INTERNAL_SERVER_ERROR',
      message:
        config.env === 'production'
          ? 'An internal operational error occurred. Please contact system support.'
          : err.message,
    },
  });
}
