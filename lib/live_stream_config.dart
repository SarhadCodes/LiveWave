/// HTTP headers for IPTV streams (HLS primary, TS progressive fallback).
abstract final class LiveStreamConfig {
  static const _userAgents = [
    'IPTV Smarters Pro',
    'VLC/3.0.20 LibVLC/3.0.20',
    'XP Player',
    'Mozilla/5.0 (Linux; Android 10; Android TV) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  ];

  static int _userAgentIndex = 0;

  static Map<String, String> headersFor(String streamUrl) {
    final uri = Uri.tryParse(streamUrl);
    final referer = uri != null ? _origin(uri) : null;

    return {
      'User-Agent': _userAgents[_userAgentIndex % _userAgents.length],
      'Accept': '*/*',
      'Accept-Encoding': 'identity',
      if (referer != null) 'Referer': referer,
    };
  }

  static Map<String, String> nextHeadersFor(String streamUrl) {
    _userAgentIndex++;
    return headersFor(streamUrl);
  }

  /// Progressive .ts first for Xtream/redirect providers; HLS as secondary fallback.
  static List<String> liveSourceCandidates(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return const [];

    if (trimmed.endsWith('.ts')) {
      return [trimmed, normalizeToHls(trimmed)];
    }
    if (trimmed.endsWith('.m3u8')) {
      final tsVariant =
          '${trimmed.substring(0, trimmed.length - 5)}ts';
      return [trimmed, tsVariant];
    }
    return [normalizeToHls(trimmed)];
  }

  static String normalizeToHls(String url) {
    final trimmed = url.trim();
    if (trimmed.endsWith('.ts')) {
      return '${trimmed.substring(0, trimmed.length - 3)}m3u8';
    }
    return trimmed;
  }

  static String _origin(Uri uri) {
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port/';
  }
}
