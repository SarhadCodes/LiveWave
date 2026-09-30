import 'package:flutter/foundation.dart';

import '../config/wave_music_config.dart';
import '../models/wave_music_album.dart';
import '../models/wave_music_artist.dart';
import '../models/wave_music_playlist.dart';
import '../models/wave_music_track.dart';
import 'audius_music_catalog.dart';
import 'itunes_music_catalog.dart';
import 'newpipe_music_catalog.dart';
import 'soundcloud_music_catalog.dart';
import 'wave_music_catalog.dart';
import 'wave_music_playback_resolver.dart';
import 'youtube_music_catalog.dart';

/// App-facing catalog. UI must not import a vendor catalog.
class WaveMusicService implements WaveMusicCatalogService {
  WaveMusicService._() : _backend = _createBackend();

  static WaveMusicCatalogService _createBackend() {
    if (WaveMusicConfig.useItunes) return ITunesMusicCatalog();
    if (WaveMusicConfig.useAudiusCatalog) return AudiusMusicCatalog();
    if (WaveMusicConfig.useYoutubeCatalog) return YouTubeMusicCatalog();
    if (WaveMusicConfig.useSoundCloud) return SoundCloudMusicCatalog();
    return NewPipeMusicCatalog();
  }

  static final WaveMusicService instance = WaveMusicService._();

  final WaveMusicCatalogService _backend;

  Future<void> ensureLoaded() async {
    try {
      await _backend.getHome();
    } catch (_) {}
  }

  Future<WaveMusicTrack> resolveAudio(
    WaveMusicTrack track, {
    bool force = false,
    bool startPlayback = true,
  }) {
    debugPrintSynchronously('[WAVE_FUTURE] service BEFORE resolve id=${track.id}');
    final future = WaveMusicPlaybackResolver.instance.resolve(
      track,
      force: force,
      startPlayback: startPlayback,
    );
    debugPrintSynchronously(
      '[WAVE_FUTURE] service AFTER got future hash=${identityHashCode(future)} type=${future.runtimeType} id=${track.id}',
    );
    return future;
  }

  Future<List<WaveMusicTrack>> resolveQueue(List<WaveMusicTrack> tracks) {
    return Future.wait(tracks.map(resolveAudio));
  }

  @override
  Future<WaveMusicHomeData> getHome() => _backend.getHome();

  @override
  Future<List<WaveMusicTrack>> getTrending({int limit = 40}) => _backend.getTrending(limit: limit);

  @override
  Future<List<WaveMusicTrack>> getRecommendations({String? seedArtist}) =>
      _backend.getRecommendations(seedArtist: seedArtist);

  @override
  Future<List<WaveMusicTrack>> getSongs({int offset = 0, int limit = 40}) =>
      _backend.getSongs(offset: offset, limit: limit);

  @override
  Future<List<WaveMusicArtist>> getArtists({int limit = 30}) => _backend.getArtists(limit: limit);

  @override
  Future<WaveMusicArtist?> getArtist(String id) => _backend.getArtist(id);

  @override
  Future<WaveMusicArtistDetails> getArtistDetails(String id) => _backend.getArtistDetails(id);

  @override
  Future<List<WaveMusicAlbum>> getAlbums({int limit = 30}) => _backend.getAlbums(limit: limit);

  @override
  Future<WaveMusicAlbum?> getAlbum(String id) => _backend.getAlbum(id);

  @override
  Future<List<WaveMusicPlaylist>> getPlaylists() => _backend.getPlaylists();

  @override
  Future<WaveMusicPlaylist?> getPlaylist(String id) => _backend.getPlaylist(id);

  @override
  Future<WaveMusicTrack?> getTrack(String id) => _backend.getTrack(id);

  @override
  Future<List<WaveMusicTrack>> tracksForIds(List<String> ids) => _backend.tracksForIds(ids);

  @override
  Future<List<WaveMusicTrack>> getRelatedTracks(WaveMusicTrack track) => _backend.getRelatedTracks(track);

  @override
  Future<WaveMusicSearchResult> search(String query, {int offset = 0, int limit = 25}) =>
      _backend.search(query, offset: offset, limit: limit);
}

class PreviewPlaybackSource implements WaveMusicPlaybackSource {
  @override
  Future<String?> resolveAudioUrl(WaveMusicTrack track) async {
    final resolved = await WaveMusicPlaybackResolver.instance.resolvePlaybackUrl(track);
    return resolved?.url;
  }
}
