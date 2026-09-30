import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import Database from 'better-sqlite3';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const dataDir = path.resolve(__dirname, '../data');
fs.mkdirSync(dataDir, { recursive: true });
fs.mkdirSync(path.join(dataDir, 'thumbs'), { recursive: true });

const dbPath = process.env.SQLITE_PATH || path.join(dataDir, 'wave.db');
export const db = new Database(dbPath);
db.pragma('journal_mode = WAL');

db.exec(`
CREATE TABLE IF NOT EXISTS movies (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT,
  original_title TEXT,
  year INTEGER,
  description TEXT,
  genres TEXT,
  language TEXT,
  rating REAL,
  rating_source TEXT,
  quality TEXT,
  original_quality TEXT,
  duration INTEGER,
  country TEXT,
  poster_url TEXT,
  video_url TEXT,
  telegram_channel_id TEXT,
  telegram_message_id INTEGER,
  telegram_media_id TEXT,
  file_name TEXT,
  mime_type TEXT,
  file_size INTEGER,
  video_width INTEGER,
  video_height INTEGER,
  original_caption TEXT,
  normalized_caption TEXT,
  parser_version TEXT,
  confidence REAL,
  parse_json TEXT,
  status TEXT,
  poster_metadata_available INTEGER DEFAULT 0,
  poster_metadata_extracted INTEGER DEFAULT 0,
  created_at TEXT,
  updated_at TEXT,
  UNIQUE(telegram_channel_id, telegram_message_id)
);

CREATE INDEX IF NOT EXISTS idx_movies_status ON movies(status);
CREATE INDEX IF NOT EXISTS idx_movies_media ON movies(telegram_media_id);

CREATE TABLE IF NOT EXISTS parser_corrections (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  source_text TEXT NOT NULL,
  normalized_text TEXT,
  correct_value TEXT NOT NULL,
  field TEXT NOT NULL,
  created_at TEXT
);

CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY,
  value TEXT
);

CREATE TABLE IF NOT EXISTS import_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  level TEXT,
  message TEXT,
  created_at TEXT
);
`);

export function nowIso() {
  return new Date().toISOString();
}

export function getSetting(key, fallback = null) {
  const row = db.prepare('SELECT value FROM settings WHERE key = ?').get(key);
  if (!row) return fallback;
  try {
    return JSON.parse(row.value);
  } catch {
    return row.value;
  }
}

export function setSetting(key, value) {
  db.prepare('INSERT INTO settings(key, value) VALUES(?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value')
    .run(key, JSON.stringify(value));
}

export function logLine(level, message) {
  db.prepare('INSERT INTO import_logs(level, message, created_at) VALUES(?,?,?)')
    .run(level, message, nowIso());
  const stamp = new Date().toISOString();
  console.log(`[${stamp}] ${message}`);
}

const aliasesPath = path.join(dataDir, 'title_aliases.json');
if (fs.existsSync(aliasesPath)) {
  try {
    const aliases = JSON.parse(fs.readFileSync(aliasesPath, 'utf8'));
    const insert = db.prepare(
      'INSERT INTO parser_corrections(source_text, normalized_text, correct_value, field, created_at) VALUES(?,?,?,?,?)',
    );
    const exists = db.prepare('SELECT id FROM parser_corrections WHERE source_text = ? AND field = ?');
    for (const row of aliases) {
      if (exists.get(row.sourceText, 'title')) continue;
      insert.run(row.sourceText, row.normalizedText || '', row.correctValue, 'title', nowIso());
    }
  } catch {
    // Seed file is optional.
  }
}
