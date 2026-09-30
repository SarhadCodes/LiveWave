import { foldForCompare } from './normalize.js';
import { GENRE_ALIASES } from './dictionaries.js';

const FOLDED_GENRES = {};
for (const [alias, canon] of Object.entries(GENRE_ALIASES)) {
  FOLDED_GENRES[foldForCompare(alias)] = canon;
}

function lookupGenre(token) {
  const folded = foldForCompare(token);
  if (!folded) return null;
  return FOLDED_GENRES[folded] || null;
}

export function extractGenres(normalizedCaption) {
  if (!normalizedCaption) return { value: [], confidence: 0 };
  const found = [];
  const tokens = normalizedCaption.split(/[\/,|·•\n]+|\s{2,}/).map((t) => t.trim()).filter(Boolean);
  const words = normalizedCaption.split(/\s+/);
  const candidates = [...tokens, ...words];

  for (const raw of candidates) {
    const hit = lookupGenre(raw.replace(/[#:.\-]/g, ' ').trim());
    if (hit && !found.includes(hit)) found.push(hit);
  }

  for (const [folded, canon] of Object.entries(FOLDED_GENRES)) {
    if (folded.length < 3) continue;
    const re = new RegExp(`(?:^|[^\\p{L}\\p{N}])${escapeRe(folded)}(?:$|[^\\p{L}\\p{N}])`, 'iu');
    if (re.test(foldForCompare(normalizedCaption)) && !found.includes(canon)) found.push(canon);
  }

  if (!found.length) return { value: [], confidence: 0 };
  const confidence = Math.min(0.95, 0.7 + found.length * 0.08);
  return { value: found, confidence };
}

function escapeRe(text) {
  return text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
