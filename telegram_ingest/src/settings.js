import { config } from './config.js';
import { getSetting, setSetting } from './db.js';

const KEYS = {
  importLimit: 'importLimit',
  importIntervalMs: 'importIntervalMs',
  autoImportEnabled: 'autoImportEnabled',
  minAutoImportConfidence: 'minAutoImportConfidence',
  reviewThreshold: 'reviewThreshold',
  allowedLanguages: 'allowedLanguages',
  allowedGenres: 'allowedGenres',
  parserVersion: 'parserVersion',
};

function asBool(value, fallback) {
  if (typeof value === 'boolean') return value;
  if (value === 'false' || value === 0 || value === '0') return false;
  if (value === 'true' || value === 1 || value === '1') return true;
  return fallback;
}

export function runtimeSettings() {
  const allowedLanguages = getSetting(KEYS.allowedLanguages, []);
  const allowedGenres = getSetting(KEYS.allowedGenres, []);
  return {
    channel: config.telegram.channel,
    importLimit: Number(getSetting(KEYS.importLimit, config.importLimit)),
    importIntervalMs: Number(getSetting(KEYS.importIntervalMs, config.importIntervalMs)),
    autoImportEnabled: asBool(getSetting(KEYS.autoImportEnabled, config.autoImportEnabled), true),
    minAutoImportConfidence: Number(
      getSetting(KEYS.minAutoImportConfidence, config.minAutoImportConfidence),
    ),
    reviewThreshold: Number(getSetting(KEYS.reviewThreshold, config.reviewThreshold)),
    allowedLanguages: Array.isArray(allowedLanguages) ? allowedLanguages : [],
    allowedGenres: Array.isArray(allowedGenres) ? allowedGenres : [],
    parserVersion: String(getSetting(KEYS.parserVersion, '1.0.0')),
  };
}

export function saveSettings(patch = {}) {
  const current = runtimeSettings();
  const next = { ...current, ...patch };
  setSetting(KEYS.importLimit, Number(next.importLimit));
  setSetting(KEYS.importIntervalMs, Number(next.importIntervalMs));
  setSetting(KEYS.autoImportEnabled, asBool(next.autoImportEnabled, true));
  setSetting(KEYS.minAutoImportConfidence, Number(next.minAutoImportConfidence));
  setSetting(KEYS.reviewThreshold, Number(next.reviewThreshold));
  setSetting(KEYS.allowedLanguages, next.allowedLanguages || []);
  setSetting(KEYS.allowedGenres, next.allowedGenres || []);
  setSetting(KEYS.parserVersion, next.parserVersion || '1.0.0');
  return runtimeSettings();
}

export function parserSettings() {
  const s = runtimeSettings();
  return {
    autoImportEnabled: s.autoImportEnabled,
    minAutoImportConfidence: s.minAutoImportConfidence,
    reviewThreshold: s.reviewThreshold,
  };
}

export function passesAllowlists(parsed) {
  const s = runtimeSettings();
  if (s.allowedLanguages?.length) {
    const lang = parsed.language?.value;
    if (lang && lang !== 'Unknown' && !s.allowedLanguages.includes(lang)) return false;
  }
  if (s.allowedGenres?.length && parsed.genres?.value?.length) {
    const ok = parsed.genres.value.some((g) => s.allowedGenres.includes(g));
    if (!ok) return false;
  }
  return true;
}
