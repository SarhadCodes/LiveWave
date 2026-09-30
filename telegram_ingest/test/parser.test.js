import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import { parseCaption } from '../src/parser/index.js';
import { extractYear } from '../src/parser/year.js';
import { extractRating } from '../src/parser/rating.js';
import { extractQuality } from '../src/parser/quality.js';
import { extractGenres } from '../src/parser/genre.js';
import { normalizeForParse } from '../src/parser/normalize.js';
import { toPublicId, fromPublicId } from '../src/ids.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const fixtures = JSON.parse(
  fs.readFileSync(path.join(__dirname, 'fixtures/telegram/captions.json'), 'utf8'),
);

test('fixtures cover many caption formats', () => {
  assert.ok(fixtures.length >= 20, `expected at least 20 fixtures, got ${fixtures.length}`);
});

for (const fixture of fixtures) {
  test(`parser: ${fixture.id}`, () => {
    const parsed = parseCaption({
      caption: fixture.caption,
      fileName: fixture.fileName,
      hasVideo: true,
      video: { mime: 'video/mp4', duration: 7200 },
      messageId: 100,
    });
    const expect = fixture.expect || {};
    if (expect.titleIncludes) {
      const blob = `${parsed.title?.value || ''} ${parsed.originalTitle?.value || ''}`;
      assert.match(blob, new RegExp(expect.titleIncludes, 'i'));
    }
    if (Object.prototype.hasOwnProperty.call(expect, 'title')) {
      assert.equal(parsed.title?.value ?? null, expect.title);
    }
    if (Object.prototype.hasOwnProperty.call(expect, 'year')) {
      assert.equal(parsed.year?.value ?? null, expect.year);
    }
    if (expect.genresIncludes) {
      assert.ok(
        (parsed.genres?.value || []).includes(expect.genresIncludes),
        `expected genre ${expect.genresIncludes}, got ${JSON.stringify(parsed.genres?.value)}`,
      );
    }
    if (expect.genresEmpty) {
      assert.equal((parsed.genres?.value || []).length, 0);
    }
    if (expect.language) {
      assert.equal(parsed.language?.value, expect.language);
    }
    if (Object.prototype.hasOwnProperty.call(expect, 'rating')) {
      assert.equal(parsed.rating?.value ?? null, expect.rating);
    }
    if (expect.quality) {
      assert.equal(parsed.quality?.value, expect.quality);
    }
    if (expect.descriptionIncludes) {
      assert.match(String(parsed.description?.value || ''), new RegExp(expect.descriptionIncludes, 'i'));
    }
    assert.ok(parsed.originalCaption !== undefined);
    assert.ok(parsed.normalizedCaption !== undefined);
    assert.ok(parsed.confidence >= 0 && parsed.confidence <= 0.99);
    assert.ok(['approved', 'review', 'pending'].includes(parsed.status));
  });
}

test('parser never crashes on missing or garbage captions', () => {
  const samples = [null, undefined, '', '   ', '🔥🔥🔥', '1080 4K 5.1 202', { toString: () => 'ok' }];
  for (const caption of samples) {
    const parsed = parseCaption({ caption: caption == null ? caption : String(caption) });
    assert.equal(typeof parsed.confidence, 'number');
    assert.ok(parsed.title === null || typeof parsed.title.value === 'string' || parsed.title.value === null);
  }
});

test('year ignores 1080, 4K, and 5.1', () => {
  const text = normalizeForParse('Audio 5.1\n1080p\n4K\nruntime 2:21:35');
  const year = extractYear(text);
  assert.equal(year.value, null);
});

test('rating ignores years and quality', () => {
  const text = normalizeForParse('2023\n1080p\n4K\n2:21:35');
  const rating = extractRating(text);
  assert.equal(rating.value, null);
});

test('quality normalizes 4K/FHD/HD', () => {
  assert.equal(extractQuality('4K movie').value, '2160p');
  assert.equal(extractQuality('FHD').value, '1080p');
  assert.equal(extractQuality('HD').value, '720p');
  assert.equal(extractQuality('4K movie').originalQuality, '4K');
});

test('genres normalize Kurdish/Arabic/English to English', () => {
  const parsed = extractGenres(normalizeForParse('Komedî کۆمیدی Comedy دراما'));
  assert.ok(parsed.value.includes('Comedy'));
  assert.ok(parsed.value.includes('Drama'));
});

test('low title confidence is never auto-approved', () => {
  const parsed = parseCaption({ caption: 'join our channel', hasVideo: true });
  assert.notEqual(parsed.status, 'approved');
});

test('public movie ids do not collide with TMDB', () => {
  const publicId = toPublicId(12);
  assert.ok(publicId < 0);
  assert.equal(fromPublicId(publicId), 12);
  assert.equal(fromPublicId(12), 12);
});

test('original caption is preserved after normalization', () => {
  const original = 'تايگەر ٣\n٢٠٢٣\n🔥';
  const parsed = parseCaption({ caption: original, hasVideo: true });
  assert.equal(parsed.originalCaption, original);
  assert.ok(parsed.normalizedCaption.includes('2023'));
});
