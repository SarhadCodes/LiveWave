import { db, nowIso } from './db.js';

export function listMovies({ status, q, limit = 50, offset = 0 } = {}) {
  const where = [];
  const args = [];
  if (status) {
    where.push('status = ?');
    args.push(status);
  }
  if (q) {
    where.push('(title LIKE ? OR original_caption LIKE ?)');
    args.push(`%${q}%`, `%${q}%`);
  }
  const sql = `SELECT * FROM movies ${where.length ? `WHERE ${where.join(' AND ')}` : ''} ORDER BY id DESC LIMIT ? OFFSET ?`;
  args.push(Number(limit), Number(offset));
  return db.prepare(sql).all(...args).map(shape);
}

export function getMovie(id) {
  const row = db.prepare('SELECT * FROM movies WHERE id = ?').get(Number(id));
  return row ? shape(row) : null;
}

export function findByTelegram(channelId, messageId) {
  const row = db.prepare(
    'SELECT * FROM movies WHERE telegram_channel_id = ? AND telegram_message_id = ?',
  ).get(String(channelId), Number(messageId));
  return row ? shape(row) : null;
}

export function findTitleYearDuplicate(title, year, excludeId) {
  if (!title || !year) return null;
  const row = db.prepare(
    `SELECT * FROM movies WHERE lower(title) = lower(?) AND year = ? AND id != ? AND status NOT IN ('rejected') LIMIT 1`,
  ).get(title, year, excludeId || 0);
  return row ? shape(row) : null;
}

export function findByMediaId(mediaId, excludeId) {
  if (!mediaId) return null;
  const row = db.prepare(
    `SELECT * FROM movies WHERE telegram_media_id = ? AND id != ? AND status NOT IN ('rejected') LIMIT 1`,
  ).get(String(mediaId), excludeId || 0);
  return row ? shape(row) : null;
}

export function listReviewQueue(limit = 200) {
  return db.prepare(
    `SELECT * FROM movies WHERE status IN ('review', 'pending') ORDER BY id DESC LIMIT ?`,
  ).all(Number(limit)).map(shape);
}

export function listLogs(limit = 100) {
  return db.prepare('SELECT * FROM import_logs ORDER BY id DESC LIMIT ?').all(Number(limit));
}

export function insertMovie(data) {
  const info = db.prepare(`
    INSERT INTO movies (
      title, original_title, year, description, genres, language, rating, rating_source,
      quality, original_quality, duration, country, poster_url, video_url,
      telegram_channel_id, telegram_message_id, telegram_media_id, file_name, mime_type,
      file_size, video_width, video_height, original_caption, normalized_caption,
      parser_version, confidence, parse_json, status, poster_metadata_available,
      poster_metadata_extracted, created_at, updated_at
    ) VALUES (
      @title, @original_title, @year, @description, @genres, @language, @rating, @rating_source,
      @quality, @original_quality, @duration, @country, @poster_url, @video_url,
      @telegram_channel_id, @telegram_message_id, @telegram_media_id, @file_name, @mime_type,
      @file_size, @video_width, @video_height, @original_caption, @normalized_caption,
      @parser_version, @confidence, @parse_json, @status, @poster_metadata_available,
      @poster_metadata_extracted, @created_at, @updated_at
    )
  `).run(data);
  return getMovie(info.lastInsertRowid);
}

export function updateMovie(id, patch) {
  const current = getMovie(id);
  if (!current) return null;
  const merged = { ...flatten(current), ...patch, updated_at: nowIso() };
  const keys = Object.keys(merged).filter((k) => k !== 'id');
  db.prepare(`UPDATE movies SET ${keys.map((k) => `${k} = @${k}`).join(', ')} WHERE id = @id`)
    .run({ ...merged, id });
  return getMovie(id);
}

export function listCorrections() {
  return db.prepare('SELECT * FROM parser_corrections ORDER BY id DESC').all().map((row) => ({
    id: row.id,
    sourceText: row.source_text,
    normalizedText: row.normalized_text,
    correctValue: row.correct_value,
    field: row.field,
    createdAt: row.created_at,
  }));
}

export function addCorrection({ sourceText, normalizedText, correctValue, field }) {
  db.prepare(
    'INSERT INTO parser_corrections(source_text, normalized_text, correct_value, field, created_at) VALUES(?,?,?,?,?)',
  ).run(sourceText, normalizedText || '', correctValue, field, nowIso());
}

function shape(row) {
  return {
    id: row.id,
    title: row.title,
    originalTitle: row.original_title,
    year: row.year,
    description: row.description,
    genres: row.genres ? JSON.parse(row.genres) : [],
    language: row.language,
    rating: row.rating,
    ratingSource: row.rating_source,
    quality: row.quality,
    originalQuality: row.original_quality,
    duration: row.duration,
    country: row.country,
    posterUrl: row.poster_url,
    videoUrl: row.video_url,
    telegramChannelId: row.telegram_channel_id,
    telegramMessageId: row.telegram_message_id,
    telegramMediaId: row.telegram_media_id,
    fileName: row.file_name,
    mimeType: row.mime_type,
    fileSize: row.file_size,
    videoWidth: row.video_width,
    videoHeight: row.video_height,
    originalCaption: row.original_caption,
    normalizedCaption: row.normalized_caption,
    parserVersion: row.parser_version,
    confidence: row.confidence,
    parseJson: row.parse_json ? JSON.parse(row.parse_json) : null,
    status: row.status,
    posterMetadataAvailable: Boolean(row.poster_metadata_available),
    posterMetadataExtracted: Boolean(row.poster_metadata_extracted),
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function flatten(movie) {
  return {
    title: movie.title,
    original_title: movie.originalTitle,
    year: movie.year,
    description: movie.description,
    genres: JSON.stringify(movie.genres || []),
    language: movie.language,
    rating: movie.rating,
    rating_source: movie.ratingSource,
    quality: movie.quality,
    original_quality: movie.originalQuality,
    duration: movie.duration,
    country: movie.country,
    poster_url: movie.posterUrl,
    video_url: movie.videoUrl,
    telegram_channel_id: movie.telegramChannelId,
    telegram_message_id: movie.telegramMessageId,
    telegram_media_id: movie.telegramMediaId,
    file_name: movie.fileName,
    mime_type: movie.mimeType,
    file_size: movie.fileSize,
    video_width: movie.videoWidth,
    video_height: movie.videoHeight,
    original_caption: movie.originalCaption,
    normalized_caption: movie.normalizedCaption,
    parser_version: movie.parserVersion,
    confidence: movie.confidence,
    parse_json: JSON.stringify(movie.parseJson),
    status: movie.status,
    poster_metadata_available: movie.posterMetadataAvailable ? 1 : 0,
    poster_metadata_extracted: movie.posterMetadataExtracted ? 1 : 0,
    created_at: movie.createdAt,
    updated_at: movie.updatedAt,
  };
}
