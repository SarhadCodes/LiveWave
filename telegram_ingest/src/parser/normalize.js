const ARABIC_INDIC = '٠١٢٣٤٥٦٧٨٩';
const EASTERN_ARABIC = '۰۱۲۳۴۵۶۷۸۹';

function digitsToAscii(text) {
  return text.replace(/[٠-٩۰-۹]/g, (ch) => {
    const a = ARABIC_INDIC.indexOf(ch);
    if (a >= 0) return String(a);
    const e = EASTERN_ARABIC.indexOf(ch);
    return e >= 0 ? String(e) : ch;
  });
}

function foldArabicKurdishLetters(text) {
  return text
    .replace(/[يى]/g, 'ی')
    .replace(/ك/g, 'ک')
    .replace(/ة/g, 'ە')
    .replace(/ؤ/g, 'ۆ')
    .replace(/إأٱآ/g, 'ا');
}

function stripZeroWidth(text) {
  return text.replace(/[\u200B-\u200F\u202A-\u202E\u2060\uFEFF]/g, '');
}

function collapsePunctuation(text) {
  return text
    .replace(/[|¦]/g, ' ')
    .replace(/[•·●○★☆✦✧■□▪▫►▸►]/g, ' ')
    .replace(/[-–—_]{2,}/g, ' ')
    .replace(/[!?؟.]{2,}/g, '.')
    .replace(/[#]{2,}/g, '#');
}

export function stripHashtags(text) {
  return text.replace(/#[\p{L}\p{N}_]+/gu, ' ');
}

export function stripEmojis(text) {
  return text.replace(/\p{Extended_Pictographic}/gu, ' ');
}

export function normalizeForParse(text) {
  if (!text) return '';
  let out = String(text).normalize('NFKC');
  out = stripZeroWidth(out);
  out = digitsToAscii(out);
  out = foldArabicKurdishLetters(out);
  out = collapsePunctuation(out);
  out = out.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
  out = out.replace(/[ \t]+/g, ' ');
  out = out.replace(/\n{3,}/g, '\n\n');
  return out.trim();
}

export function linesOf(text) {
  return normalizeForParse(text)
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean);
}

export function foldForCompare(text) {
  return normalizeForParse(text)
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}
