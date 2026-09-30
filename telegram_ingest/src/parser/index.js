import { PARSER_VERSION } from './dictionaries.js';
import { extractDescription } from './description.js';
import { extractGenres } from './genre.js';
import { extractLanguage } from './language.js';
import { normalizeForParse } from './normalize.js';
import { extractCountry, extractDuration, extractQuality } from './quality.js';
import { extractRating } from './rating.js';
import { extractTitle } from './title.js';
import { extractYear } from './year.js';

function field(value, confidence, extra = {}) {
  if (value === null || value === undefined || (Array.isArray(value) && !value.length)) {
    return { value: null, confidence: 0, ...extra };
  }
  return { value, confidence: Number(confidence.toFixed(4)), ...extra };
}

export function overallConfidence(parsed, { hasVideo = false } = {}) {
  const title = parsed.title?.confidence || 0;
  const year = parsed.year?.confidence || 0;
  const genres = parsed.genres?.confidence || 0;
  const language = parsed.language?.confidence || 0;
  const rating = parsed.rating?.confidence || 0;
  let score = title * 0.45 + year * 0.2 + genres * 0.12 + language * 0.08 + rating * 0.05;
  if (hasVideo) score += 0.1;
  if (!parsed.title?.value) score = Math.min(score, 0.49);
  if (parsed.posterMetadataAvailable && !parsed.title?.value) score = Math.min(score, 0.4);
  return Number(Math.max(0, Math.min(0.99, score)).toFixed(4));
}

export function decideStatus(confidence, settings = {}) {
  const autoMin = settings.minAutoImportConfidence ?? 0.9;
  const reviewMin = settings.reviewThreshold ?? 0.6;
  const autoImport = settings.autoImportEnabled !== false;
  if (confidence >= autoMin && autoImport) return 'approved';
  if (confidence >= reviewMin) return 'review';
  return 'pending';
}

export function parseCaption(input = {}, corrections = []) {
  const originalCaption = input.caption ?? input.originalCaption ?? '';
  const fileName = input.fileName || input.filename || null;
  const videoMeta = input.video || {};
  const normalizedCaption = normalizeForParse(originalCaption);

  const haystack = [normalizedCaption, fileName].filter(Boolean).join('\n');
  const year = extractYear(haystack);
  const title = extractTitle({
    originalCaption,
    normalizedCaption,
    fileName,
    year: year.value,
    corrections,
  });
  const genres = extractGenres(haystack);
  const language = extractLanguage(normalizedCaption);
  const rating = extractRating(normalizedCaption);
  const quality = extractQuality(haystack);
  const duration = extractDuration(normalizedCaption, videoMeta);
  const country = extractCountry(normalizedCaption);

  const partial = {
    title: field(title.value, title.confidence),
    originalTitle: field(title.originalTitle, title.confidence),
    year: field(year.value, year.confidence),
    genres: { value: genres.value, confidence: genres.confidence },
    language: field(language.value, language.confidence),
    rating: field(rating.value, rating.confidence, { ratingSource: rating.ratingSource }),
    quality: field(quality.value, quality.confidence, {
      originalQuality: quality.originalQuality,
    }),
    duration: field(duration.value, duration.confidence),
    country: field(country.value, country.confidence),
  };

  const description = extractDescription(originalCaption, partial);
  const parsed = {
    ...partial,
    description: field(description.value, description.confidence),
    originalCaption,
    normalizedCaption,
    sourceMessageId: input.messageId ?? input.sourceMessageId ?? null,
    parserVersion: PARSER_VERSION,
    titleCandidates: title.candidates || [],
  };

  const hasVideo = Boolean(videoMeta.mime || videoMeta.duration || input.hasVideo);
  parsed.posterMetadataAvailable = Boolean(input.hasPoster && !normalizedCaption);
  parsed.posterMetadataExtracted = false;
  parsed.confidence = overallConfidence(parsed, { hasVideo });
  parsed.status = decideStatus(parsed.confidence, input.settings);
  return parsed;
}

export { PARSER_VERSION };
