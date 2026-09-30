export function extractRating(normalizedCaption) {
  if (!normalizedCaption) return { value: null, ratingSource: null, confidence: 0 };

  const patterns = [
    { re: /\bimdb\s*[:\-]?\s*(\d{1,2}(?:[.,]\d))?/i, source: 'imdb', conf: 0.96 },
    { re: /\brating\s*[:\-]?\s*(\d{1,2}(?:[.,]\d))?/i, source: 'caption', conf: 0.9 },
    { re: /\b(\d{1,2}(?:[.,]\d))\s*\/\s*10\b/, source: 'caption', conf: 0.92 },
    { re: /(?:نمرە|نمره|تقييم)\s*[:\-]?\s*(\d{1,2}(?:[.,]\d))?/i, source: 'caption', conf: 0.9 },
  ];

  for (const p of patterns) {
    const m = normalizedCaption.match(p.re);
    if (!m) continue;
    const rating = Number(String(m[1]).replace(',', '.'));
    if (rating >= 1 && rating <= 10) {
      return { value: rating, ratingSource: p.source, confidence: p.conf };
    }
  }

  const lines = normalizedCaption.split('\n').map((l) => l.trim());
  for (const line of lines) {
    if (/^\d{1,2}[.,]\d$/.test(line)) {
      const rating = Number(line.replace(',', '.'));
      if (rating >= 1 && rating <= 10) {
        return { value: rating, ratingSource: 'caption', confidence: 0.7 };
      }
    }
  }
  return { value: null, ratingSource: null, confidence: 0 };
}
