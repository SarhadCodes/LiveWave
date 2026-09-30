import { foldForCompare, linesOf } from './normalize.js';
import { CHANNEL_PHRASES, GENRE_ALIASES, LANGUAGE_KEYWORDS, METADATA_KEYWORDS, TITLE_LABELS } from './dictionaries.js';

function looksLikeDescription(line) {
  return line.length > 80 || (line.split(/\s+/).length > 14 && /[.؟!]/.test(line));
}

function isGenreLine(line) {
  const folded = foldForCompare(line);
  if (!folded) return false;
  const parts = folded.split(/[\/,|&\s]+/).map((p) => p.trim()).filter(Boolean);
  if (!parts.length) return false;
  return parts.every((p) => GENRE_ALIASES[p] || Object.values(GENRE_ALIASES).some((g) => foldForCompare(g) === p));
}

function isLanguageLine(line) {
  const folded = foldForCompare(line);
  if (!folded) return false;
  if (Object.keys(LANGUAGE_KEYWORDS).some((label) => foldForCompare(label) === folded)) return true;
  return Object.values(LANGUAGE_KEYWORDS).some((words) => words.some((w) => foldForCompare(w) === folded));
}

function isRatingOrQuality(line) {
  return /^(imdb|rating|hd|fhd|uhd|4k|\d{3,4}p|\d{1,2}[.,]\d(?:\s*\/\s*10)?)$/i.test(
    foldForCompare(line).replace(/\s/g, ''),
  ) || /\bimdb\b/i.test(line);
}

function isChannelNoise(line) {
  const folded = foldForCompare(line);
  return CHANNEL_PHRASES.some((p) => folded.includes(foldForCompare(p)));
}

function isYearOnly(line) {
  return /^\(?((?:19[5-9]\d)|(?:20[0-2]\d))\)?$/.test(line.trim());
}

function hasMetadataKeyword(line) {
  const folded = foldForCompare(line);
  return METADATA_KEYWORDS.some((k) => folded === foldForCompare(k) || folded.startsWith(`${foldForCompare(k)} `));
}

export function extractTitle({ originalCaption, normalizedCaption, fileName, year, corrections = [] }) {
  const candidates = [];
  const push = (text, extra) => {
    const clean = String(text || '')
      .replace(/^[#@]+/, '')
      .replace(/["«»]/g, '')
      .trim();
    if (!clean) return;
    if (clean.length < 2 || clean.length > 80) return;
    candidates.push({ text: clean, extra });
  };

  const lines = linesOf(normalizedCaption || originalCaption || '');
  lines.forEach((line, idx) => push(line, { idx, source: 'line' }));

  const yearStr = year ? String(year) : null;
  if (yearStr) {
    const nearYear = normalizedCaption?.match(
      new RegExp(`([^\\n]{2,80}?)[\\s(\[]*${yearStr}`),
    );
    if (nearYear) push(nearYear[1].replace(/[-:|]\s*$/, '').trim(), { source: 'nearYear' });
  }

  for (const line of lines) {
    const tagged = line.match(/#([^\s#]+)/g) || [];
    for (const tag of tagged) {
      push(tag.replace(/_/g, ' '), { source: 'hashtag' });
    }
    for (const key of TITLE_LABELS) {
      const foldedKey = foldForCompare(key);
      const foldedLine = foldForCompare(line);
      if (foldedLine.startsWith(`${foldedKey} `) && foldedLine.length > foldedKey.length + 2) {
        push(line.replace(new RegExp(`^[^:：\\-]+[:：\\-]\\s*`), '').trim(), { source: 'afterMeta' });
      }
    }
  }

  if (fileName) {
    const base = String(fileName)
      .replace(/\.[a-z0-9]{2,4}$/i, '')
      .replace(/[._]/g, ' ');
    push(base, { source: 'filename' });
  }

  for (const rule of corrections) {
    if (rule.field !== 'title') continue;
    const src = foldForCompare(rule.sourceText);
    if (src && foldForCompare(normalizedCaption).includes(src)) {
      push(rule.correctValue, { source: 'correction' });
    }
  }

  const scored = candidates.map((c) => scoreCandidate(c, { lines, yearStr, originalCaption }));
  scored.sort((a, b) => b.score - a.score);
  const best = scored[0];
  if (!best || best.score < 15) {
    return { value: null, originalTitle: null, confidence: 0, candidates: scored.slice(0, 5) };
  }

  const latin = scored.find((c) => /[A-Za-z]/.test(c.text) && c.score >= best.score - 20);
  const title = best.text;
  const originalTitle = latin && latin.text !== title ? latin.text : title;
  const confidence = Math.max(0.05, Math.min(0.99, best.score / 110));
  return {
    value: title,
    originalTitle,
    confidence,
    candidates: scored.slice(0, 6),
  };
}

function scoreCandidate(candidate, ctx) {
  const { text, extra } = candidate;
  const folded = foldForCompare(text);
  let score = 10;

  if (extra.source === 'nearYear') score += 30;
  if (ctx.yearStr && text.includes(ctx.yearStr)) score += 12;
  if (extra.source === 'filename') score += 15;
  if (extra.source === 'correction') score += 40;
  if (extra.source === 'afterMeta') score += 15;
  if (extra.source === 'line' && extra.idx === 0) score += 8;
  if (extra.source === 'line' && extra.idx === ctx.lines.length - 1 && text.length <= 40) score += 10;
  if (extra.source === 'line' && text.length <= 40 && !looksLikeDescription(text)) score += 20;
  if (extra.source === 'hashtag') score += 6;

  const nextLine = extra.source === 'line' ? ctx.lines[extra.idx + 1] : null;
  if (nextLine && (isYearOnly(nextLine) || hasMetadataKeyword(nextLine) || isGenreLine(nextLine))) {
    score += 15;
  }

  const repeats = (foldForCompare(ctx.originalCaption || '').split(folded).length - 1);
  if (repeats >= 2) score += 10;

  if (looksLikeDescription(text)) score -= 30;
  if (isGenreLine(text)) score -= 20;
  if (isLanguageLine(text)) score -= 25;
  if (isRatingOrQuality(text)) score -= 20;
  if (isChannelNoise(text)) score -= 20;
  if (isYearOnly(text)) score -= 40;
  if (hasMetadataKeyword(text) && text.split(/\s+/).length <= 3) score -= 15;
  if (/^\d+$/.test(text)) score -= 40;

  return { text, score, source: extra.source };
}
