import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:collection/collection.dart';

class SubtitleLine {
  final Duration start;
  final Duration end;
  final String text;

  SubtitleLine({required this.start, required this.end, required this.text});
}

/// Represents a single subtitle track.
class SubtitleTrack {
  final String language;
  final String languageId;
  final String fileName;
  final String downloadUrl;
  final String format;
  final bool isHearingImpaired;
  final int downloadCount;
  final int score;

  SubtitleTrack({
    required this.language,
    required this.languageId,
    required this.fileName,
    required this.downloadUrl,
    required this.format,
    this.isHearingImpaired = false,
    this.downloadCount = 0,
    this.score = 0,
  });
}

class SubtitleService {
  static const String _tmdbApiKey = 'ebdc5880060530e71d89c0dab80a2d84';
  static const String _tmdbBaseUrl = 'https://api.themoviedb.org/3';
  static const String _osBaseUrl   = 'https://rest.opensubtitles.org';

  // ── Kurdish subtitle servers ────────────────────────────────────────────────
  //
  //  TV shows  : http://154.48.204.98/Flussonic251/EnglishTvSeries-Subtitle/Ku/
  //              Filename format : {Hyphen-Title}-Ku-S{SS}E{EE}.srt
  //              Example: From-Ku-S04E02.srt
  //
  //  Movies    : http://130.193.165.194/Flussonic247/EnglishMovies-Subtitle/Ku/
  //              Filename format : {year}/{PascalCaseTitle}-Ku.srt
  //              Example: 2024/TwilightOfTheWarriorsWalledIn-Ku.srt
  //              Example: 2026/180-Ku.srt
  // ────────────────────────────────────────────────────────────────────────────

  static const String _kurdishTvBase    = 'http://154.48.204.98/Flussonic251';
  static const String _kurdishTvPath    = 'EnglishTvSeries-Subtitle/Ku';

  static const String _kurdishMovieBase = 'http://130.193.165.194/Flussonic247';
  static const String _kurdishMoviePath = 'EnglishMovies-Subtitle/Ku';

  // ── Title normalisation ─────────────────────────────────────────────────────

  /// Strip year tags and trailing junk from a TMDB title.
  static String _cleanTitle(String title) {
    String cleaned = title
        .replaceAll(RegExp(r'\(\d{4}\)'), '')
        .replaceAll(RegExp(r'\[\d{4}\]'), '')
        .replaceAll('&', 'and'); // Normalize '&' to 'and'
    
    // Safely extract TV show title avoiding splits on natural hyphens
    final match = RegExp(r'^(.*?)\s*-\s*S\d+:E\d+').firstMatch(cleaned);
    if (match != null) {
      cleaned = match.group(1)!;
    } else {
      cleaned = cleaned.split(' - ').first;
    }
    
    // Remove colon if it's at the end
    cleaned = cleaned.trim();
    if (cleaned.endsWith(':')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    
    return cleaned.trim();
  }

  /// Alphanumeric only slug: "The Movie: Part 2" -> "themoviepart2"
  static String _normSlug(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  /// TV-show normalisation: words separated by hyphens.
  /// "The Walking Dead" → "The-Walking-Dead"
  static String _normHyphen(String text) {
    String t = text.replaceAll(RegExp(r"['’‘]"), ''); // Handle all apostrophe types
    t = t.replaceAll(RegExp(r'[^\w\s\-:]'), ' ');      // Remove other punctuation
    t = t.replaceAll(':', '-');                       // Replace colons with hyphen
    
    // Handle Roman Numerals (simple common ones)
    t = t.replaceAll(RegExp(r'\bII\b', caseSensitive: false), '2');
    t = t.replaceAll(RegExp(r'\bIII\b', caseSensitive: false), '3');
    t = t.replaceAll(RegExp(r'\bIV\b', caseSensitive: false), '4');
    t = t.replaceAll(RegExp(r'\bV\b', caseSensitive: false), '5');

    return t.trim().replaceAll(RegExp(r'\s+'), '-').replaceAll(RegExp(r'-+'), '-');
  }

  /// Movie normalisation: PascalCase (each word capitalised, no separator).
  /// "Twilight of the Warriors: Walled In" → "TwilightOfTheWarriorsWalledIn"
  static String _normPascal(String text) {
    String t = text.replaceAll(RegExp(r"['’‘]"), '');
    t = t.replaceAll(RegExp(r'[^\w\s\-]'), ' ');
    
    // Handle Roman Numerals
    t = t.replaceAll(RegExp(r'\bII\b', caseSensitive: false), '2');
    t = t.replaceAll(RegExp(r'\bIII\b', caseSensitive: false), '3');
    
    final parts = t.split(RegExp(r'[\s\-]+'));
    if (parts.isEmpty) return t;
    return parts.map((p) {
      if (p.isEmpty) return '';
      // Preserve internal casing (e.g. SpongeBob)
      return p[0].toUpperCase() + p.substring(1);
    }).join('');
  }

  static String _normDot(String text) {
    String t = text.replaceAll(RegExp(r"['’‘]"), '');
    t = t.replaceAll(RegExp(r'[^\w\s\-:]'), ' ');
    t = t.replaceAll(':', '.');
    return t.trim().replaceAll(RegExp(r'[\s\-]+'), '.').replaceAll(RegExp(r'\.+'), '.');
  }

  static String _normUnderscore(String text) {
    String t = text.replaceAll(RegExp(r"['’‘]"), '');
    t = t.replaceAll(RegExp(r'[^\w\s\-:]'), ' ');
    t = t.replaceAll(':', '_');
    return t.trim().replaceAll(RegExp(r'[\s\-]+'), '_').replaceAll(RegExp(r'_+'), '_');
  }

  // ── TV subtitle candidates ──────────────────────────────────────────────────

  static List<String> _kurdishTvCandidates(
    String title,
    int season,
    int episode, {
    int? year,
  }) {
    final ssPadded = season.toString().padLeft(2, '0');
    final eePadded = episode.toString().padLeft(2, '0');
    
    final suffixes = [
      '-Ku-S${ssPadded}E$eePadded.srt', // S04E02
      '-Ku-S${season}E$episode.srt',     // S4E2
      '-Ku-${season}x$eePadded.srt',     // 1x01
      '-Ku-${season}x$episode.srt',      // 1x1
      '-Ku-Season-${season}-Episode-${episode}.srt',
      '-Ku-S${ssPadded}-E$eePadded.srt',
      ' - S${ssPadded}E$eePadded - Ku.srt',
    ];

    final Set<String> names = {};
    final clean = _cleanTitle(title);
    
    // Standard names
    names.add(_normHyphen(clean));
    names.add(_normPascal(clean));
    names.add(_normDot(clean));
    names.add(_normUnderscore(clean));
    names.add(_normSlug(clean));
    names.add(clean); // With spaces

    // Names with year (e.g. ThePitt2025)
    if (year != null) {
      names.add('${_normPascal(clean)}$year');
      names.add('${_normHyphen(clean)}-$year');
      names.add('${_normSlug(clean)}$year');
      names.add('$clean ($year)');
    }

    // Without leading article
    final articleRe = RegExp(r'^(The|A|An)[\s-]+', caseSensitive: false);
    final noArticle = clean.replaceFirst(articleRe, '');
    if (noArticle != clean) {
      names.add(_normHyphen(noArticle));
      names.add(_normPascal(noArticle));
      names.add(_normDot(noArticle));
      names.add(_normUnderscore(noArticle));
      names.add(_normSlug(noArticle));
      names.add(noArticle);
      
      if (year != null) {
        names.add('${_normPascal(noArticle)}$year');
        names.add('${_normHyphen(noArticle)}-$year');
        names.add('${_normSlug(noArticle)}$year');
        names.add('$noArticle ($year)');
      }
    }

    // Lowercase variants
    for (final n in names.toList()) {
      names.add(n.toLowerCase());
    }

    // Combine all names with all possible suffixes
    final List<String> results = [];
    for (final n in names) {
      for (final s in suffixes) {
        results.add('$n$s');
      }
    }
    return results;
  }

  static List<String> _kurdishTvVideoCandidates(
    String title,
    int season,
    int episode, {
    int? year,
  }) {
    final ssPadded = season.toString().padLeft(2, '0');
    final eePadded = episode.toString().padLeft(2, '0');
    
    final suffixes = [
      '-S${ssPadded}E$eePadded.mp4',
      '-S${season}E$episode.mp4',
      '-${season}x$eePadded.mp4',
      '-${season}x$episode.mp4',
      '.S${ssPadded}E$eePadded.mp4',
      '_S${ssPadded}E$eePadded.mp4',
      ' S${ssPadded}E$eePadded.mp4',
      'S${ssPadded}E$eePadded.mp4',
      '-Season-${season}-Episode-${episode}.mp4',
      '-S${ssPadded}-E$eePadded.mp4',
    ];

    final Set<String> names = {};
    final clean = _cleanTitle(title);
    
    names.add(_normHyphen(clean));
    names.add(_normPascal(clean));
    names.add(_normDot(clean));
    names.add(_normUnderscore(clean));
    names.add(_normSlug(clean));
    names.add(clean);

    if (year != null) {
      names.add('${_normPascal(clean)}$year');
      names.add('${_normHyphen(clean)}-$year');
      names.add('${_normSlug(clean)}$year');
      names.add('$clean ($year)');
    }

    final articleRe = RegExp(r'^(The|A|An)[\s-]+', caseSensitive: false);
    final noArticle = clean.replaceFirst(articleRe, '');
    if (noArticle != clean) {
      names.add(_normHyphen(noArticle));
      names.add(_normPascal(noArticle));
      names.add(_normDot(noArticle));
      names.add(_normUnderscore(noArticle));
      names.add(_normSlug(noArticle));
      names.add(noArticle);

      if (year != null) {
        names.add('${_normPascal(noArticle)}$year');
        names.add('${_normHyphen(noArticle)}-$year');
        names.add('${_normSlug(noArticle)}$year');
        names.add('$noArticle ($year)');
      }
    }

    for (final n in names.toList()) {
      names.add(n.toLowerCase());
    }

    final List<String> results = [];
    for (final n in names) {
      for (final s in suffixes) {
        results.add('$n$s');
      }
    }
    return results;
  }

  static List<String> _kurdishMovieVideoCandidates(String title, int year) {
    final Set<String> names = {};
    final clean = _cleanTitle(title);
    
    names.add(_normPascal(clean));
    names.add(_normHyphen(clean));
    names.add(_normUnderscore(clean));
    names.add(_normDot(clean));
    names.add(_normSlug(clean));
    names.add(clean);
    names.add('$clean ($year)');

    final articleRe = RegExp(r'^(The|A|An)[\s-]+', caseSensitive: false);
    final noArticle = clean.replaceFirst(articleRe, '');
    if (noArticle != clean) {
      names.add(_normPascal(noArticle));
      names.add(_normHyphen(noArticle));
      names.add(_normUnderscore(noArticle));
      names.add(_normDot(noArticle));
      names.add(_normSlug(noArticle));
      names.add(noArticle);
    }

    for (final n in names.toList()) {
      names.add(n.toLowerCase());
    }

    final suffixes = ['-NoSub.mp4', '.mp4', ' NoSub.mp4'];
    
    final List<String> results = [];
    for (final n in names) {
      for (final s in suffixes) {
        results.add('$year/$n$s');
        results.add('OTHER/$n$s');
      }
    }
    return results;
  }

  // ── Movie subtitle candidates ───────────────────────────────────────────────

  /// Build movie filename candidates for a given year.
  static List<String> _kurdishMovieCandidatesForYear(
    String title,
    int year,
  ) {
    final Set<String> names = {};
    final clean = _cleanTitle(title);
    names.add(_normPascal(clean));
    names.add(_normPascal(title));
    names.add(_normSlug(clean));

    // Without leading article
    final articleRe = RegExp(r'^(The|A|An)[\s]+', caseSensitive: false);
    final noArticle = clean.replaceFirst(articleRe, '');
    if (noArticle != clean) {
      names.add(_normPascal(noArticle));
      names.add(_normSlug(noArticle));
    }

    // Lowercase variants
    for (final n in names.toList()) {
      names.add(n.toLowerCase());
    }

    return names.map((n) => '$year/$n-Ku.srt').toList();
  }

  // ── TMDB helpers ────────────────────────────────────────────────────────────

  static Future<String?> _getImdbId(int tmdbId, {required bool isMovie}) async {
    try {
      final type     = isMovie ? 'movie' : 'tv';
      final url      = '$_tmdbBaseUrl/$type/$tmdbId/external_ids?api_key=$_tmdbApiKey';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['imdb_id']?.toString();
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> _getEpisodeImdbId(
    int seriesId,
    int season,
    int episode,
  ) async {
    try {
      final url = '$_tmdbBaseUrl/tv/$seriesId/season/$season/episode/$episode'
          '/external_ids?api_key=$_tmdbApiKey';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['imdb_id']?.toString();
      }
    } catch (_) {}
    return null;
  }

  /// Fetch the release year of a movie from TMDB (used when caller doesn't supply it).
  static Future<int?> _getMovieYear(int tmdbId) async {
    try {
      final url = '$_tmdbBaseUrl/movie/$tmdbId?api_key=$_tmdbApiKey';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final releaseDate = jsonDecode(response.body)['release_date']?.toString() ?? '';
        if (releaseDate.length >= 4) {
          return int.tryParse(releaseDate.substring(0, 4));
        }
      }
    } catch (_) {}
    return null;
  }

  // ── Kurdish server probing ──────────────────────────────────────────────────

  /// Probe a single URL; returns true if file exists.
  static Future<bool> _probe(String url) async {
    try {
      final response = await http.head(Uri.parse(url)).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        // If it's a video, ensure it's not a 0-byte "ghost" file
        if (url.toLowerCase().contains('.mp4')) {
          final contentLength = int.tryParse(response.headers['content-length'] ?? '0') ?? 0;
          if (contentLength < 1024) return false; // Ignore if less than 1KB
        }
        return true;
      }
      return false;
    } catch (_) {
      try {
        final req = http.Request('GET', Uri.parse(url));
        final response = await req.send().timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          if (url.toLowerCase().contains('.mp4')) {
             final len = response.contentLength ?? 0;
             if (len > 0 && len < 1024) return false;
          }
          return true;
        }
        return false;
      } catch (__) {
        return false;
      }
    }
  }

  /// Try to find a Kurdish TV subtitle on the private server.
  static Future<SubtitleTrack?> getKurdishTvSubtitle(
    String title,
    int season,
    int episode, {
    int? year,
  }) async {
    final candidates = _kurdishTvCandidates(title, season, episode, year: year);
    
    // Sort candidates to prioritize those with the year if we have one
    if (year != null) {
      candidates.sort((a, b) {
        final aHasYear = a.contains(year.toString());
        final bHasYear = b.contains(year.toString());
        if (aHasYear && !bHasYear) return -1;
        if (!aHasYear && bHasYear) return 1;
        return 0;
      });
    }

    final ss = season.toString().padLeft(2, '0');
    final ee = episode.toString().padLeft(2, '0');
    debugPrint(
      '[Kurdish TV] Probing ${candidates.length} candidates for "$title" S${ss}E$ee',
    );

    final List<String> possibleBases = [
      '$_kurdishTvBase/$_kurdishTvPath',
      'http://154.48.204.98/Flussonic251/EnglishTvSeries-Subtitle/Ku',
      'http://130.193.166.118/sss/EnglishTvSeries-Subtitle/Ku',
      'http://130.193.165.194/Flussonic247/EnglishTvSeries-Subtitle/Ku',
      'http://130.193.166.197/nasstore/EnglishTvSeries-Subtitle/Ku',
      'http://130.193.166.118/sss/EnglishMovies-Subtitle/Ku',
      'http://130.193.166.197/nasstore/EnglishMovies-Subtitle/Ku',
    ];

    // Parallel batch probing for performance
    List<String> allUrls = [];
    for (final base in possibleBases) {
      for (final filename in candidates) {
        allUrls.add('$base/$filename');
      }
    }

    // Process in batches of 25 for speed
    const int batchSize = 25;
    for (int i = 0; i < allUrls.length; i += batchSize) {
      final batch = allUrls.sublist(i, i + batchSize > allUrls.length ? allUrls.length : i + batchSize);
      final results = await Future.wait(batch.map((url) async {
        if (await _probe(url)) return url;
        return null;
      }));

      final foundUrl = results.firstWhereOrNull((r) => r != null);
      if (foundUrl != null) {
        final filename = foundUrl.split('/').last;
        debugPrint('[Kurdish TV] ✓ FOUND: $foundUrl');
        return SubtitleTrack(
          language: 'Kurdish',
          languageId: 'ku',
          fileName: filename,
          downloadUrl: foundUrl,
          format: 'srt',
          score: 999999,
        );
      }
    }

    debugPrint('[Kurdish TV] ✗ Not found for "$title" S${season}E$episode');
    return null;
  }

  /// Try to find a Kurdish native video (.mp4) on the private server.
  static Future<String?> getNativeTvVideoUrl(
    String title,
    int season,
    int episode, {
    int? year,
  }) async {
    final candidates = _kurdishTvVideoCandidates(title, season, episode, year: year);
    
    // Sort candidates to prioritize those with the year if we have one
    if (year != null) {
      candidates.sort((a, b) {
        final aHasYear = a.contains(year.toString());
        final bHasYear = b.contains(year.toString());
        if (aHasYear && !bHasYear) return -1;
        if (!aHasYear && bHasYear) return 1;
        return 0;
      });
    }

    final List<String> bases = [
      '$_kurdishMovieBase', // 130.193.165.194/Flussonic247
      'http://154.48.204.98/Flussonic251',
      'http://130.193.166.197/nasstore',
      'http://130.193.166.118/sss',
      'http://154.48.204.98/Flussonic251/nasstore',
      'http://130.193.165.194/Flussonic247/nasstore',
      'http://130.193.166.197/sss',
      'http://130.193.166.118/nasstore',
    ];
    final List<String> paths = [
      'EnglishTvSeries1',
      'EnglishTvSeries2',
      'EnglishTvSeries3',
      'EnglishTvSeries4',
      'EnglishTvSeries5',
      'EnglishTvSeries6',
      'EnglishTvSeries7',
      'EnglishTvSeries8',
      'EnglishTvSeries9',
      'EnglishTvSeries10',
      'EnglishTvSeries',
      'EnglishMovies1',
      'EnglishMovies2',
      'EnglishMovies3',
      'EnglishMovies4',
      'EnglishMovies5',
    ];

    List<String> allUrls = [];
    for (final base in bases) {
      for (final path in paths) {
        for (final file in candidates) {
          allUrls.add('$base/$path/$file');
        }
      }
    }

    debugPrint('[NativeVideo] Probing ${allUrls.length} possible URLs for "$title" S${season}E$episode');
    
    // Batch in chunks of 20 to avoid overwhelmingly large bursts of requests
    for (int i = 0; i < allUrls.length; i += 20) {
      final chunk = allUrls.sublist(i, i + 20 > allUrls.length ? allUrls.length : i + 20);
      final results = await Future.wait(chunk.map((url) async {
        if (await _probe(url)) return url;
        return null;
      }));
      
      for (final r in results) {
        if (r != null) {
          debugPrint('[NativeVideo] ✓ FOUND VIDEO: $r');
          return r;
        }
      }
    }

    debugPrint('[NativeVideo] ✗ Video not found on private servers');
    return null;
  }

  /// Try to find a Kurdish native video (.mp4) for a Movie on the private server.
  static Future<String?> getNativeMovieVideoUrl(
    String title, {
    int? releaseYear,
    int? tmdbId,
  }) async {
    int? year = releaseYear;
    if (year == null && tmdbId != null) {
      year = await _getMovieYear(tmdbId);
    }
    if (year == null) {
      debugPrint('[NativeMovie] Cannot fetch native movie without a year');
      return null;
    }

    final candidates = _kurdishMovieVideoCandidates(title, year);
    final List<String> bases = [
      'http://130.193.166.118/sss',
      '$_kurdishMovieBase/Flussonic251', // 130.193.165.194
      '$_kurdishMovieBase/Flussonic247',
      'http://130.193.166.197/nasstore',
      '$_kurdishTvBase/Flussonic251', // 154.48.204.98
    ];
    final List<String> paths = [
      'EnglishMovies1',
      'EnglishMovies2',
      'EnglishMovies3',
      'EnglishMovies',
    ];

    List<String> allUrls = [];
    for (final base in bases) {
      for (final path in paths) {
        for (final file in candidates) {
          allUrls.add('$base/$path/$file');
        }
      }
    }

    debugPrint('[NativeMovie] Probing ${allUrls.length} possible URLs for "$title" ($year)');
    
    // Batch in chunks of 20 to avoid overwhelmingly large bursts of requests
    for (int i = 0; i < allUrls.length; i += 20) {
      final chunk = allUrls.sublist(i, i + 20 > allUrls.length ? allUrls.length : i + 20);
      final results = await Future.wait(chunk.map((url) async {
        if (await _probe(url)) return url;
        return null;
      }));
      
      for (final r in results) {
        if (r != null) {
          debugPrint('[NativeMovie] ✓ FOUND VIDEO: $r');
          return r;
        }
      }
    }

    debugPrint('[NativeMovie] ✗ Video not found on private servers');
    return null;
  }

  /// Try to find a Kurdish movie subtitle on the private server.
  ///
  /// [releaseYear] should be the movie's actual release year (e.g. 2024).
  /// If omitted, it is fetched from TMDB via [tmdbId].
  static Future<SubtitleTrack?> getKurdishMovieSubtitle(
    String title, {
    int? releaseYear,
    int? tmdbId,
  }) async {
    // Resolve year: caller supplies it, or we fetch from TMDB, or we try recent range.
    int? year = releaseYear;
    if (year == null && tmdbId != null) {
      year = await _getMovieYear(tmdbId);
      debugPrint('[Kurdish Movie] Resolved year from TMDB: $year');
    }

    // Build year list to try: exact year first, then ±1 as safety net.
    final List<int> yearsToTry = [];
    if (year != null) {
      yearsToTry.addAll([year, year - 1, year + 1]);
    } else {
      // Fallback: try recent years
      final now = DateTime.now().year;
      yearsToTry.addAll([now, now - 1, now - 2, now + 1]);
    }

    debugPrint('[Kurdish Movie] Probing "$title" across years $yearsToTry');

    final List<String> possibleBases = [
      '$_kurdishMovieBase/$_kurdishMoviePath',
      'http://154.48.204.98/Flussonic251/EnglishMovies-Subtitle/Ku',
      'http://130.193.166.118/sss/EnglishMovies-Subtitle/Ku',
      'http://130.193.165.194/Flussonic247/EnglishMovies-Subtitle/Ku',
      'http://130.193.166.197/nasstore/EnglishMovies-Subtitle/Ku',
      'http://130.193.166.118/sss/EnglishTvSeries-Subtitle/Ku', // Cross-check TV folder
      'http://130.193.166.197/nasstore/EnglishTvSeries-Subtitle/Ku',
    ];

    debugPrint('[Kurdish Movie] Probing "$title" across years $yearsToTry');

    for (final y in yearsToTry) {
      final candidates = _kurdishMovieCandidatesForYear(title, y);
      for (final base in possibleBases) {
        for (final filename in candidates) {
          final url = '$base/$filename';
          debugPrint('[Kurdish Movie] → $url');
          if (await _probe(url)) {
            debugPrint('[Kurdish Movie] ✓ FOUND: $url');
            return SubtitleTrack(
              language: 'Kurdish',
              languageId: 'ku',
              fileName: filename,
              downloadUrl: url,
              format: 'srt',
              score: 999999,
            );
          }
        }
      }
    }

    debugPrint('[Kurdish Movie] ✗ Not found for "$title"');
    return null;
  }

  // ── Public subtitle fetch API ───────────────────────────────────────────────

  /// Fetch subtitles for a movie.
  /// [releaseYear] improves Kurdish subtitle lookup accuracy.
  static Future<List<SubtitleTrack>> getMovieSubtitles(
    int tmdbId,
    String title, {
    int? releaseYear,
  }) async {
    final results = await Future.wait([
      getKurdishMovieSubtitle(title, releaseYear: releaseYear, tmdbId: tmdbId),
      _getOpenSubtitlesMovieSubtitles(tmdbId, title),
    ]);

    final kurdish   = results[0] as SubtitleTrack?;
    final osResults = results[1] as List<SubtitleTrack>;

    return [
      if (kurdish != null) kurdish,
      ...osResults,
    ];
  }

  /// Fetch subtitles for a TV show episode.
  static Future<List<SubtitleTrack>> getTvShowSubtitles(
    int tmdbId,
    String title, {
    int? season,
    int? episode,
  }) async {
    final List<Future<dynamic>> futures = [
      _getOpenSubtitlesTvShowSubtitles(tmdbId, title, season: season, episode: episode),
    ];

    if (season != null && episode != null) {
      futures.add(getKurdishTvSubtitle(title, season, episode));
    }

    final settled      = await Future.wait(futures);
    final osResults    = settled[0] as List<SubtitleTrack>;
    final kurdishTrack = futures.length > 1 ? settled[1] as SubtitleTrack? : null;

    return [
      if (kurdishTrack != null) kurdishTrack,
      ...osResults,
    ];
  }

  // ── OpenSubtitles (internal) ────────────────────────────────────────────────

  static Future<List<SubtitleTrack>> _getOpenSubtitlesMovieSubtitles(
    int tmdbId,
    String title,
  ) async {
    final imdbId = await _getImdbId(tmdbId, isMovie: true);
    List<SubtitleTrack> results = [];
    if (imdbId != null) results = await _searchByImdbId(imdbId);
    if (results.isEmpty) results = await _searchByQuery(_cleanTitle(title));
    return results;
  }

  static Future<List<SubtitleTrack>> _getOpenSubtitlesTvShowSubtitles(
    int tmdbId,
    String title, {
    int? season,
    int? episode,
  }) async {
    String? epImdbId;
    if (season != null && episode != null) {
      epImdbId = await _getEpisodeImdbId(tmdbId, season, episode);
    }

    List<SubtitleTrack> results = [];
    if (epImdbId != null) results = await _searchByImdbId(epImdbId);

    if (results.isEmpty) {
      final seriesImdbId = await _getImdbId(tmdbId, isMovie: false);
      if (seriesImdbId != null) {
        results = await _searchByImdbId(seriesImdbId, season: season, episode: episode);
      }
    }

    if (results.isEmpty) {
      String query = _cleanTitle(title);
      if (season != null && episode != null) {
        query += ' S${season.toString().padLeft(2, '0')}E${episode.toString().padLeft(2, '0')}';
      }
      results = await _searchByQuery(query, season: season, episode: episode);
    }

    if (results.isEmpty) {
      results = await _searchByQuery(_cleanTitle(title), season: season, episode: episode);
    }

    return results;
  }

  static Future<List<SubtitleTrack>> _searchByImdbId(
    String imdbId, {
    int? season,
    int? episode,
  }) async {
    final cleanId = imdbId.replaceAll('tt', '').padLeft(7, '0');
    String path   = '/search/imdbid-$cleanId';
    if (season != null) path  += '/season-$season';
    if (episode != null) path += '/episode-$episode';
    return _doSearch(path, season: season, episode: episode);
  }

  static Future<List<SubtitleTrack>> _searchByQuery(
    String query, {
    int? season,
    int? episode,
  }) async {
    final encodedQuery = Uri.encodeComponent(query);
    return _doSearch('/search/query-$encodedQuery', season: season, episode: episode);
  }

  static const List<String> _userAgents = [
    'TemporaryUserAgent',
    'LiveWavePlayer v1.2',
    'SubtitleDownloader 2.0',
    'OpenSubtitlesPlayer v1',
  ];

  static String _getRandomUA() =>
      _userAgents[DateTime.now().millisecond % _userAgents.length];

  static Future<List<SubtitleTrack>> _doSearch(
    String path, {
    int? season,
    int? episode,
  }) async {
    int attempt = 0;
    while (attempt < 2) {
      try {
        final url = '$_osBaseUrl$path';
        final ua  = _getRandomUA();
        debugPrint('[SubtitleService] Request (attempt ${attempt + 1}): $url UA=$ua');

        final response = await http
            .get(Uri.parse(url), headers: {'User-Agent': ua, 'Accept': 'application/json'})
            .timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          final dynamic data = jsonDecode(response.body);
          if (data is List && data.isNotEmpty) {
            return _processResults(data, filterSeason: season, filterEpisode: episode);
          }
          debugPrint('[SubtitleService] No results or unexpected format');
        } else if (response.statusCode == 429) {
          debugPrint('[SubtitleService] Rate limited (429)');
        } else {
          debugPrint('[SubtitleService] API error ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('[SubtitleService] Request error: $e');
      }

      attempt++;
      if (attempt < 2) await Future.delayed(const Duration(milliseconds: 1500));
    }
    return [];
  }

  static List<SubtitleTrack> _processResults(
    List<dynamic> results, {
    int? filterSeason,
    int? filterEpisode,
  }) {
    debugPrint(
      '[SubtitleService] Processing ${results.length} results '
      '(Filter: S$filterSeason E$filterEpisode)',
    );
    final Map<String, SubtitleTrack> bestByLang = {};

    for (final sub in results) {
      if (filterSeason != null || filterEpisode != null) {
        final subSeason  = int.tryParse(sub['SeriesSeason']?.toString()  ?? '-1');
        final subEpisode = int.tryParse(sub['SeriesEpisode']?.toString() ?? '-1');
        if (subSeason  != null && subSeason  > 0 && subSeason  != filterSeason)  continue;
        if (subEpisode != null && subEpisode > 0 && subEpisode != filterEpisode) continue;
      }

      final lang        = sub['LanguageName']?.toString() ?? 'Unknown';
      final langId      = sub['SubLanguageID']?.toString() ?? '';
      final format      = (sub['SubFormat']?.toString() ?? '').toLowerCase();
      final downloadUrl = sub['SubDownloadLink']?.toString() ?? '';
      final hi          = sub['SubHearingImpaired']?.toString() == '1';
      final downloads   = int.tryParse(sub['SubDownloadsCnt']?.toString() ?? '0') ?? 0;
      final fileName    = sub['SubFileName']?.toString() ?? '';

      if (format != 'srt' && format != 'vtt') continue;
      if (downloadUrl.isEmpty) continue;

      int score  = downloads;
      final fn   = fileName.toUpperCase();
      if (fn.contains('WEB-DL') || fn.contains('WEBRIP') || fn.contains('HDRIP')) {
        score += 50000;
      }
      if (fn.contains('BRRIP') || fn.contains('BLURAY')) score += 20000;
      if (format == 'srt') score += 1000;

      final key = '$lang-${hi ? 'HI' : 'Normal'}';
      if (!bestByLang.containsKey(key) || score > bestByLang[key]!.score) {
        bestByLang[key] = SubtitleTrack(
          language: lang,
          languageId: langId,
          fileName: fileName,
          downloadUrl: downloadUrl,
          format: format,
          isHearingImpaired: hi,
          downloadCount: downloads,
          score: score,
        );
      }
    }

    final sorted = bestByLang.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final priority    = ['English', 'Arabic', 'Kurdish', 'Persian'];
    final prioritized = <SubtitleTrack>[];
    final rest        = <SubtitleTrack>[];
    for (final track in sorted) {
      if (priority.any((p) => track.language.contains(p))) {
        prioritized.add(track);
      } else {
        rest.add(track);
      }
    }

    final finalResults = [...prioritized, ...rest];
    debugPrint(
      '[SubtitleService] Unique tracks: ${finalResults.length} '
      '(top: ${finalResults.isNotEmpty ? finalResults.first.language : "none"})',
    );
    return finalResults;
  }

  // ── Download & parse ────────────────────────────────────────────────────────

  static Future<String?> downloadAndExtractSubtitle(SubtitleTrack track) async {
    try {
      final url = track.downloadUrl;
      final isPrivateServer = url.contains('154.48.204.98') ||
                              url.contains('130.193.165.194') ||
                              url.contains('130.193.166.197') ||
                              url.contains('130.193.166.118') ||
                              url.contains('130.193.166.19');

      final Map<String, String> headers =
          isPrivateServer ? {} : {'User-Agent': _getRandomUA()};

      debugPrint('[SubtitleService] Downloading: ${track.downloadUrl}');
      final response = await http
          .get(Uri.parse(track.downloadUrl), headers: headers)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        debugPrint('[SubtitleService] Download HTTP ${response.statusCode}');
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final subDir  = Directory('${tempDir.path}/live_wave_subs');
      if (!subDir.existsSync()) subDir.createSync(recursive: true);

      final bytes = response.bodyBytes;
      List<int> decompressed;

      if (isPrivateServer) {
        // Kurdish servers send raw UTF-8 SRT (no gzip)
        decompressed = bytes;
      } else {
        try {
          decompressed = gzip.decode(bytes);
        } catch (_) {
          decompressed = bytes;
        }
      }

      final srtPath =
          '${subDir.path}/sub_${DateTime.now().millisecondsSinceEpoch}.${track.format}';
      await File(srtPath).writeAsBytes(decompressed);
      debugPrint('[SubtitleService] Saved ${decompressed.length} bytes → $srtPath');
      return srtPath;
    } catch (e) {
      debugPrint('[SubtitleService] Download error: $e');
    }
    return null;
  }

  static Future<List<SubtitleLine>> parseSrt(String filePath) async {
    try {
      final file     = File(filePath);
      if (!file.existsSync()) return [];
      final contents = await file.readAsString();
      // More robust block splitting (handles \r\n and various whitespace)
      final blocks   = contents.trim().split(RegExp(r'\r?\n\s*\r?\n'));
      final lines    = <SubtitleLine>[];
      final tsRe     = RegExp(
        r'(\d{2}:\d{2}:\d{2}[,. ]\d{3}) --> (\d{2}:\d{2}:\d{2}[,. ]\d{3})',
      );

      for (final block in blocks) {
        final blockLines = block.trim().split('\n');
        if (blockLines.length < 2) continue;

        final match = tsRe.firstMatch(block);
        if (match != null) {
          final start = _parseDuration(match.group(1)!);
          final end   = _parseDuration(match.group(2)!);
          final text = blockLines
              .skipWhile((l) => !l.contains(' --> '))
              .skip(1)
              .map((l) {
                // Remove \r, remove RTL/LTR marks, remove HTML tags (<i>), remove ASS tags ({\an8})
                return l
                    .replaceAll('\r', '')
                    .replaceAll(RegExp(r'[\u200f\u200e\u202b\u202a\u202c\u200c]'), '')
                    .replaceAll(RegExp(r'<[^>]*>'), '')
                    .replaceAll(RegExp(r'\{[^}]*\}'), '')
                    .trim();
              })
              .where((l) => l.isNotEmpty)
              .join('\n');
          
          if (text.isNotEmpty) {
            // Apply bidi formatting if Kurdish/Arabic text is detected to ensure proper punctuation rendering
            final bidiText = RegExp(r'[\u0600-\u06FF]').hasMatch(text)
                ? '\u202B$text\u202C' // RLE + text + PDF
                : text;
            lines.add(SubtitleLine(start: start, end: end, text: bidiText));
          }
        }
      }
      return lines;
    } catch (_) {
      return [];
    }
  }

  static Duration _parseDuration(String ts) {
    try {
      final cleanTs = ts.replaceAll(',', '.').trim();
      final parts   = cleanTs.split(':');
      final h       = int.parse(parts[0]);
      final m       = int.parse(parts[1]);
      final sParts  = parts[2].split('.');
      final s       = int.parse(sParts[0]);
      final ms      = int.parse(sParts[1]);
      return Duration(hours: h, minutes: m, seconds: s, milliseconds: ms);
    } catch (_) {
      return Duration.zero;
    }
  }

  static Future<String?> shiftSubtitle(String filePath, double seconds) async {
    try {
      final file    = File(filePath);
      if (!file.existsSync()) return null;
      final contents    = await file.readAsString();
      final rawLines    = contents.split('\n');
      final shifted     = <String>[];
      final tsRe        = RegExp(
        r'(\d{2}:\d{2}:\d{2}[,. ]\d{3}) --> (\d{2}:\d{2}:\d{2}[,. ]\d{3})',
      );
      final ms = (seconds * 1000).toInt();

      for (final line in rawLines) {
        final match = tsRe.firstMatch(line);
        if (match != null) {
          final start = _formatDuration(_parseDuration(match.group(1)!) + Duration(milliseconds: ms));
          final end   = _formatDuration(_parseDuration(match.group(2)!) + Duration(milliseconds: ms));
          shifted.add('$start --> $end');
        } else {
          shifted.add(line);
        }
      }

      final newPath = filePath
          .replaceAll('.srt', '_shifted.srt')
          .replaceAll('.vtt', '_shifted.vtt');
      await File(newPath).writeAsString(shifted.join('\n'));
      return newPath;
    } catch (_) {}
    return null;
  }

  static String _formatDuration(Duration d) {
    var dur     = d;
    if (dur.isNegative) dur = Duration.zero;
    final hours   = dur.inHours.toString().padLeft(2, '0');
    final minutes = (dur.inMinutes  % 60).toString().padLeft(2, '0');
    final secs    = (dur.inSeconds  % 60).toString().padLeft(2, '0');
    final millis  = (dur.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$hours:$minutes:$secs,$millis';
  }
}
