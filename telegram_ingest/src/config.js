import 'dotenv/config';

function required(name, fallback = '') {
  return process.env[name] ?? fallback;
}

export const config = {
  port: Number(required('PORT', '8787')),
  bindHost: required('BIND_HOST', '127.0.0.1'),
  adminToken: required('ADMIN_TOKEN', ''),
  publicBaseUrl: required('PUBLIC_BASE_URL', 'http://127.0.0.1:8787'),
  telegram: {
    apiId: Number(required('TELEGRAM_API_ID', '0')),
    apiHash: required('TELEGRAM_API_HASH', ''),
    channel: required('TELEGRAM_CHANNEL', ''),
    session: required('TELEGRAM_SESSION', ''),
  },
  importLimit: Number(required('IMPORT_LIMIT', '176')),
  importIntervalMs: Number(required('IMPORT_INTERVAL_MS', '120000')),
  autoImportEnabled: required('AUTO_IMPORT_ENABLED', 'true') !== 'false',
  minAutoImportConfidence: Number(required('MIN_AUTO_IMPORT_CONFIDENCE', '0.9')),
  reviewThreshold: Number(required('REVIEW_THRESHOLD', '0.6')),
};

export function assertTelegramConfig() {
  if (!config.telegram.apiId || !config.telegram.apiHash) {
    throw new Error('TELEGRAM_API_ID and TELEGRAM_API_HASH are required');
  }
  if (!config.telegram.channel) {
    throw new Error('TELEGRAM_CHANNEL is required (@username or -100id)');
  }
}
