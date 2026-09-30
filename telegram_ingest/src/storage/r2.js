import { StorageProvider } from './base.js';

/** Placeholder for a later Cloudflare R2 provider. Not required for MVP. */
export class R2StorageProvider extends StorageProvider {
  async getPlayUrl() {
    throw new Error('R2StorageProvider is not configured');
  }

  async stream(_movie, _req, res) {
    res.status(501).json({ error: 'R2 storage is not configured yet' });
  }
}
