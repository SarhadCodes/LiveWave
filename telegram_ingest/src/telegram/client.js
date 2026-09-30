import { TelegramClient } from 'telegram';
import { StringSession } from 'telegram/sessions/index.js';
import { config, assertTelegramConfig } from '../config.js';

let clientPromise = null;

export function getClient() {
  if (!clientPromise) {
    clientPromise = (async () => {
      assertTelegramConfig();
      if (!config.telegram.session) {
        throw new Error('TELEGRAM_SESSION is empty. Run `npm run login` first.');
      }
      const client = new TelegramClient(
        new StringSession(config.telegram.session),
        config.telegram.apiId,
        config.telegram.apiHash,
        { connectionRetries: 5 },
      );
      await client.connect();
      return client;
    })();
  }
  return clientPromise;
}

export async function resolveChannel(client) {
  const raw = String(config.telegram.channel).trim();
  return client.getEntity(raw);
}

export function mediaFromMessage(msg) {
  const doc = msg.video || msg.document || null;
  if (!doc) return null;
  const attr = (doc.attributes || []).find((a) => a.className === 'DocumentAttributeVideo');
  const mime = String(doc.mimeType || '').toLowerCase();
  const isVideo = Boolean(msg.video) || Boolean(attr) || mime.startsWith('video/');
  if (!isVideo) return null;
  const nameAttr = (doc.attributes || []).find((a) => a.fileName || a.className === 'DocumentAttributeFilename');
  return {
    telegramMediaId: String(doc.id),
    duration: attr?.duration || msg.video?.duration || null,
    width: attr?.w || msg.video?.w || null,
    height: attr?.h || msg.video?.h || null,
    fileSize: Number(doc.size || 0) || null,
    mimeType: doc.mimeType || 'video/mp4',
    fileName: nameAttr?.fileName || null,
  };
}

export function summarizeMessage(msg, channelId) {
  const media = mediaFromMessage(msg);
  return {
    messageId: msg.id,
    channelId: String(channelId),
    date: msg.date ? new Date(msg.date * 1000).toISOString() : null,
    caption: msg.message || '',
    hasVideo: Boolean(media),
    hasPoster: Boolean(msg.photo || msg.video?.thumbs?.length),
    video: media || {},
    fileName: media?.fileName || null,
  };
}
