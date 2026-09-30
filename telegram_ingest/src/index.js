import express from 'express';
import { config } from './config.js';
import { requireAdmin, rateLimit, info, error } from './auth.js';
import { adminRouter } from './routes/admin.js';
import { moviesRouter } from './routes/movies.js';
import { startMonitor } from './telegram/ingest.js';

const app = express();
app.set('trust proxy', 1);
app.use(express.json({ limit: '1mb' }));
app.use(rateLimit({ windowMs: 60000, max: 180 }));
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Admin-Token');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PATCH,OPTIONS');
  if (req.method === 'OPTIONS') return res.end();
  return next();
});

app.get('/health', (_req, res) => res.json({ ok: true, service: 'wave-telegram-ingest' }));
app.use('/api/admin', requireAdmin, adminRouter);
app.use('/api/movies', moviesRouter);

app.listen(config.port, config.bindHost, async () => {
  info('API', `WAVE Telegram ingest listening on ${config.bindHost}:${config.port}`);
  if (process.env.TELEGRAM_MONITOR_ON_START === 'true') {
    try {
      await startMonitor();
    } catch (err) {
      error('TELEGRAM', `Monitor did not start: ${err.message}`);
    }
  }
});
