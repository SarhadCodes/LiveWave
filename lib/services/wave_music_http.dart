import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

class WaveMusicHttp {
  WaveMusicHttp({
    http.Client? client,
    this.minGap = const Duration(milliseconds: 120),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration minGap;
  DateTime _nextSlot = DateTime.fromMillisecondsSinceEpoch(0);

  static const _userAgent = 'WAVE-Music/1.0 (Android; catalog)';

  Future<Map<String, dynamic>> getJson(
    Uri uri, {
    int retries = 1,
    Map<String, String>? headers,
  }) async {
    Object? last;
    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        await _throttle();
        final response = await _client
            .get(uri, headers: {
              'User-Agent': _userAgent,
              'Accept': 'application/json',
              ...?headers,
            })
            .timeout(const Duration(seconds: 10));
        return _decodeMap(response, uri);
      } catch (e) {
        last = e;
        if (e is HttpException && !e.retryable) break;
        if (attempt == retries) break;
        await Future<void>.delayed(Duration(milliseconds: 350 * pow(2, attempt).toInt()));
      }
    }
    throw last ?? Exception('Request failed');
  }

  Future<Map<String, dynamic>> postForm(
    Uri uri, {
    required Map<String, String> body,
    Map<String, String>? headers,
  }) async {
    await _throttle();
    final response = await _client
        .post(
          uri,
          headers: {
            'User-Agent': _userAgent,
            'Content-Type': 'application/x-www-form-urlencoded',
            ...?headers,
          },
          body: body,
        )
        .timeout(const Duration(seconds: 12));
    return _decodeMap(response, uri);
  }

  /// HEAD/GET a URL with auth headers and return the final (often CDN) location.
  Future<String> resolveRedirect(Uri uri, {Map<String, String>? headers}) async {
    await _throttle();
    final common = {
      'User-Agent': _userAgent,
      ...?headers,
    };
    try {
      final head = http.Request('HEAD', uri)
        ..followRedirects = false
        ..headers.addAll(common);
      final headed = await _client.send(head).timeout(const Duration(seconds: 10));
      final location = headed.headers['location'];
      if (location != null && location.isNotEmpty && headed.statusCode >= 300 && headed.statusCode < 400) {
        return uri.resolve(location).toString();
      }
      if (headed.statusCode >= 200 && headed.statusCode < 300) {
        return uri.toString();
      }
    } catch (_) {}
    final get = http.Request('GET', uri)
      ..followRedirects = true
      ..headers.addAll(common);
    final streamed = await _client.send(get).timeout(const Duration(seconds: 12));
    await streamed.stream.drain<void>();
    if (streamed.statusCode == 429) {
      throw HttpException('HTTP 429', uri: uri, statusCode: 429);
    }
    if (streamed.statusCode < 200 || streamed.statusCode >= 400) {
      throw HttpException('HTTP ${streamed.statusCode}', uri: uri, statusCode: streamed.statusCode);
    }
    return streamed.request?.url.toString() ?? uri.toString();
  }

  Map<String, dynamic> _decodeMap(http.Response response, Uri uri) {
    if (response.statusCode == 429) {
      throw HttpException('HTTP 429', uri: uri, statusCode: 429);
    }
    if (response.statusCode >= 500) {
      throw HttpException('HTTP ${response.statusCode}', uri: uri, statusCode: response.statusCode);
    }
    if (response.statusCode == 400 || response.statusCode == 404) {
      return const {};
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('HTTP ${response.statusCode}', uri: uri, statusCode: response.statusCode);
    }
    if (response.bodyBytes.isEmpty) return const {};
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {'data': decoded};
  }

  Future<void> _throttle() async {
    final now = DateTime.now();
    if (now.isBefore(_nextSlot)) {
      await Future<void>.delayed(_nextSlot.difference(now));
    }
    _nextSlot = DateTime.now().add(minGap);
  }
}

class HttpException implements Exception {
  HttpException(this.message, {this.uri, this.statusCode});
  final String message;
  final Uri? uri;
  final int? statusCode;
  bool get retryable => statusCode == null || statusCode! >= 500;
  @override
  String toString() => message;
}
