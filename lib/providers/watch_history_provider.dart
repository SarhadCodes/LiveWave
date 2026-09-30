import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/watch_history_item.dart';
import '../screens/media_custom_player_screen.dart';
import '../services/download_service.dart';

class WatchHistoryProvider extends ChangeNotifier {
  static const _itemsKey = 'watch_history_items';
  static const _progressKey = 'watch_history_episode_progress';
  static const _minSaveMs = 8000;
  static const _completedFraction = 0.92;
  static const _maxItems = 40;

  List<WatchHistoryItem> _items = [];
  final Map<String, List<int>> _episodeProgress = {};
  bool _loaded = false;
  final Completer<void> _ready = Completer<void>();

  List<WatchHistoryItem> get continueWatching => List.unmodifiable(_items);

  List<WatchHistoryItem> get continueMovies =>
      _items.where((item) => item.isMovie).toList();

  List<WatchHistoryItem> get continueSeries =>
      _items.where((item) => !item.isMovie).toList();

  WatchHistoryProvider() {
    _load();
  }

  static String catalogKey({required int contentId, required bool isMovie}) {
    return isMovie ? 'movie:$contentId' : 'tv:$contentId';
  }

  static String episodeKey({
    required int contentId,
    required bool isMovie,
    int? season,
    int? episode,
  }) {
    if (isMovie) return catalogKey(contentId: contentId, isMovie: true);
    return 'tv:$contentId:s${season ?? 0}e${episode ?? 0}';
  }

  WatchHistoryItem? itemFor(int contentId, {required bool isMovie}) {
    final key = catalogKey(contentId: contentId, isMovie: isMovie);
    for (final item in _items) {
      if (item.key == key) return item;
    }
    return null;
  }

  int? resumePositionMs({
    required int contentId,
    required bool isMovie,
    int? season,
    int? episode,
  }) {
    final key = episodeKey(
      contentId: contentId,
      isMovie: isMovie,
      season: season,
      episode: episode,
    );
    final stored = _episodeProgress[key];
    if (stored != null && stored.isNotEmpty) {
      final position = stored[0];
      final duration = stored.length > 1 ? stored[1] : 0;
      if (_isCompleted(position, duration)) return null;
      if (position >= _minSaveMs) return position;
    }

    final item = itemFor(contentId, isMovie: isMovie);
    if (item == null) return null;
    if (!isMovie &&
        (item.season != season || item.episode != episode)) {
      return null;
    }
    if (_isCompleted(item.positionMs, item.durationMs)) return null;
    if (item.positionMs >= _minSaveMs) return item.positionMs;
    return null;
  }

  Future<void> recordProgress({
    required int contentId,
    required bool isMovie,
    required String title,
    String? seriesTitle,
    String posterPath = '',
    String backdropPath = '',
    int? tmdbId,
    int? xtreamSeriesId,
    String? streamUrl,
    int? season,
    int? episode,
    String? episodeTitle,
    required int positionMs,
    required int durationMs,
    int? releaseYear,
    bool notify = true,
  }) async {
    await _ready.future;
    if (contentId == 0 || positionMs < _minSaveMs) return;

    final key = catalogKey(contentId: contentId, isMovie: isMovie);
    final progressKey = episodeKey(
      contentId: contentId,
      isMovie: isMovie,
      season: season,
      episode: episode,
    );

    if (_isCompleted(positionMs, durationMs)) {
      _episodeProgress.remove(progressKey);
      _items.removeWhere((item) => item.key == key);
      await _persist();
      if (notify) notifyListeners();
      return;
    }

    _episodeProgress[progressKey] = [positionMs, durationMs];
    _items.removeWhere((item) => item.key == key);
    _items.insert(
      0,
      WatchHistoryItem(
        key: key,
        contentId: contentId,
        isMovie: isMovie,
        title: title,
        seriesTitle: seriesTitle,
        posterPath: posterPath,
        backdropPath: backdropPath,
        tmdbId: tmdbId,
        xtreamSeriesId: xtreamSeriesId,
        streamUrl: streamUrl,
        season: season,
        episode: episode,
        episodeTitle: episodeTitle,
        positionMs: positionMs,
        durationMs: durationMs,
        lastWatchedMs: DateTime.now().millisecondsSinceEpoch,
        releaseYear: releaseYear,
      ),
    );
    if (_items.length > _maxItems) {
      _items = _items.sublist(0, _maxItems);
    }
    await _persist();
    if (notify) notifyListeners();
  }

  Future<void> remove(String key) async {
    _items.removeWhere((item) => item.key == key);
    await _persist();
    notifyListeners();
  }

  Future<void> clear() async {
    _items.clear();
    _episodeProgress.clear();
    await _persist();
    notifyListeners();
  }

  static void play(BuildContext context, WatchHistoryItem item) {
    final downloads = Provider.of<DownloadService>(context, listen: false);
    String? customUrl = item.streamUrl;
    String? customSubtitleUrl;

    final downloadId = downloads.generateId(
      item.contentId,
      item.isMovie,
      season: item.season,
      episode: item.episode,
    );
    final download = downloads.getDownload(downloadId);
    if (download?.status == DownloadStatus.completed &&
        download!.localVideoPath.isNotEmpty) {
      customUrl = 'file://${download.localVideoPath}';
      if (download.localSubtitlePath != null) {
        customSubtitleUrl = 'file://${download.localSubtitlePath}';
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaCustomPlayerScreen(
          contentId: item.contentId,
          tmdbId: item.tmdbId,
          isMovie: item.isMovie,
          title: item.title,
          seriesTitle: item.seriesTitle,
          season: item.season,
          episode: item.episode,
          releaseYear: item.releaseYear,
          posterPath: item.posterPath,
          backdropPath: item.backdropPath,
          xtreamSeriesId: item.xtreamSeriesId,
          customUrl: customUrl,
          customSubtitleUrl: customSubtitleUrl,
        ),
      ),
    );
  }

  bool _isCompleted(int positionMs, int durationMs) {
    if (durationMs <= 0) return false;
    return positionMs / durationMs >= _completedFraction;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawItems = prefs.getString(_itemsKey);
      if (rawItems != null && rawItems.isNotEmpty) {
        final decoded = json.decode(rawItems);
        if (decoded is List) {
          _items = decoded
              .whereType<Map>()
              .map((item) => WatchHistoryItem.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .where((item) => item.contentId != 0)
              .toList();
        }
      }

      final rawProgress = prefs.getString(_progressKey);
      if (rawProgress != null && rawProgress.isNotEmpty) {
        final decoded = json.decode(rawProgress);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            if (value is List && value.length >= 2) {
              _episodeProgress[key.toString()] = [
                (value[0] as num).toInt(),
                (value[1] as num).toInt(),
              ];
            }
          });
        }
      }
      _loaded = true;
      if (!_ready.isCompleted) _ready.complete();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading watch history: $e');
      _loaded = true;
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  Future<void> _persist() async {
    if (!_loaded && _items.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _itemsKey,
        json.encode(_items.map((item) => item.toJson()).toList()),
      );
      await prefs.setString(
        _progressKey,
        json.encode(_episodeProgress),
      );
    } catch (e) {
      debugPrint('Error saving watch history: $e');
    }
  }
}
