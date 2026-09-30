export const TELEGRAM_ID_OFFSET = 1_000_000_000;

export function toPublicId(sqliteId) {
  return -(TELEGRAM_ID_OFFSET + Number(sqliteId));
}

export function fromPublicId(id) {
  const n = Number(id);
  if (!Number.isFinite(n)) return NaN;
  if (n <= -TELEGRAM_ID_OFFSET) return -n - TELEGRAM_ID_OFFSET;
  return n;
}

export function isTelegramPublicId(id) {
  return Number(id) <= -TELEGRAM_ID_OFFSET;
}
