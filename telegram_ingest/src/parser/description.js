import { foldForCompare, linesOf, stripEmojis, stripHashtags } from './normalize.js';
import { CHANNEL_PHRASES, METADATA_KEYWORDS } from './dictionaries.js';

function isNoiseLine(line) {
  const folded = foldForCompare(line);
  if (!folded) return true;
  if (CHANNEL_PHRASES.some((p) => folded.includes(foldForCompare(p)))) return true;
  if (/^https?:\/\//i.test(line) || /^t\.me\//i.test(line)) return true;
  if (/^#/.test(line.trim())) return true;
  if (folded.length <= 2) return true;
  return false;
}

export function extractDescription(originalCaption, parsed) {
  if (!originalCaption) return { value: null, confidence: 0 };
  let text = stripHashtags(stripEmojis(originalCaption));
  const drop = [];
  if (parsed.title?.value) drop.push(parsed.title.value);
  if (parsed.originalTitle?.value) drop.push(parsed.originalTitle.value);
  if (parsed.year?.value) drop.push(String(parsed.year.value));
  if (parsed.rating?.value) drop.push(String(parsed.rating.value));
  if (parsed.quality?.originalQuality) drop.push(parsed.quality.originalQuality);
  if (parsed.quality?.value) drop.push(parsed.quality.value);
  for (const g of parsed.genres?.value || []) drop.push(g);

  const kept = [];
  for (const line of linesOf(text)) {
    if (isNoiseLine(line)) continue;
    let candidate = line;
    for (const piece of drop) {
      const re = new RegExp(piece.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'ig');
      candidate = candidate.replace(re, ' ').trim();
    }
    const folded = foldForCompare(candidate);
    if (!folded || folded.length < 12) continue;
    if (METADATA_KEYWORDS.some((k) => folded === foldForCompare(k))) continue;
    if (/^\(?\d{4}\)?$/.test(candidate)) continue;
    if (/^\d{1,2}[.,]\d(?:\s*\/\s*10)?$/.test(candidate)) continue;
    kept.push(candidate);
  }

  const value = kept.join('\n').trim();
  if (!value) return { value: null, confidence: 0 };
  return { value, confidence: value.length > 40 ? 0.75 : 0.55 };
}
