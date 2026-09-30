import { foldForCompare } from './normalize.js';
import { LANGUAGE_KEYWORDS } from './dictionaries.js';

function countScript(text, re) {
  return (text.match(re) || []).length;
}

export function extractLanguage(normalizedCaption) {
  if (!normalizedCaption) return { value: 'Unknown', confidence: 0 };
  const folded = foldForCompare(normalizedCaption);

  for (const [label, words] of Object.entries(LANGUAGE_KEYWORDS)) {
    for (const word of words) {
      if (folded.includes(foldForCompare(word))) {
        return { value: label, confidence: 0.93 };
      }
    }
  }

  const soraniMarks = countScript(normalizedCaption, /[ێڵۆەڕ]/g);
  const arabicLetters = countScript(normalizedCaption, /[\u0600-\u06FF]/g);
  const latinLetters = countScript(normalizedCaption, /[A-Za-z]/g);
  const badiniLatin = countScript(normalizedCaption, /[çêîûşÇÊÎÛŞ]/g);
  const devanagari = countScript(normalizedCaption, /[\u0900-\u097F]/g);

  if (devanagari > 8) return { value: 'Hindi', confidence: 0.8 };
  if (soraniMarks >= 2) return { value: 'Kurdish Sorani', confidence: 0.78 };
  if (badiniLatin >= 3 && latinLetters > arabicLetters) {
    return { value: 'Kurdish Badini', confidence: 0.72 };
  }
  if (arabicLetters > 12 && arabicLetters > latinLetters * 2) {
    return { value: 'Arabic', confidence: 0.62 };
  }
  if (latinLetters > 12 && latinLetters > arabicLetters * 2) {
    return { value: 'English', confidence: 0.55 };
  }
  if (arabicLetters > 0) return { value: 'Kurdish', confidence: 0.45 };
  return { value: 'Unknown', confidence: 0.2 };
}
