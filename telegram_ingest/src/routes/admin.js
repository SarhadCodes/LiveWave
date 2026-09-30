import express from 'express';
import { db } from '../db.js';
import { getMovie, listLogs, listMovies, listReviewQueue } from '../movies.js';
import { saveSettings } from '../settings.js';
import {
  approve,
  importHistory,
  ingestMessageId,
  ingestSettings,
  publish,
  reject,
  reprocess,
  reprocessAll,
  reprocessFailed,
  startMonitor,
  stopMonitor,
} from '../telegram/ingest.js';

export const adminRouter = express.Router();

adminRouter.get('/telegram/status', (_req, res) => {
  res.json({
    ok: true,
    settings: ingestSettings(),
    counts: {
      published: count('published'),
      review: count('review'),
      pending: count('pending'),
      rejected: count('rejected'),
      approved: count('approved'),
      failed: count('failed'),
    },
  });
});

adminRouter.patch('/telegram/settings', (req, res) => {
  res.json({ settings: saveSettings(req.body || {}) });
});

adminRouter.get('/telegram/logs', (req, res) => {
  res.json({ items: listLogs(Number(req.query.limit) || 100) });
});

adminRouter.post('/telegram/import', async (req, res) => {
  try {
    const limit = Number(req.body?.limit);
    const result = await importHistory(limit);
    res.json(result);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

adminRouter.post('/telegram/import/:messageId', async (req, res) => {
  try {
    const movie = await ingestMessageId(req.params.messageId);
    res.json({ movie });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

adminRouter.get('/telegram/imports', (req, res) => {
  res.json({ items: listMovies({ status: req.query.status, q: req.query.q, limit: req.query.limit }) });
});

adminRouter.get('/telegram/review', (_req, res) => {
  res.json({ items: listReviewQueue(200) });
});

adminRouter.post('/telegram/review/:id/approve', async (req, res) => {
  const movie = await approve(Number(req.params.id), req.body || {});
  if (!movie) return res.status(404).json({ error: 'Not found' });
  return res.json({ movie });
});

adminRouter.post('/telegram/review/:id/reject', (req, res) => {
  const movie = reject(Number(req.params.id));
  if (!movie) return res.status(404).json({ error: 'Not found' });
  return res.json({ movie });
});

adminRouter.patch('/telegram/review/:id', async (req, res) => {
  const movie = await approve(Number(req.params.id), req.body || {});
  if (!movie) return res.status(404).json({ error: 'Not found' });
  return res.json({ movie });
});

adminRouter.post('/telegram/reprocess/:id', (req, res) => {
  const movie = reprocess(Number(req.params.id));
  if (!movie) return res.status(404).json({ error: 'Not found' });
  return res.json({ movie });
});

adminRouter.post('/telegram/reprocess-failed', (_req, res) => {
  res.json({ items: reprocessFailed() });
});

adminRouter.post('/telegram/reprocess-all', (_req, res) => {
  const items = reprocessAll();
  res.json({ count: items.length });
});

adminRouter.post('/telegram/monitor/start', async (_req, res) => {
  try {
    res.json(await startMonitor());
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

adminRouter.post('/telegram/monitor/stop', async (_req, res) => {
  res.json(await stopMonitor());
});

adminRouter.post('/telegram/publish/:id', async (req, res) => {
  const movie = await publish(Number(req.params.id));
  if (!movie) return res.status(404).json({ error: 'Not found' });
  return res.json({ movie });
});

adminRouter.get('/telegram/imports/:id', (req, res) => {
  const movie = getMovie(Number(req.params.id));
  if (!movie) return res.status(404).json({ error: 'Not found' });
  return res.json({ movie });
});

function count(status) {
  return db.prepare('SELECT COUNT(*) AS n FROM movies WHERE status = ?').get(status).n;
}
