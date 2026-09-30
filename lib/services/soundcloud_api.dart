import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/wave_music_config.dart';
import 'wave_music_http.dart';

/// Official SoundCloud API client (OAuth 2.1 Client Credentials).
/// Tokens are reused — SoundCloud limits new client-credential tokens.
class SoundCloudApi {
  SoundCloudApi({WaveMusicHttp? http}) : _http = http ?? WaveMusicHttp(minGap: const Duration(milliseconds: 160));

  static final SoundCloudApi instance = SoundCloudApi();

  static const apiBase = 'https://api.soundcloud.com';
  static const tokenUrl = 'https://secure.soundcloud.com/oauth/token';
  static const _tokenPrefsKey = 'wave_sc_oauth_v1';

  final WaveMusicHttp _http;
  String? _accessToken;
  String? _refreshToken;
  DateTime _expiresAt = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void>? _refreshing;

  bool get isConfigured => WaveMusicConfig.soundCloudClientId.isNotEmpty && WaveMusicConfig.soundCloudClientSecret.isNotEmpty;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
    bool retryAuth = true,
  }) async {
    final uri = Uri.parse('$apiBase$path').replace(queryParameters: query);
    return getUri(uri, retryAuth: retryAuth);
  }

  Future<Map<String, dynamic>> getUri(Uri uri, {bool retryAuth = true}) async {
    try {
      return await _http.getJson(uri, headers: await _authHeaders());
    } on HttpException catch (e) {
      if (e.statusCode == 401 && retryAuth) {
        await _forceRefresh();
        return _http.getJson(uri, headers: await _authHeaders());
      }
      rethrow;
    }
  }

  /// `GET /tracks/{id}/streams` — official transcoding URLs.
  Future<Map<String, dynamic>> trackStreams(String trackId) {
    return getJson('/tracks/${Uri.encodeComponent(trackId)}/streams');
  }

  /// Follow redirects on an authenticated stream URL so Media3 can play the CDN URL.
  Future<String> resolveCdnUrl(String streamUrl) async {
    final uri = Uri.parse(streamUrl);
    if (_isCdn(uri)) return streamUrl;
    final redirected = await _http.resolveRedirect(uri, headers: await _authHeaders());
    return redirected.isNotEmpty ? redirected : streamUrl;
  }

  bool _isCdn(Uri uri) {
    final host = uri.host.toLowerCase();
    return host.contains('sndcdn.com') || host.contains('soundcloud.cloud') || host.contains('media-streaming');
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await accessToken();
    return {
      'Authorization': 'OAuth $token',
      'Accept': 'application/json; charset=utf-8',
    };
  }

  Future<String> accessToken() async {
    await _loadPersisted();
    if (_accessToken != null && DateTime.now().isBefore(_expiresAt.subtract(const Duration(minutes: 2)))) {
      return _accessToken!;
    }
    await _forceRefresh();
    final token = _accessToken;
    if (token == null || token.isEmpty) {
      throw StateError('SoundCloud authentication failed.');
    }
    return token;
  }

  Future<void> _forceRefresh() {
    return _refreshing ??= () async {
      try {
        if (_refreshToken != null && _refreshToken!.isNotEmpty) {
          try {
            await _exchange(grantType: 'refresh_token', refreshToken: _refreshToken);
            return;
          } catch (_) {
            _refreshToken = null;
          }
        }
        await _exchange(grantType: 'client_credentials');
      } finally {
        _refreshing = null;
      }
    }();
  }

  Future<void> _exchange({required String grantType, String? refreshToken}) async {
    if (!isConfigured) {
      throw StateError('SoundCloud is not configured.');
    }
    final id = WaveMusicConfig.soundCloudClientId;
    final secret = WaveMusicConfig.soundCloudClientSecret;
    final basic = base64Encode(utf8.encode('$id:$secret'));
    final body = <String, String>{'grant_type': grantType};
    if (grantType == 'refresh_token') {
      body['refresh_token'] = refreshToken ?? '';
      body['client_id'] = id;
      body['client_secret'] = secret;
    }
    final json = await _http.postForm(
      Uri.parse(tokenUrl),
      body: body,
      headers: grantType == 'client_credentials'
          ? {
              'Authorization': 'Basic $basic',
              'Accept': 'application/json; charset=utf-8',
            }
          : {
              'Accept': 'application/json; charset=utf-8',
            },
    );
    final access = json['access_token']?.toString() ?? '';
    if (access.isEmpty) {
      throw StateError('SoundCloud authentication failed.');
    }
    _accessToken = access;
    final refresh = json['refresh_token']?.toString();
    if (refresh != null && refresh.isNotEmpty) {
      _refreshToken = refresh;
    }
    final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 3600;
    _expiresAt = DateTime.now().add(Duration(seconds: expiresIn.clamp(60, 24 * 3600)));
    await _persist();
  }

  Future<void> _loadPersisted() async {
    if (_accessToken != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_tokenPrefsKey);
      if (raw == null || raw.isEmpty) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _accessToken = map['access']?.toString();
      _refreshToken = map['refresh']?.toString();
      _expiresAt = DateTime.tryParse(map['exp']?.toString() ?? '') ?? _expiresAt;
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _tokenPrefsKey,
        jsonEncode({
          'access': _accessToken,
          'refresh': _refreshToken,
          'exp': _expiresAt.toIso8601String(),
        }),
      );
    } catch (_) {}
  }
}
