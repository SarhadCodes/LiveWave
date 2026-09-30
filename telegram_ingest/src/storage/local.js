import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { config } from '../config.js';
import { toPublicId } from '../ids.js';
import { StorageProvider } from './base.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const videosDir = path.resolve(__dirname, '../../data/videos');

export class LocalStorageProvider extends StorageProvider {
  fileFor(movie) {
    return path.join(videosDir, `${movie.id}.mp4`);
  }

  async getPlayUrl(movie) {
    return `${config.publicBaseUrl}/api/movies/${toPublicId(movie.id)}/play`;
  }

  async stream(movie, req, res) {
    const file = this.fileFor(movie);
    if (!fs.existsSync(file)) {
      res.status(404).json({ error: 'Local video file is not available' });
      return;
    }
    const stat = fs.statSync(file);
    res.setHeader('Content-Type', movie.mimeType || 'video/mp4');
    res.setHeader('Content-Length', String(stat.size));
    fs.createReadStream(file).pipe(res);
  }
}
