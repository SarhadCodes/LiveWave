import '../models/wave_music_lyrics.dart';
import '../models/wave_music_track.dart';
import 'wave_music_cache.dart';
import 'wave_music_http.dart';

/// Public LRCLIB lyrics API. No scraping, no invented text.
class WaveMusicLyricsService {
  WaveMusicLyricsService({WaveMusicHttp? http, WaveMusicCache? cache})
      : _http = http ?? WaveMusicHttp(),
        _cache = cache ?? WaveMusicCache.instance;

  static final instance = WaveMusicLyricsService();

  final WaveMusicHttp _http;
  final WaveMusicCache _cache;

  Future<WaveMusicLyrics> getLyrics(WaveMusicTrack track) async {
    final key = 'lyrics:${track.id}';
    final cached = _cache.get<WaveMusicLyrics>(key);
    if (cached != null) return cached;

    if (track.title.trim().isEmpty || track.artist.trim().isEmpty) {
      return WaveMusicLyrics(trackId: track.id);
    }

    try {
      final uri = Uri.https('lrclib.net', '/api/get', {
        'artist_name': track.artist.split(RegExp(r'[,&]')).first.trim(),
        'track_name': track.title.replaceAll(RegExp(r'\s*\(.*\)\s*'), '').trim(),
        if (track.album.isNotEmpty) 'album_name': track.album,
      });
      final json = await _http.getJson(uri, retries: 1);
      final lyrics = _parse(track.id, json);
      _cache.set(key, lyrics, ttl: const Duration(hours: 12));
      return lyrics;
    } catch (_) {
      return WaveMusicLyrics(trackId: track.id);
    }
  }

  WaveMusicLyrics _parse(String trackId, Map<String, dynamic> json) {
    if (json.isEmpty || json['statusCode'] == 404) {
      return WaveMusicLyrics(trackId: trackId);
    }
    final plain = json['plainLyrics']?.toString();
    final syncedRaw = json['syncedLyrics']?.toString();
    return WaveMusicLyrics(
      trackId: trackId,
      plain: (plain != null && plain.trim().isNotEmpty) ? plain.trim() : null,
      synced: _parseLrc(syncedRaw),
    );
  }

  List<WaveMusicLyricLine> _parseLrc(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    final lines = <WaveMusicLyricLine>[];
    final re = RegExp(r'\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\](.*)');
    for (final line in raw.split('\n')) {
      final match = re.firstMatch(line.trim());
      if (match == null) continue;
      final minutes = int.tryParse(match.group(1) ?? '') ?? 0;
      final seconds = int.tryParse(match.group(2) ?? '') ?? 0;
      var fraction = match.group(3) ?? '0';
      if (fraction.length == 1) fraction = '${fraction}00';
      if (fraction.length == 2) fraction = '${fraction}0';
      final ms = int.tryParse(fraction.padRight(3, '0').substring(0, 3)) ?? 0;
      final text = (match.group(4) ?? '').trim();
      if (text.isEmpty) continue;
      lines.add(
        WaveMusicLyricLine(
          at: Duration(minutes: minutes, seconds: seconds, milliseconds: ms),
          text: text,
        ),
      );
    }
    return lines;
  }
}
