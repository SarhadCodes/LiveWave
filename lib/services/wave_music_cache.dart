import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class WaveMusicCache {
  WaveMusicCache._();
  static final WaveMusicCache instance = WaveMusicCache._();

  final Map<String, _Entry> _memory = {};
  static const _prefix = 'wave_music_cache_v2_';

  T? get<T>(String key) {
    final entry = _memory[key];
    if (entry == null) return null;
    if (entry.expires.isBefore(DateTime.now())) {
      _memory.remove(key);
      return null;
    }
    return entry.value as T?;
  }

  void set(String key, Object value, {Duration ttl = const Duration(minutes: 30)}) {
    _memory[key] = _Entry(value, DateTime.now().add(ttl));
    if (_memory.length > 120) {
      final oldest = _memory.keys.take(_memory.length - 100).toList();
      for (final k in oldest) {
        _memory.remove(k);
      }
    }
  }

  Future<Map<String, dynamic>?> readDisk(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$key');
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final exp = DateTime.tryParse(map['exp']?.toString() ?? '');
      if (exp == null || exp.isBefore(DateTime.now())) {
        await prefs.remove('$_prefix$key');
        return null;
      }
      final data = map['data'];
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
    } catch (_) {}
    return null;
  }

  Future<void> writeDisk(String key, Map<String, dynamic> data, {Duration ttl = const Duration(minutes: 30)}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_prefix$key',
        jsonEncode({
          'exp': DateTime.now().add(ttl).toIso8601String(),
          'data': data,
        }),
      );
    } catch (_) {}
  }
}

class _Entry {
  final Object value;
  final DateTime expires;
  _Entry(this.value, this.expires);
}
