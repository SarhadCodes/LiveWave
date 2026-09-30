const MAX_YEAR = new Date().getFullYear() + 1;
const MIN_YEAR = 1950;

export function extractYear(normalizedCaption) {
  if (!normalizedCaption) return { value: null, confidence: 0 };
  const matches = [...normalizedCaption.matchAll(/\b((?:19[5-9]\d)|(?:20[0-2]\d))\b/g)];
  const years = [];
  for (const match of matches) {
    const year = Number(match[1]);
    if (year < MIN_YEAR || year > MAX_YEAR) continue;
    const around = normalizedCaption.slice(Math.max(0, match.index - 2), match.index + 6);
    if (/\d{2,4}p/i.test(around) || /4k/i.test(around)) continue;
    years.push({ year, paren: /[(\[]\s*$/.test(normalizedCaption.slice(0, match.index)) });
  }
  if (!years.length) return { value: null, confidence: 0 };
  const best = years.find((y) => y.paren) || years[years.length - 1];
  return {
    value: best.year,
    confidence: best.paren || years.length === 1 ? 0.99 : 0.82,
  };
}
