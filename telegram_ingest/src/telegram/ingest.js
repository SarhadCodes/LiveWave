import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { nowIso } from '../db.js';
import { info, error } from '../auth.js';
import { parseCaption } from '../parser/index.js';
import { parserSettings, passesAllowlists, runtimeSettings } from '../settings.js';
import { getStorageProvider } from '../storage/index.js';
import {
  addCorrection,
  findByMediaId,
  findByTelegram,
  findTitleYearDuplicate,
  getMovie,
  insertMovie,
  listCorrections,
  listMovies,
  updateMovie,
} from '../movies.js';
import { getClient, mediaFromMessage, resolveChannel, summarizeMessage } from './client.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const thumbsDir = path.resolve(__dirname, '../../data/thumbs');
fs.mkdirSync(thumbsDir, { recursive: true });

let monitorHandle = null;
let pollTimer = null;
let running = false;

export function ingestSettings() {
  return {
    ...runtimeSettings(),
    monitoring: Boolean(monitorHandle || pollTimer),
  };
}

export async function importHistory(limit) {
  const settings = runtimeSettings();
  const client = await getClient();
  const channel = await resolveChannel(client);
  const safeLimit = Math.max(1, Math.min(Number(limit || settings.importLimit) || 10, 500));
  info('TELEGRAM', `Importing last ${safeLimit} posts from ${settings.channel}`);
  const messages = await client.getMessages(channel, { limit: safeLimit });
  let imported = 0;
  let skipped = 0;
  for (const msg of messages) {
    const result = await ingestMessage(msg, channel);
    if (result === 'skipped') skipped += 1;
    else imported += 1;
  }
  return { imported, skipped, limit: safeLimit };
}

export async function ingestMessageId(messageId) {
  const id = Number(messageId);
  if (!Number.isInteger(id) || id <= 0) throw new Error('Invalid Telegram message ID');
  const client = await getClient();
  const channel = await resolveChannel(client);
  const messages = await client.getMessages(channel, { ids: [id] });
  const msg = messages[0];
  if (!msg) throw new Error('Message not found in the configured channel');
  return ingestMessage(msg, channel);
}

export async function ingestMessage(msg, channel) {
  const settings = runtimeSettings();
  const channelId = String(channel.id || settings.channel);
  const existing = findByTelegram(channelId, msg.id);
  if (existing) {
    info('IMPORT', `Skip duplicate telegram ${channelId}/${msg.id}`);
    return 'skipped';
  }

  const media = mediaFromMessage(msg);
  if (!media) {
    info('TELEGRAM', `Skip non-video message ${msg.id}`);
    return 'skipped';
  }

  info('TELEGRAM', `New message: ${msg.id}`);
  info('PARSER', `Parsing message ${msg.id}`);
  const summary = summarizeMessage(msg, channelId);
  const parsed = parseCaption(
    { ...summary, settings: parserSettings() },
    listCorrections(),
  );

  if (parsed.title?.value) info('PARSER', `Title candidate: ${parsed.title.value}`);
  if (parsed.year?.value) info('PARSER', `Year: ${parsed.year.value}`);
  info('PARSER', `Confidence: ${parsed.confidence}`);

  let status = parsed.status;
  const titleDup = findTitleYearDuplicate(parsed.title?.value, parsed.year?.value);
  const mediaDup = findByMediaId(media.telegramMediaId);
  if (titleDup || mediaDup) {
    status = 'review';
    info('IMPORT', `Possible duplicate of movie ${(titleDup || mediaDup).id} → review`);
  }
  if (!passesAllowlists(parsed)) {
    status = 'review';
    info('IMPORT', 'Allow-list filter sent this movie to review');
  }
  if (parsed.posterMetadataAvailable && !parsed.title?.value) status = 'pending';
  if (status === 'approved' && parsed.confidence < 0.6) status = 'pending';

  const thumbPath = await saveThumb(msg, msg.id);
  const movie = insertMovie({
    title: parsed.title?.value || null,
    original_title: parsed.originalTitle?.value || null,
    year: parsed.year?.value || null,
    description: parsed.description?.value || null,
    genres: JSON.stringify(parsed.genres?.value || []),
    language: parsed.language?.value || 'Unknown',
    rating: parsed.rating?.value || null,
    rating_source: parsed.rating?.ratingSource || null,
    quality: parsed.quality?.value || null,
    original_quality: parsed.quality?.originalQuality || null,
    duration: parsed.duration?.value || media.duration || null,
    country: parsed.country?.value || null,
    poster_url: thumbPath,
    video_url: null,
    telegram_channel_id: channelId,
    telegram_message_id: msg.id,
    telegram_media_id: media.telegramMediaId,
    file_name: media.fileName,
    mime_type: media.mimeType,
    file_size: media.fileSize,
    video_width: media.width,
    video_height: media.height,
    original_caption: parsed.originalCaption,
    normalized_caption: parsed.normalizedCaption,
    parser_version: parsed.parserVersion,
    confidence: parsed.confidence,
    parse_json: JSON.stringify(parsed),
    status,
    poster_metadata_available: parsed.posterMetadataAvailable ? 1 : 0,
    poster_metadata_extracted: 0,
    created_at: nowIso(),
    updated_at: nowIso(),
  });

  if (status === 'approved') {
    await publish(movie.id);
    info('IMPORT', `Auto-approved movie ${movie.id}`);
  } else {
    info('IMPORT', `Movie ${movie.id} queued as ${status}`);
  }
  return getMovie(movie.id);
}

async function saveThumb(msg, messageId) {
  try {
    const client = await getClient();
    const thumb = msg.video?.thumbs?.[0] || msg.document?.thumbs?.[0] || msg.photo;
    if (!thumb) return null;
    const buffer = await client.downloadMedia(msg, { thumb: 0 });
    if (!buffer) return null;
    const file = path.join(thumbsDir, `${messageId}.jpg`);
    fs.writeFileSync(file, buffer);
    return `/api/movies/thumb/${messageId}.jpg`;
  } catch (err) {
    error('TELEGRAM', `Thumb download failed for ${messageId}: ${err.message}`);
    return null;
  }
}

export async function publish(id) {
  const movie = getMovie(id);
  if (!movie) return null;
  const videoUrl = await getStorageProvider().getPlayUrl(movie);
  return updateMovie(id, {
    status: 'published',
    video_url: videoUrl,
  });
}

export async function approve(id, edits = {}) {
  const movie = getMovie(id);
  if (!movie) return null;
  const patch = mapEdits(edits);
  if (edits.title && movie.title && edits.title !== movie.title) {
    addCorrection({
      sourceText: movie.title,
      normalizedText: movie.normalizedCaption,
      correctValue: edits.title,
      field: 'title',
    });
  }
  updateMovie(id, patch);
  return publish(id);
}

export function reject(id) {
  return updateMovie(id, { status: 'rejected' });
}

export function reprocess(id) {
  const movie = getMovie(id);
  if (!movie) return null;
  const parsed = parseCaption(
    {
      caption: movie.originalCaption,
      fileName: movie.fileName,
      messageId: movie.telegramMessageId,
      hasVideo: true,
      hasPoster: Boolean(movie.posterUrl),
      video: { duration: movie.duration, mime: movie.mimeType },
      settings: parserSettings(),
    },
    listCorrections(),
  );
  let status = parsed.status === 'approved' ? 'review' : parsed.status;
  const titleDup = findTitleYearDuplicate(parsed.title?.value, parsed.year?.value, movie.id);
  if (titleDup) status = 'review';
  return updateMovie(id, {
    title: parsed.title?.value || movie.title,
    original_title: parsed.originalTitle?.value,
    year: parsed.year?.value,
    description: parsed.description?.value,
    genres: JSON.stringify(parsed.genres?.value || []),
    language: parsed.language?.value,
    rating: parsed.rating?.value,
    rating_source: parsed.rating?.ratingSource,
    quality: parsed.quality?.value,
    original_quality: parsed.quality?.originalQuality,
    confidence: parsed.confidence,
    parse_json: JSON.stringify(parsed),
    parser_version: parsed.parserVersion,
    status,
  });
}

export function reprocessFailed() {
  return listMovies({ status: 'failed', limit: 200 }).map((m) => reprocess(m.id));
}

export function reprocessAll() {
  return listMovies({ limit: 1000 }).map((m) => reprocess(m.id));
}

function mapEdits(edits) {
  const patch = {};
  if (edits.title !== undefined) patch.title = edits.title;
  if (edits.originalTitle !== undefined) patch.original_title = edits.originalTitle;
  if (edits.year !== undefined) patch.year = edits.year;
  if (edits.description !== undefined) patch.description = edits.description;
  if (edits.genres !== undefined) patch.genres = JSON.stringify(edits.genres);
  if (edits.language !== undefined) patch.language = edits.language;
  if (edits.rating !== undefined) patch.rating = edits.rating;
  if (edits.quality !== undefined) patch.quality = edits.quality;
  return patch;
}

export async function startMonitor() {
  if (monitorHandle || pollTimer) return ingestSettings();
  const { NewMessage } = await import('telegram/events/index.js');
  const client = await getClient();
  const channel = await resolveChannel(client);
  const handler = async (event) => {
    try {
      await ingestMessage(event.message, channel);
    } catch (err) {
      error('TELEGRAM', err.message);
    }
  };
  client.addEventHandler(handler, new NewMessage({ chats: [channel.id] }));
  monitorHandle = handler;
  const interval = runtimeSettings().importIntervalMs;
  pollTimer = setInterval(() => {
    if (running) return;
    running = true;
    importHistory(10)
      .catch((err) => error('TELEGRAM', err.message))
      .finally(() => {
        running = false;
      });
  }, Math.max(30000, interval));
  info('TELEGRAM', `Live monitoring started for ${runtimeSettings().channel}`);
  return ingestSettings();
}

export async function stopMonitor() {
  if (pollTimer) {
    clearInterval(pollTimer);
    pollTimer = null;
  }
  monitorHandle = null;
  info('TELEGRAM', 'Live monitoring stopped');
  return ingestSettings();
}
