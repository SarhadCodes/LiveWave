import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/wave_config.dart';
import '../models/movie.dart';

class TelegramIngestService {
  static const _baseKey = 'telegram_ingest_base_url';
  static const _tokenKey = 'telegram_admin_token';

  static String? _baseUrl;
  static String? _token;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = (prefs.getString(_baseKey) ?? '').trim();
    _token = (prefs.getString(_tokenKey) ?? '').trim();
    if (_baseUrl == null || _baseUrl!.isEmpty) {
      _baseUrl = WaveConfig.telegramIngestBaseUrl;
    }
  }

  static String get baseUrl => (_baseUrl ?? WaveConfig.telegramIngestBaseUrl).replaceAll(RegExp(r'/$'), '');
  static String get adminToken => _token ?? '';

  static Future<void> saveConnection({required String baseUrl, required String token}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseKey, baseUrl.trim());
    await prefs.setString(_tokenKey, token.trim());
    _baseUrl = baseUrl.trim();
    _token = token.trim();
  }

  static Map<String, String> _adminHeaders() => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $adminToken',
      };

  static Future<List<Movie>> fetchPublished() async {
    try {
      await load();
      if (baseUrl.isEmpty) return const [];
      final res = await http.get(Uri.parse('$baseUrl/api/movies')).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return const [];
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final items = (body['items'] as List?) ?? const [];
      return items.map((e) => Movie.fromTelegram(Map<String, dynamic>.from(e as Map))).toList();
    } catch (e) {
      debugPrint('[TelegramIngest] catalog: $e');
      return const [];
    }
  }

  static Future<Map<String, dynamic>> status() => _get('/api/admin/telegram/status');

  static Future<Map<String, dynamic>> reviewQueue() => _get('/api/admin/telegram/review');

  static Future<Map<String, dynamic>> imports({String? statusFilter}) {
    final q = statusFilter == null ? '' : '?status=$statusFilter';
    return _get('/api/admin/telegram/imports$q');
  }

  static Future<Map<String, dynamic>> importLimit(int limit) =>
      _post('/api/admin/telegram/import', {'limit': limit});

  static Future<Map<String, dynamic>> startMonitor() => _post('/api/admin/telegram/monitor/start');

  static Future<Map<String, dynamic>> stopMonitor() => _post('/api/admin/telegram/monitor/stop');

  static Future<Map<String, dynamic>> approve(int id, [Map<String, dynamic>? edits]) =>
      _post('/api/admin/telegram/review/$id/approve', edits);

  static Future<Map<String, dynamic>> reject(int id) =>
      _post('/api/admin/telegram/review/$id/reject');

  static Future<Map<String, dynamic>> reprocess(int id) =>
      _post('/api/admin/telegram/reprocess/$id');

  static Future<Map<String, dynamic>> reprocessFailed() =>
      _post('/api/admin/telegram/reprocess-failed');

  static Future<Map<String, dynamic>> reprocessAll() =>
      _post('/api/admin/telegram/reprocess-all');

  static Future<Map<String, dynamic>> patchSettings(Map<String, dynamic> patch) async {
    await load();
    final res = await http
        .patch(Uri.parse('$baseUrl/api/admin/telegram/settings'), headers: _adminHeaders(), body: jsonEncode(patch))
        .timeout(const Duration(seconds: 20));
    return _decode(res);
  }

  static Future<Map<String, dynamic>> _get(String path) async {
    await load();
    final res = await http.get(Uri.parse('$baseUrl$path'), headers: _adminHeaders()).timeout(const Duration(seconds: 20));
    return _decode(res);
  }

  static Future<Map<String, dynamic>> _post(String path, [Map<String, dynamic>? body]) async {
    await load();
    final res = await http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: _adminHeaders(),
          body: jsonEncode(body ?? {}),
        )
        .timeout(const Duration(seconds: 120));
    return _decode(res);
  }

  static Map<String, dynamic> _decode(http.Response res) {
    final body = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw Exception(body is Map ? (body['error'] ?? res.body) : res.body);
    }
    return Map<String, dynamic>.from(body as Map);
  }
}
