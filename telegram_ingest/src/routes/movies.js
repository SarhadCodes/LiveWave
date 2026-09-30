import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import express from 'express';
import { config } from '../config.js';
import { fromPublicId, toPublicId } from '../ids.js';
import { getMovie, listMovies } from '../movies.js';
import { getStorageProvider } from '../storage/index.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const thumbsDir = path.resolve(__dirname, '../../data/thumbs');

export const moviesRouter = express.Router();

moviesRouter.get('/', (_req, res) => {
  const items = listMovies({ status: 'published', limit: 500 }).map(publicMovie);
  res.json({ items });
});

moviesRouter.get('/thumb/:file', (req, res) => {
  const name = path.basename(req.params.file);
  if (!/^\d+\.jpg$/i.test(name)) return res.status(400).json({ error: 'Invalid thumbnail' });
  const file = path.join(thumbsDir, name);
  if (!fs.existsSync(file)) return res.status(404).end();
  res.setHeader('Content-Type', 'image/jpeg');
  res.setHeader('Cache-Control', 'public, max-age=86400');
  res.send(fs.readFileSync(file));
});

moviesRouter.get('/:id/play', async (req, res) => {
  const movie = publishedMovie(req.params.id);
  if (!movie) return res.status(404).json({ error: 'Not found' });
  try {
    await getStorageProvider().stream(movie, req, res);
  } catch (err) {
    if (!res.headersSent) res.status(500).json({ error: err.message });
  }
});

moviesRouter.get('/:id', (req, res) => {
  const movie = publishedMovie(req.params.id);
  if (!movie) return res.status(404).json({ error: 'Not found' });
  return res.json(publicMovie(movie));
});

function publishedMovie(rawId) {
  const id = fromPublicId(rawId);
  if (!Number.isInteger(id) || id <= 0) return null;
  const movie = getMovie(id);
  if (!movie || movie.status !== 'published') return null;
  return movie;
}

function publicMovie(movie) {
  const publicId = toPublicId(movie.id);
  const poster = movie.posterUrl
    ? (movie.posterUrl.startsWith('http') ? movie.posterUrl : `${config.publicBaseUrl}${movie.posterUrl}`)
    : null;
  return {
    id: publicId,
    title: movie.title,
    originalTitle: movie.originalTitle,
    year: movie.year,
    description: movie.description,
    genres: movie.genres,
    language: movie.language,
    rating: movie.rating,
    ratingSource: movie.ratingSource,
    quality: movie.quality,
    duration: movie.duration,
    posterUrl: poster,
    playUrl: `${config.publicBaseUrl}/api/movies/${publicId}/play`,
  };
}
