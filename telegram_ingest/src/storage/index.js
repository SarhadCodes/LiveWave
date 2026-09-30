import { TelegramStorageProvider } from './telegram.js';
import { LocalStorageProvider } from './local.js';
import { R2StorageProvider } from './r2.js';

const providers = {
  telegram: () => new TelegramStorageProvider(),
  local: () => new LocalStorageProvider(),
  r2: () => new R2StorageProvider(),
};

let cached = null;

export function getStorageProvider() {
  if (cached) return cached;
  const name = (process.env.STORAGE_PROVIDER || 'telegram').toLowerCase();
  const factory = providers[name] || providers.telegram;
  cached = factory();
  return cached;
}

export { TelegramStorageProvider, LocalStorageProvider, R2StorageProvider };
