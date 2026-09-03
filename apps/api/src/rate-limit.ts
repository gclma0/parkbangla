import { NextFunction, Request, Response } from 'express';

type Bucket = {
  count: number;
  resetAt: number;
};

const buckets = new Map<string, Bucket>();

function ruleFor(path: string, method: string) {
  if (path.startsWith('/auth/otp')) return { limit: 8, windowMs: 10 * 60 * 1000 };
  if (path.includes('/messages')) return { limit: 60, windowMs: 60 * 1000 };
  if (path.startsWith('/bookings') && method === 'POST') return { limit: 30, windowMs: 60 * 1000 };
  if (path.startsWith('/wallet')) return { limit: 30, windowMs: 60 * 1000 };
  if (path.startsWith('/uploads')) return { limit: 20, windowMs: 60 * 1000 };
  if (path.startsWith('/spots') && method === 'GET') return { limit: 120, windowMs: 60 * 1000 };
  return { limit: 300, windowMs: 60 * 1000 };
}

export function createRateLimitMiddleware() {
  return (req: Request, res: Response, next: NextFunction) => {
    const path = req.path || req.url || '';
    const method = req.method || 'GET';
    const { limit, windowMs } = ruleFor(path, method);
    const key = `${req.ip}:${method}:${path}`;
    const now = Date.now();
    const current = buckets.get(key);

    if (!current || current.resetAt <= now) {
      buckets.set(key, { count: 1, resetAt: now + windowMs });
      next();
      return;
    }

    if (current.count >= limit) {
      res.status(429).json({ message: 'Too many requests. Try again later.' });
      return;
    }

    current.count += 1;
    next();
  };
}
