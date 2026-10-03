import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/wave_music_album.dart';
import '../models/wave_music_artist.dart';
import '../models/wave_music_playlist.dart';
import '../models/wave_music_track.dart';
import '../services/ios_youtube_music.dart';
import '../services/wave_music_playback_resolver.dart';
import '../services/wave_music_player.dart';
import '../services/wave_music_service.dart';

enum WaveMusicTab { home, songs, albums, artists, playlists, liked, recent, search }

class WaveMusicRecentItem {
  final WaveMusicTrack track;
  final DateTime playedAt;
  final int positionMs;

  const WaveMusicRecentItem({
    required this.track,
    required this.playedAt,
    this.positionMs = 0,
  });
}

/// Owns catalog, queue, likes, playlists, recents. Playback ticks stay on [player].
class WaveMusicProvider extends ChangeNotifier {
  WaveMusicProvider({
    WaveMusicService? service,
    WaveMusicPlayer? player,
  })  : _service = service ?? WaveMusicService.instance,
        player = player ?? WaveMusicPlayer.instance {
    this.player.onMediaIndex = _onNativeIndex;
    this.player.onPlaybackError = (message) => unawaited(_onPlaybackError(message));
    this.player.onSkipToNext = () => skipToNextValid();
    this.player.onSkipToPrevious = () => unawaited(previous());
    this.player.onTrackEnded = () {
      if (this.player.repeat == WaveMusicRepeatMode.one) return;
      unawaited(skipToNextValid());
    };
    this.player.position.addListener(_onPositionTick);
    this.player.playing.addListener(_onPlayingChanged);
    unawaited(load());
  }

  static const _likedKey = 'wave_music_liked_tracks_v2';
  static const _playlistsKey = 'wave_music_playlists';
  static const _recentKey = 'wave_music_recent_v2';
  static const _followedKey = 'wave_music_followed_artists_v2';
  static const _searchKey = 'wave_music_recent_queries';
  static const _maxRecent = 40;

  final WaveMusicService _service;
  final WaveMusicPlayer player;

  bool loading = false;
  String? loadError;
  WaveMusicTab tab = WaveMusicTab.home;
  WaveMusicHomeData? home;

  List<WaveMusicTrack> songs = const [];
  List<WaveMusicAlbum> albums = const [];
  List<WaveMusicArtist> artists = const [];
  List<WaveMusicPlaylist> catalogPlaylists = const [];

  final List<WaveMusicTrack> queue = [];
  int queueIndex = 0;
  WaveMusicTrack? currentTrack;

  final List<WaveMusicTrack> likedTracks = [];
  final List<WaveMusicPlaylist> userPlaylists = [];
  final List<WaveMusicRecentItem> recents = [];
  final List<WaveMusicArtist> followedArtists = [];
  bool fullPlayerOpen = false;

  String searchQuery = '';
  WaveMusicSearchResult searchResult = const WaveMusicSearchResult();
  bool searching = false;
  String? searchError;
  final List<String> recentQueries = [];
  Timer? _searchDebounce;
  DateTime _lastPositionSave = DateTime.fromMillisecondsSinceEpoch(0);
  String? _streamRetryId;
  bool _playInFlight = false;
  int _transitionEpoch = 0;
  int? _transitionTarget;
  int? _transitionInFlight;
  Future<void>? _transitionDone;
  List<WaveMusicTrack>? _orderBeforeShuffle;
  int _warmGeneration = 0;

  bool get hasQueue => currentTrack != null;
  bool get isPlaying => player.playing.value;
  List<String> get likedIds => likedTracks.map((t) => t.id).toList();
  List<String> get followedArtistIds => followedArtists.map((a) => a.id).toList();
  List<WaveMusicRecentItem> get continueListening {
    return recents.where((item) {
      if (item.positionMs < 3000) return false;
      final end = item.track.durationMs;
      if (end <= 0) return true;
      return item.positionMs < end - 2500;
    }).take(8).toList();
  }

  Future<void> load() async {
    if (home != null || loading) return;
    loading = true;
    loadError = null;
    notifyListeners();
    try {
      await player.bind();
      await _restoreLocal();
      home = await _service.getHome();
      songs = home!.trending.isNotEmpty ? home!.trending : await _service.getSongs();
      albums = home!.albums;
      artists = home!.popularArtists;
      catalogPlaylists = home!.playlists;
      loading = false;
      notifyListeners();
      _warmTracks(songs);
      unawaited(_enrichHome());
    } catch (e) {
      loading = false;
      loadError = _friendlyError(e);
      notifyListeners();
    }
  }

  Future<void> _enrichHome() async {
    try {
      final extraPlaylists = await _service.getPlaylists();
      if (extraPlaylists.isNotEmpty) {
        catalogPlaylists = extraPlaylists;
      }
      List<WaveMusicTrack> rec = home?.recommended ?? const [];
      if (recents.isNotEmpty) {
        rec = await _service.getRecommendations(seedArtist: recents.first.track.artist);
      }
      if (home == null) return;
      home = WaveMusicHomeData(
        quickPicks: home!.quickPicks,
        popularSongs: home!.popularSongs,
        trending: home!.trending,
        popularArtists: home!.popularArtists,
        newReleases: home!.newReleases,
        albums: home!.albums,
        playlists: extraPlaylists.isNotEmpty ? extraPlaylists : home!.playlists,
        recommended: rec.isNotEmpty ? rec : home!.recommended,
      );
      notifyListeners();
    } catch (_) {}
  }

  Future<void> retryLoad() async {
    home = null;
    await load();
  }

  void setTab(WaveMusicTab value) {
    if (tab == value) return;
    tab = value;
    notifyListeners();
  }

  Future<void> playTracks(List<WaveMusicTrack> tracks, {int startIndex = 0, Duration? startAt}) async {
    if (tracks.isEmpty) return;
    final candidates = tracks.where((t) => t.isPlayable).toList();
    if (candidates.isEmpty) {
      player.error.value = tracks.first.unavailabilityMessage;
      notifyListeners();
      return;
    }
    final targetId = tracks[startIndex.clamp(0, tracks.length - 1)].id;
    var index = candidates.indexWhere((t) => t.id == targetId);
    if (index < 0) index = 0;
    _playInFlight = true;
    final selected = candidates[index];
    final ios = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    debugPrint('[WAVE_PLAY] id=${selected.id} title=${selected.title} artist=${selected.artist}');
    if (ios) {
      debugPrint('[WAVE_IOS_MUSIC] playTrack started title=${selected.title}');
    }
    try {
      final WaveMusicTrack resolved;
      try {
        debugPrintSynchronously('[WAVE_FUTURE] playTracks BEFORE await id=${selected.id}');
        if (ios) debugPrint('[WAVE_IOS_MUSIC] resolver invoke title=${selected.title}');
        resolved = await _service.resolveAudio(selected);
        debugPrintSynchronously('[WAVE_FUTURE] playTracks AFTER await id=${selected.id}');
        if (ios) {
          debugPrint(
            '[WAVE_IOS_MUSIC] resolver returned title=${selected.title} '
            'urlEmpty=${resolved.audioUrl.trim().isEmpty} mime=${resolved.mimeType}',
          );
        }
      } catch (e) {
        player.error.value = _friendlyError(e);
        debugPrint('[WAVE_PLAY] resolve failed id=${selected.id}');
        if (ios) debugPrint('[WAVE_IOS_MUSIC] resolver threw title=${selected.title} error=$e');
        notifyListeners();
        return;
      }
      if (resolved.audioUrl.trim().isEmpty) {
        player.error.value = selected.unavailabilityMessage;
        debugPrint('[WAVE_PLAY] aborted empty stream id=${selected.id} title=${selected.title}');
        if (ios) debugPrint('[WAVE_IOS_MUSIC] stop before setQueue: empty resolve title=${selected.title}');
        notifyListeners();
        return;
      }
      queue
        ..clear()
        ..addAll(candidates);
      queue[index] = resolved;
      queueIndex = index;
      currentTrack = resolved;
      _streamRetryId = null;
      // iOS setQueue waits for AVPlayerItem ready. Open the player UI first so a
      // slow/failing native load does not look like "track never opened".
      if (ios) {
        player.playing.value = false;
        player.buffering.value = true;
        player.error.value = null;
        notifyListeners();
        debugPrint('[WAVE_IOS_MUSIC] player UI opened title=${selected.title}');
      }
      final handedOff = WaveMusicPlaybackResolver.instance.takeNativeHandoff(resolved.id);
      if (handedOff) {
        // Native already prepared this item inside the resolve reply.
        // Notifying or printing here re-enters the platform thread before
        // that reply returns, and the UI thread never comes back.
        _stageRecent(resolved, positionMs: startAt?.inMilliseconds ?? 0);
      } else {
        if (ios) debugPrint('[WAVE_IOS_MUSIC] setQueue invoke title=${selected.title}');
        await player.setQueue([resolved], startIndex: 0, play: true);
        if (ios) {
          debugPrint(
            '[WAVE_IOS_MUSIC] setQueue returned title=${selected.title} '
            'error=${player.error.value ?? 'none'}',
          );
        }
        var playing = resolved;
        // One alternate AAC/MP4 candidate if AVPlayer rejected the first URL.
        if (ios && player.error.value != null) {
          final failedKey = IosYoutubeMusic.streamKey(resolved.audioUrl);
          debugPrint('[WAVE_IOS_MUSIC] trying alternate stream title=${selected.title}');
          final alternate = await IosYoutubeMusic.resolveTrack(
            selected,
            excludeKeys: {failedKey},
          );
          if (alternate.audioUrl.startsWith('http') &&
              IosYoutubeMusic.streamKey(alternate.audioUrl) != failedKey) {
            player.error.value = null;
            queue[index] = alternate;
            currentTrack = alternate;
            playing = alternate;
            notifyListeners();
            debugPrint('[WAVE_IOS_MUSIC] setQueue retry invoke title=${selected.title}');
            await player.setQueue([alternate], startIndex: 0, play: true);
            debugPrint(
              '[WAVE_IOS_MUSIC] setQueue retry returned title=${selected.title} '
              'error=${player.error.value ?? 'none'}',
            );
          } else {
            debugPrint('[WAVE_IOS_MUSIC] no alternate stream title=${selected.title}');
          }
        }
        if (startAt != null && startAt.inMilliseconds > 0) {
          await player.seek(startAt);
        }
        _stageRecent(playing, positionMs: startAt?.inMilliseconds ?? 0);
        notifyListeners();
        await _persist();
      }
    } finally {
      _playInFlight = false;
      _warmUpcoming();
      if (_transitionTarget != null && _transitionDone == null) {
        _startTransition();
      }
    }
  }

  Future<void> playRecent(WaveMusicRecentItem item) {
    return playTracks(
      [item.track, ...recents.map((e) => e.track).where((t) => t.id != item.track.id)],
      startAt: item.positionMs > 3000 ? Duration(milliseconds: item.positionMs) : null,
    );
  }

  Future<void> playTrack(WaveMusicTrack track, {List<WaveMusicTrack>? contextQueue}) {
    final list = contextQueue != null && contextQueue.isNotEmpty ? contextQueue : [track];
    final index = max(0, list.indexWhere((t) => t.id == track.id));
    return playTracks(list, startIndex: index < 0 ? 0 : index);
  }

  Future<void> playAlbum(WaveMusicAlbum album, {bool shuffle = false}) async {
    var resolved = album;
    if (album.trackIds.isEmpty) {
      resolved = await _service.getAlbum(album.id) ?? album;
    }
    final tracks = await _service.tracksForIds(resolved.trackIds);
    if (shuffle) tracks.shuffle();
    await player.setShuffle(shuffle);
    await playTracks(tracks);
  }

  Future<void> playArtist(WaveMusicArtist artist, {bool shuffle = false}) async {
    var tracks = await _service.tracksForIds(artist.popularTrackIds);
    if (tracks.isEmpty) {
      final details = await _service.getArtistDetails(artist.id);
      tracks = List<WaveMusicTrack>.from(details.popular);
    }
    if (tracks.isEmpty) {
      final albumTracks = <WaveMusicTrack>[];
      for (final id in artist.albumIds) {
        final album = await _service.getAlbum(id);
        if (album != null) {
          albumTracks.addAll(await _service.tracksForIds(album.trackIds));
        }
      }
      if (shuffle) albumTracks.shuffle();
      await player.setShuffle(shuffle);
      await playTracks(albumTracks);
      return;
    }
    if (shuffle) tracks.shuffle();
    await player.setShuffle(shuffle);
    await playTracks(tracks);
  }

  Future<void> playPlaylist(WaveMusicPlaylist playlist, {bool shuffle = false}) async {
    final tracks = await _service.tracksForIds(playlist.trackIds);
    if (shuffle) tracks.shuffle();
    await player.setShuffle(shuffle);
    await playTracks(tracks);
  }

  Future<void> playLiked({bool shuffle = false}) async {
    final tracks = List<WaveMusicTrack>.from(likedTracks);
    if (shuffle) tracks.shuffle();
    await player.setShuffle(shuffle);
    await playTracks(tracks);
  }

  Future<void> togglePlayPause() => player.toggle();

  Future<void> next() async {
    if (queue.isEmpty) return;
    await skipToNextValid();
  }

  Future<void> previous() async {
    if (queue.isEmpty) return;
    if (player.position.value.inSeconds >= 3 || queueIndex <= 0) {
      await player.seek(Duration.zero);
      return;
    }
    await _requestTransition(queueIndex - 1);
  }

  /// Plays a row already in the queue. Resolves that track, then hands it to Media3.
  Future<void> playFromQueue(int index) => _requestTransition(index);

  Future<void> seek(Duration to) => player.seek(to);

  Future<void> toggleShuffle() async {
    final enabled = !player.shuffle;
    if (queue.length > 1) {
      if (enabled) {
        _orderBeforeShuffle = List<WaveMusicTrack>.from(queue);
        final current = queue.removeAt(queueIndex.clamp(0, queue.length - 1));
        queue.shuffle(Random());
        queue.insert(0, current);
        queueIndex = 0;
        currentTrack = current;
      } else if (_orderBeforeShuffle != null) {
        final id = currentTrack?.id;
        queue
          ..clear()
          ..addAll(_orderBeforeShuffle!);
        _orderBeforeShuffle = null;
        final i = id == null ? 0 : queue.indexWhere((t) => t.id == id);
        queueIndex = i < 0 ? 0 : i;
        if (queue.isNotEmpty) currentTrack = queue[queueIndex];
      }
    }
    await player.setShuffle(enabled);
    notifyListeners();
    _warmUpcoming();
  }

  Future<void> cycleRepeat() async {
    final next = switch (player.repeat) {
      WaveMusicRepeatMode.off => WaveMusicRepeatMode.all,
      WaveMusicRepeatMode.all => WaveMusicRepeatMode.one,
      WaveMusicRepeatMode.one => WaveMusicRepeatMode.off,
    };
    await player.setRepeat(next);
    notifyListeners();
  }

  Future<void> addToQueue(WaveMusicTrack track) async {
    if (queue.any((t) => t.id == track.id) && currentTrack == null) return;
    if (queue.isEmpty) {
      await playTrack(track);
      return;
    }
    queue.add(track);
    _orderBeforeShuffle?.add(track);
    notifyListeners();
  }

  Future<void> playNext(WaveMusicTrack track) async {
    if (queue.isEmpty) {
      await playTrack(track);
      return;
    }
    final insertAt = (queueIndex + 1).clamp(0, queue.length);
    queue.insert(insertAt, track);
    if (_orderBeforeShuffle != null) {
      final savedAt = (_orderBeforeShuffle!.indexWhere((t) => t.id == currentTrack?.id) + 1)
          .clamp(0, _orderBeforeShuffle!.length);
      _orderBeforeShuffle!.insert(savedAt, track);
    }
    notifyListeners();
    _warmUpcoming();
  }

  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= queue.length) return;
    if (queue.length == 1) {
      await clearQueue();
      return;
    }
    final removed = queue.removeAt(index);
    _orderBeforeShuffle?.removeWhere((t) => t.id == removed.id);
    final removedCurrent = index == queueIndex;
    if (index < queueIndex) {
      queueIndex -= 1;
    }
    notifyListeners();
    if (removedCurrent) {
      queueIndex = index.clamp(0, queue.length - 1);
      await _requestTransition(queueIndex);
    }
  }

  Future<void> moveQueueItem(int from, int to) async {
    if (from < 0 || from >= queue.length || to < 0 || to >= queue.length || from == to) return;
    final item = queue.removeAt(from);
    queue.insert(to, item);
    if (from == queueIndex) {
      queueIndex = to;
    } else if (from < queueIndex && to >= queueIndex) {
      queueIndex -= 1;
    } else if (from > queueIndex && to <= queueIndex) {
      queueIndex += 1;
    }
    _retarget(from, to);
    notifyListeners();
  }

  Future<void> clearQueue() async {
    _transitionTarget = null;
    _transitionEpoch++;
    _transitionInFlight = null;
    _orderBeforeShuffle = null;
    queue.clear();
    queueIndex = 0;
    currentTrack = null;
    await player.stop();
    notifyListeners();
  }

  Future<void> skipToNextValid() {
    debugPrintSynchronously(
      '[WAVE_PLAY] skip next queue=${queue.length} index=$queueIndex inFlight=$_playInFlight',
    );
    if (queue.isEmpty) return Future.value();
    final nextIndex = _followingIndex(queueIndex);
    if (nextIndex < 0) return Future.value();
    return _requestTransition(nextIndex);
  }

  int _followingIndex(int from) {
    if (queue.isEmpty) return -1;
    final next = from + 1;
    if (next < queue.length) return next;
    if (player.repeat == WaveMusicRepeatMode.all && queue.first.isPlayable) return 0;
    return -1;
  }

  /// Resolves stream URLs ahead of the tap. Playback is not started.
  /// A newer warm replaces the previous list. The extract already running
  /// finishes, then the loop stops.
  void _warmUpcoming() {
    if (currentTrack == null || queue.isEmpty) return;
    final next = _followingIndex(queueIndex);
    if (next < 0) return;
    _beginWarm([queue[next]]);
  }

  void _warmTracks(List<WaveMusicTrack> tracks) {
    if (currentTrack != null) return;
    _beginWarm(
      tracks.where((track) => track.provider == 'youtube' && track.isPlayable).take(3).toList(),
    );
  }

  void _beginWarm(List<WaveMusicTrack> tracks) {
    final generation = ++_warmGeneration;
    if (tracks.isEmpty) return;
    unawaited(_warm(generation, tracks));
  }

  Future<void> _warm(int generation, List<WaveMusicTrack> tracks) async {
    for (final track in tracks) {
      if (generation != _warmGeneration) return;
      try {
        await _service.resolveAudio(track, startPlayback: false);
      } catch (_) {}
    }
  }

  /// One queue change at a time. A newer Next/Previous replaces the target.
  /// The in-flight resolve is ignored when it finishes if a newer change won.
  Future<void> _requestTransition(int index) {
    if (index < 0 || index >= queue.length) return Future.value();
    if (_transitionInFlight == index && _transitionTarget == null) {
      return _transitionDone ?? Future.value();
    }
    if (_transitionTarget == index) {
      return _transitionDone ?? Future.value();
    }
    _transitionTarget = index;
    _transitionEpoch++;
    if (_playInFlight || _transitionDone != null) {
      return _transitionDone ?? Future.value();
    }
    return _startTransition();
  }

  Future<void> _startTransition() {
    final run = _drainTransitions();
    late final Future<void> wrapped;
    wrapped = run.then((_) {
      _transitionInFlight = null;
      if (_transitionTarget != null && !_playInFlight) {
        return _startTransition();
      }
      if (identical(_transitionDone, wrapped)) _transitionDone = null;
    });
    _transitionDone = wrapped;
    return wrapped;
  }

  Future<void> _drainTransitions() async {
    while (_transitionTarget != null) {
      final index = _transitionTarget!;
      _transitionTarget = null;
      if (index < 0 || index >= queue.length) break;
      final epoch = _transitionEpoch;
      final track = queue[index];
      _transitionInFlight = index;
      if (!track.isPlayable) {
        debugPrint('[WAVE_PLAY] queue skip unplayable id=${track.id} title=${track.title}');
        continue;
      }
      debugPrint('[WAVE_PLAY] queue transition index=$index id=${track.id} title=${track.title}');
      final WaveMusicTrack resolved;
      try {
        resolved = await _service.resolveAudio(track);
      } catch (e) {
        if (epoch != _transitionEpoch) continue;
        player.error.value = _friendlyError(e);
        debugPrint('[WAVE_PLAY] resolve failed id=${track.id}');
        notifyListeners();
        continue;
      }
      if (epoch != _transitionEpoch) continue;
      final url = resolved.audioUrl.trim();
      final mime = resolved.mimeType.trim().toLowerCase();
      if (!url.startsWith('http') || (mime.isNotEmpty && !mime.startsWith('audio/'))) {
        player.error.value = track.unavailabilityMessage;
        continue;
      }
      final handedOff = WaveMusicPlaybackResolver.instance.takeNativeHandoff(resolved.id);
      if (epoch != _transitionEpoch) continue;
      final at = (index < queue.length && queue[index].id == track.id)
          ? index
          : queue.indexWhere((t) => t.id == track.id);
      if (at < 0) continue;
      queue[at] = resolved;
      queueIndex = at;
      currentTrack = resolved;
      _streamRetryId = null;
      _stageRecent(resolved);
      if (handedOff) continue;
      await player.setQueue([resolved], startIndex: 0, play: true);
      notifyListeners();
      await _recordRecent(resolved);
    }
    _warmUpcoming();
  }

  void _retarget(int from, int to) {
    _transitionTarget = _shiftIndex(_transitionTarget, from, to);
    _transitionInFlight = _shiftIndex(_transitionInFlight, from, to);
  }

  int? _shiftIndex(int? index, int from, int to) {
    if (index == null) return null;
    if (index == from) return to;
    if (from < index && to >= index) return index - 1;
    if (from > index && to <= index) return index + 1;
    return index;
  }

  void _onNativeIndex(int index) {
    if (_transitionDone != null) return;
    final id = player.currentMediaId ?? '';
    if (id.isEmpty) return;
    final i = queue.indexWhere((t) => t.id == id);
    if (i < 0) return;
    if (queueIndex != i || currentTrack?.id != id) {
      queueIndex = i;
      currentTrack = queue[i];
      _stageRecent(currentTrack!);
    }
    notifyListeners();
  }

  Future<void> _onPlaybackError(String message) async {
    final track = currentTrack;
    if (track == null || _playInFlight || _transitionDone != null) return;
    if (_streamRetryId != track.id) {
      _streamRetryId = track.id;
      try {
        final fresh = await _service.resolveAudio(track, force: true);
        if (fresh.audioUrl.trim().isNotEmpty) {
          queue[queueIndex] = fresh;
          currentTrack = fresh;
          if (!WaveMusicPlaybackResolver.instance.takeNativeHandoff(fresh.id)) {
            await player.setQueue([fresh], startIndex: 0, play: true);
          }
          return;
        }
      } catch (_) {}
    }
    _streamRetryId = null;
    player.error.value = track.unavailabilityMessage;
    notifyListeners();
    await skipToNextValid();
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('YouTube Music search is available on Android')) {
      return 'Music search is available on Android.';
    }
    if (text.contains('not configured')) {
      return 'SoundCloud is not configured. Add SOUNDCLOUD_CLIENT_ID and SOUNDCLOUD_CLIENT_SECRET.';
    }
    if (text.contains('authentication failed') || text.contains('HTTP 401')) {
      return 'SoundCloud authentication failed. Check API credentials.';
    }
    if (text.contains('HTTP 403')) {
      return 'This track is not available to stream.';
    }
    if (text.contains('HTTP 429')) {
      return 'SoundCloud rate limit reached. Try again shortly.';
    }
    if (text.contains('HTTP 5') || text.contains('Timeout') || text.contains('Socket')) {
      return 'Music catalog unavailable. Check your connection and try again.';
    }
    return 'Music catalog unavailable. Check your connection and try again.';
  }

  bool isLiked(String trackId) => likedTracks.any((t) => t.id == trackId);

  Future<void> toggleLike(WaveMusicTrack track) async {
    final i = likedTracks.indexWhere((t) => t.id == track.id);
    if (i >= 0) {
      likedTracks.removeAt(i);
    } else {
      likedTracks.insert(0, track);
    }
    await _persist();
    notifyListeners();
  }

  bool isFollowed(String artistId) => followedArtists.any((a) => a.id == artistId);

  Future<void> toggleFollow(String artistId, {WaveMusicArtist? artist}) async {
    final i = followedArtists.indexWhere((a) => a.id == artistId);
    if (i >= 0) {
      followedArtists.removeAt(i);
    } else if (artist != null) {
      followedArtists.insert(0, artist);
    } else {
      followedArtists.insert(0, WaveMusicArtist(id: artistId, name: artistId, artworkUrl: ''));
    }
    await _persist();
    notifyListeners();
  }

  Future<WaveMusicPlaylist> createPlaylist(String title) async {
    final playlist = WaveMusicPlaylist(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      title: title.trim().isEmpty ? 'Playlist' : title.trim(),
      userCreated: true,
    );
    userPlaylists.insert(0, playlist);
    await _persist();
    notifyListeners();
    return playlist;
  }

  Future<void> renamePlaylist(String id, String title) async {
    final i = userPlaylists.indexWhere((p) => p.id == id);
    if (i < 0) return;
    userPlaylists[i] = userPlaylists[i].copyWith(title: title.trim());
    await _persist();
    notifyListeners();
  }

  Future<void> deletePlaylist(String id) async {
    userPlaylists.removeWhere((p) => p.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> addTrackToPlaylist(String playlistId, WaveMusicTrack track) async {
    final i = userPlaylists.indexWhere((p) => p.id == playlistId);
    if (i < 0) return;
    final ids = List<String>.from(userPlaylists[i].trackIds);
    if (ids.contains(track.id)) return;
    ids.add(track.id);
    userPlaylists[i] = userPlaylists[i].copyWith(
      trackIds: ids,
      artworkUrl: userPlaylists[i].artworkUrl.isEmpty ? track.artworkUrl : userPlaylists[i].artworkUrl,
    );
    await _persist();
    notifyListeners();
  }

  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    final i = userPlaylists.indexWhere((p) => p.id == playlistId);
    if (i < 0) return;
    final ids = List<String>.from(userPlaylists[i].trackIds)..remove(trackId);
    userPlaylists[i] = userPlaylists[i].copyWith(trackIds: ids);
    await _persist();
    notifyListeners();
  }

  Future<void> reorderPlaylistTracks(String playlistId, int from, int to) async {
    final i = userPlaylists.indexWhere((p) => p.id == playlistId);
    if (i < 0) return;
    final ids = List<String>.from(userPlaylists[i].trackIds);
    if (from < 0 || from >= ids.length || to < 0 || to >= ids.length) return;
    final id = ids.removeAt(from);
    ids.insert(to, id);
    userPlaylists[i] = userPlaylists[i].copyWith(trackIds: ids);
    await _persist();
    notifyListeners();
  }

  WaveMusicPlaylist? playlistById(String id) {
    for (final p in userPlaylists) {
      if (p.id == id) return p;
    }
    for (final p in catalogPlaylists) {
      if (p.id == id) return p;
    }
    return null;
  }

  void onSearchChanged(String query) {
    searchQuery = query;
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      searching = false;
      searchError = null;
      searchResult = const WaveMusicSearchResult();
      notifyListeners();
      return;
    }
    searching = true;
    notifyListeners();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      unawaited(_runSearch(query.trim()));
    });
  }

  Future<void> _runSearch(String query, {bool loadMore = false}) async {
    searching = true;
    searchError = null;
    notifyListeners();
    try {
      final offset = loadMore ? searchResult.nextOffset : 0;
      final result = await _service.search(query, offset: offset);
      if (loadMore) {
        searchResult = WaveMusicSearchResult(
          tracks: [...searchResult.tracks, ...result.tracks],
          artists: searchResult.artists,
          albums: searchResult.albums,
          playlists: searchResult.playlists,
          hasMore: result.hasMore,
          nextOffset: result.nextOffset,
        );
      } else {
        searchResult = result;
        recentQueries.remove(query);
        recentQueries.insert(0, query);
        if (recentQueries.length > 12) recentQueries.removeLast();
      }
      searching = false;
      await _persist();
      notifyListeners();
      _warmTracks(loadMore ? result.tracks : searchResult.tracks);
    } catch (e) {
      searching = false;
      searchError = _friendlyError(e);
      notifyListeners();
    }
  }

  Future<void> loadMoreSearch() async {
    if (!searchResult.hasMore || searching || searchQuery.trim().isEmpty) return;
    await _runSearch(searchQuery.trim(), loadMore: true);
  }

  void setFullPlayerOpen(bool open) {
    if (fullPlayerOpen == open) return;
    fullPlayerOpen = open;
    notifyListeners();
  }

  void _stageRecent(WaveMusicTrack track, {int positionMs = 0}) {
    recents.removeWhere((item) => item.track.id == track.id);
    recents.insert(
      0,
      WaveMusicRecentItem(track: track, playedAt: DateTime.now(), positionMs: positionMs),
    );
    if (recents.length > _maxRecent) {
      recents.removeRange(_maxRecent, recents.length);
    }
  }

  Future<void> _recordRecent(WaveMusicTrack track, {int positionMs = 0}) async {
    _stageRecent(track, positionMs: positionMs);
    await _persist();
  }

  void _onPositionTick() {
    if (currentTrack == null) return;
    final now = DateTime.now();
    if (now.difference(_lastPositionSave).inSeconds < 5) return;
    _lastPositionSave = now;
    unawaited(_touchRecentPosition(player.position.value.inMilliseconds));
  }

  void _onPlayingChanged() {
    if (!player.playing.value) {
      unawaited(_touchRecentPosition(player.position.value.inMilliseconds));
    }
  }

  Future<void> _touchRecentPosition(int positionMs) async {
    if (currentTrack == null || recents.isEmpty) return;
    if (recents.first.track.id != currentTrack!.id) return;
    recents[0] = WaveMusicRecentItem(
      track: recents.first.track,
      playedAt: recents.first.playedAt,
      positionMs: positionMs,
    );
    await _persist();
  }

  Future<void> _restoreLocal() async {
    final prefs = await SharedPreferences.getInstance();
    likedTracks
      ..clear()
      ..addAll(_decodeTracks(prefs.getString(_likedKey)));
    followedArtists
      ..clear()
      ..addAll(_decodeArtists(prefs.getString(_followedKey)));
    userPlaylists
      ..clear()
      ..addAll(_decodePlaylists(prefs.getString(_playlistsKey)));
    recents
      ..clear()
      ..addAll(_decodeRecents(prefs.getString(_recentKey)));
    recentQueries
      ..clear()
      ..addAll(prefs.getStringList(_searchKey) ?? const []);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_likedKey, jsonEncode(likedTracks.map((t) => t.toJson()).toList()));
    await prefs.setString(_followedKey, jsonEncode(followedArtists.map((a) => a.toJson()).toList()));
    await prefs.setString(_playlistsKey, jsonEncode(userPlaylists.map((p) => p.toJson()).toList()));
    await prefs.setStringList(_searchKey, recentQueries);
    await prefs.setString(
      _recentKey,
      jsonEncode(
        recents
            .map((item) => {
                  'track': item.track.toJson(),
                  'playedAt': item.playedAt.toIso8601String(),
                  'positionMs': item.positionMs,
                })
            .toList(),
      ),
    );
  }

  List<WaveMusicPlaylist> _decodePlaylists(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.whereType<Map>().map((e) => WaveMusicPlaylist.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return [];
    }
  }

  List<WaveMusicTrack> _decodeTracks(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.whereType<Map>().map((e) => WaveMusicTrack.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return [];
    }
  }

  List<WaveMusicArtist> _decodeArtists(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.whereType<Map>().map((e) => WaveMusicArtist.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return [];
    }
  }

  List<WaveMusicRecentItem> _decodeRecents(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final items = <WaveMusicRecentItem>[];
      for (final entry in list) {
        if (entry is! Map) continue;
        final map = Map<String, dynamic>.from(entry);
        WaveMusicTrack? track;
        if (map['track'] is Map) {
          track = WaveMusicTrack.fromJson(Map<String, dynamic>.from(map['track'] as Map));
        }
        if (track == null) continue;
        items.add(
          WaveMusicRecentItem(
            track: track,
            playedAt: DateTime.tryParse(map['playedAt']?.toString() ?? '') ?? DateTime.now(),
            positionMs: (map['positionMs'] as num?)?.toInt() ?? 0,
          ),
        );
      }
      return items;
    } catch (_) {
      return [];
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    player.position.removeListener(_onPositionTick);
    player.playing.removeListener(_onPlayingChanged);
    super.dispose();
  }
}
