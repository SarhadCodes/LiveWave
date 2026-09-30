import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/wave_creator.dart';
import '../models/wave_followed_creator.dart';
import '../models/wave_history_item.dart';
import '../models/wave_playback_progress.dart';
import '../models/wave_saved_video.dart';
import '../models/wave_video.dart';

/// Live Wave-owned Wave library. Not a YouTube account, subscription, or cloud sync.
class WaveLibraryProvider extends ChangeNotifier {
  static const _followedKey = 'wave_followed_creators';
  static const _watchLaterKey = 'wave_watch_later';
  static const _savedKey = 'wave_saved_videos';
  static const _historyKey = 'wave_history';
  static const _progressKey = 'wave_playback_progress';
  static const _maxHistory = 80;
  static const _maxLists = 80;

  final List<WaveFollowedCreator> _followed = [];
  final List<WaveSavedVideo> _watchLater = [];
  final List<WaveSavedVideo> _saved = [];
  final List<WaveHistoryItem> _history = [];
  final Map<String, WavePlaybackProgress> _progress = {};
  final Completer<void> _ready = Completer<void>();
  bool _loaded = false;

  List<WaveFollowedCreator> get followedCreators => List.unmodifiable(_followed);
  List<WaveSavedVideo> get watchLater => List.unmodifiable(_watchLater);
  List<WaveSavedVideo> get savedVideos => List.unmodifiable(_saved);
  List<WaveHistoryItem> get history => List.unmodifiable(_history);
  List<WaveHistoryItem> get continueWatching =>
      _history.where((item) => item.canResume).toList();

  WaveLibraryProvider() {
    _load();
  }

  Future<void> ensureLoaded() => _ready.future;

  bool isFollowed(String youtubeChannelId) {
    return _followed.any((item) => item.youtubeChannelId == youtubeChannelId);
  }

  bool isWatchLater(String videoId) {
    return _watchLater.any((item) => item.videoId == videoId);
  }

  bool isSaved(String videoId) {
    return _saved.any((item) => item.videoId == videoId);
  }

  WavePlaybackProgress? progressFor(String videoId) => _progress[videoId];

  Future<void> followCreator(WaveCreator creator) async {
    await ensureLoaded();
    if (creator.youtubeChannelId.isEmpty) return;
    _followed.removeWhere(
      (item) => item.youtubeChannelId == creator.youtubeChannelId,
    );
    _followed.insert(
      0,
      WaveFollowedCreator(
        youtubeChannelId: creator.youtubeChannelId,
        channelTitle: creator.title,
        thumbnailUrl: creator.thumbnailUrl,
        followedAt: DateTime.now(),
      ),
    );
    if (_followed.length > _maxLists) {
      _followed.removeRange(_maxLists, _followed.length);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> unfollowCreator(String youtubeChannelId) async {
    await ensureLoaded();
    _followed.removeWhere((item) => item.youtubeChannelId == youtubeChannelId);
    await _persist();
    notifyListeners();
  }

  Future<void> toggleFollow(WaveCreator creator) async {
    if (isFollowed(creator.youtubeChannelId)) {
      await unfollowCreator(creator.youtubeChannelId);
    } else {
      await followCreator(creator);
    }
  }

  Future<void> toggleWatchLater(WaveVideo video) async {
    await ensureLoaded();
    final index = _watchLater.indexWhere((item) => item.videoId == video.videoId);
    if (index >= 0) {
      _watchLater.removeAt(index);
    } else {
      _watchLater.insert(0, _savedFromVideo(video, watchLater: true));
      if (_watchLater.length > _maxLists) {
        _watchLater.removeRange(_maxLists, _watchLater.length);
      }
    }
    await _persist();
    notifyListeners();
  }

  Future<void> toggleSaved(WaveVideo video) async {
    await ensureLoaded();
    final index = _saved.indexWhere((item) => item.videoId == video.videoId);
    if (index >= 0) {
      _saved.removeAt(index);
    } else {
      _saved.insert(0, _savedFromVideo(video, watchLater: false));
      if (_saved.length > _maxLists) {
        _saved.removeRange(_maxLists, _saved.length);
      }
    }
    await _persist();
    notifyListeners();
  }

  Future<void> recordWatch({
    required WaveVideo video,
    int? positionSeconds,
    int? durationSeconds,
  }) async {
    await ensureLoaded();
    if (video.videoId.isEmpty) return;

    _history.removeWhere((item) => item.videoId == video.videoId);
    _history.insert(
      0,
      WaveHistoryItem(
        videoId: video.videoId,
        title: video.title,
        thumbnailUrl: video.thumbnailUrl,
        channelId: video.channelId,
        channelTitle: video.channelTitle,
        watchedAt: DateTime.now(),
        lastKnownPositionSeconds: positionSeconds,
        durationSeconds: durationSeconds ?? video.duration?.inSeconds,
      ),
    );
    if (_history.length > _maxHistory) {
      _history.removeRange(_maxHistory, _history.length);
    }

    if (positionSeconds != null && positionSeconds >= 8) {
      _progress[video.videoId] = WavePlaybackProgress(
        videoId: video.videoId,
        positionSeconds: positionSeconds,
        durationSeconds: durationSeconds ?? video.duration?.inSeconds,
        updatedAt: DateTime.now(),
      );
    }

    await _persist();
    notifyListeners();
  }

  Future<void> recordProgress({
    required WaveVideo video,
    required int positionSeconds,
    int? durationSeconds,
  }) async {
    await recordWatch(
      video: video,
      positionSeconds: positionSeconds,
      durationSeconds: durationSeconds,
    );
  }

  WaveSavedVideo _savedFromVideo(WaveVideo video, {required bool watchLater}) {
    return WaveSavedVideo(
      videoId: video.videoId,
      title: video.title,
      thumbnailUrl: video.thumbnailUrl,
      channelId: video.channelId,
      channelTitle: video.channelTitle,
      savedAt: DateTime.now(),
      watchLater: watchLater,
    );
  }

  WaveVideo videoFromSaved(WaveSavedVideo item) {
    return WaveVideo(
      videoId: item.videoId,
      title: item.title,
      channelId: item.channelId,
      channelTitle: item.channelTitle,
      thumbnailUrl: item.thumbnailUrl,
    );
  }

  WaveVideo videoFromHistory(WaveHistoryItem item) {
    return WaveVideo(
      videoId: item.videoId,
      title: item.title,
      channelId: item.channelId,
      channelTitle: item.channelTitle,
      thumbnailUrl: item.thumbnailUrl,
      duration: item.durationSeconds == null
          ? null
          : Duration(seconds: item.durationSeconds!),
    );
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _followed.addAll(_decodeList(prefs.getString(_followedKey), WaveFollowedCreator.fromJson));
      _watchLater.addAll(_decodeList(prefs.getString(_watchLaterKey), WaveSavedVideo.fromJson));
      _saved.addAll(_decodeList(prefs.getString(_savedKey), WaveSavedVideo.fromJson));
      _history.addAll(_decodeList(prefs.getString(_historyKey), WaveHistoryItem.fromJson));
      final rawProgress = prefs.getString(_progressKey);
      if (rawProgress != null && rawProgress.isNotEmpty) {
        final decoded = json.decode(rawProgress);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            if (value is Map) {
              _progress[key.toString()] = WavePlaybackProgress.fromJson(
                Map<String, dynamic>.from(value),
              );
            }
          });
        }
      }
    } catch (error) {
      debugPrint('Error loading Wave library: $error');
    } finally {
      _loaded = true;
      if (!_ready.isCompleted) _ready.complete();
      notifyListeners();
    }
  }

  List<T> _decodeList<T>(
    String? raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (raw == null || raw.isEmpty) return const [];
    final decoded = json.decode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((item) => fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> _persist() async {
    if (!_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _followedKey,
        json.encode(_followed.map((item) => item.toJson()).toList()),
      );
      await prefs.setString(
        _watchLaterKey,
        json.encode(_watchLater.map((item) => item.toJson()).toList()),
      );
      await prefs.setString(
        _savedKey,
        json.encode(_saved.map((item) => item.toJson()).toList()),
      );
      await prefs.setString(
        _historyKey,
        json.encode(_history.map((item) => item.toJson()).toList()),
      );
      await prefs.setString(
        _progressKey,
        json.encode(_progress.map((key, value) => MapEntry(key, value.toJson()))),
      );
    } catch (error) {
      debugPrint('Error saving Wave library: $error');
    }
  }
}
