import type { NextFunction, Request, Response } from 'express';

const sensitiveKeys = new Set(['authorization', 'cookie', 'set-cookie']);

function redactHeaders(headers: Request['headers']) {
  return Object.fromEntries(
    Object.entries(headers).map(([key, value]) => [key, sensitiveKeys.has(key.toLowerCase()) ? '[redacted]' : value]),
  );
}

export function requestLogger() {
  return (req: Request, res: Response, next: NextFunction) => {
    const started = Date.now();
    res.on('finish', () => {
      const log = {
        level: res.statusCode >= 500 ? 'error' : res.statusCode >= 400 ? 'warn' : 'info',
        event: 'http_request',
        method: req.method,
        path: req.path,
        statusCode: res.statusCode,
        durationMs: Date.now() - started,
        requestId: req.headers['x-request-id'] ?? null,
        userAgent: req.headers['user-agent'] ?? null,
        headers: process.env.LOG_HEADERS === 'true' ? redactHeaders(req.headers) : undefined,
      };
      console.log(JSON.stringify(log));
    });
    next();
  };
}

export function installProcessErrorLogging() {
  process.on('unhandledRejection', (reason) => {
    console.error(JSON.stringify({ level: 'error', event: 'unhandled_rejection', reason: String(reason) }));
  });
  process.on('uncaughtException', (error) => {
    console.error(JSON.stringify({ level: 'error', event: 'uncaught_exception', message: error.message, stack: error.stack }));
    process.exitCode = 1;
  });
}
