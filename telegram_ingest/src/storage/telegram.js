import { config } from '../config.js';
import { toPublicId } from '../ids.js';
import { getClient, resolveChannel } from '../telegram/client.js';
import { StorageProvider } from './base.js';

export class TelegramStorageProvider extends StorageProvider {
  async getPlayUrl(movie) {
    const publicId = toPublicId(movie.id);
    return `${config.publicBaseUrl}/api/movies/${publicId}/play`;
  }

  async stream(movie, req, res) {
    const client = await getClient();
    const channel = await resolveChannel(client);
    const messages = await client.getMessages(channel, { ids: [movie.telegramMessageId] });
    const msg = messages[0];
    const media = msg?.document || msg?.video;
    if (!media) {
      res.status(404).json({ error: 'Telegram media is no longer available' });
      return;
    }
    res.setHeader('Content-Type', movie.mimeType || 'video/mp4');
    res.setHeader('Accept-Ranges', 'none');
    res.setHeader('Cache-Control', 'private, max-age=60');
    if (movie.fileSize) res.setHeader('Content-Length', String(movie.fileSize));
    for await (const chunk of client.iterDownload({ file: media })) {
      if (res.destroyed) break;
      res.write(Buffer.from(chunk));
    }
    res.end();
  }
}
