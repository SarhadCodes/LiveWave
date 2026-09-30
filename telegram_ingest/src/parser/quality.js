import { QUALITY_MAP } from './dictionaries.js';
import { foldForCompare } from './normalize.js';

export function extractQuality(normalizedCaption) {
  if (!normalizedCaption) {
    return { value: null, originalQuality: null, confidence: 0 };
  }
  const folded = foldForCompare(normalizedCaption);
  const raw = normalizedCaption;

  const ordered = Object.keys(QUALITY_MAP).sort((a, b) => b.length - a.length);
  for (const key of ordered) {
    const re = new RegExp(`(?:^|[^a-z0-9])${key.replace('p', 'p?')}(?:$|[^a-z0-9])`, 'i');
    if (re.test(folded) || raw.toLowerCase().includes(key)) {
      return {
        value: QUALITY_MAP[key],
        originalQuality: key.toUpperCase(),
        confidence: 0.9,
      };
    }
  }
  return { value: null, originalQuality: null, confidence: 0 };
}

export function extractDuration(normalizedCaption, videoMeta = {}) {
  if (videoMeta.duration && Number(videoMeta.duration) > 60) {
    return { value: Number(videoMeta.duration), confidence: 0.99 };
  }
  if (!normalizedCaption) return { value: null, confidence: 0 };
  const m = normalizedCaption.match(/\b(\d{1,2}):([0-5]\d):([0-5]\d)\b/);
  if (m) {
    const secs = Number(m[1]) * 3600 + Number(m[2]) * 60 + Number(m[3]);
    return { value: secs, confidence: 0.8 };
  }
  return { value: null, confidence: 0 };
}

export function extractCountry(normalizedCaption) {
  if (!normalizedCaption) return { value: null, confidence: 0 };
  const map = {
    india: 'India',
    indian: 'India',
    bollywood: 'India',
    'هیند': 'India',
    usa: 'USA',
    hollywood: 'USA',
    america: 'USA',
    turkey: 'Turkey',
    'تورکیا': 'Turkey',
    iran: 'Iran',
    'ئێران': 'Iran',
    korea: 'Korea',
    korean: 'Korea',
    kurdistan: 'Kurdistan',
    'کوردستان': 'Kurdistan',
  };
  const lower = normalizedCaption.toLowerCase();
  for (const [k, v] of Object.entries(map)) {
    if (lower.includes(k)) return { value: v, confidence: 0.7 };
  }
  return { value: null, confidence: 0 };
}
