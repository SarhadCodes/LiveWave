import { config } from './config.js';
import { logLine } from './db.js';

export function info(scope, message) {
  logLine('info', `[${scope}] ${message}`);
}

export function error(scope, message) {
  logLine('error', `[${scope}] ${message}`);
}

export function requireAdmin(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : req.headers['x-admin-token'];
  if (!config.adminToken) {
    return res.status(500).json({ error: 'ADMIN_TOKEN is not configured on the server' });
  }
  if (!token || token !== config.adminToken) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  return next();
}

const hits = new Map();
export function rateLimit({ windowMs = 60000, max = 120 } = {}) {
  return (req, res, next) => {
    const key = req.ip || 'unknown';
    const now = Date.now();
    const bucket = hits.get(key) || [];
    const fresh = bucket.filter((t) => now - t < windowMs);
    if (fresh.length >= max) {
      return res.status(429).json({ error: 'Too many requests' });
    }
    fresh.push(now);
    hits.set(key, fresh);
    return next();
  };
}
