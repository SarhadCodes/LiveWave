import '../models/wave_music_album.dart';
import '../models/wave_music_artist.dart';
import '../models/wave_music_playlist.dart';
import '../models/wave_music_track.dart';

/// Vendor-neutral catalog surface used by WAVE MUSIC.
abstract class WaveMusicCatalog {
  Future<WaveMusicSearchResult> search(String query, {int offset = 0, int limit = 25});
  Future<WaveMusicArtist?> getArtist(String id);
  Future<WaveMusicAlbum?> getAlbum(String id);
  Future<WaveMusicPlaylist?> getPlaylist(String id);
  Future<List<WaveMusicTrack>> getTrending({int limit = 40});
}

/// App catalog backend. UI talks to [WaveMusicService], never a vendor class.
abstract class WaveMusicCatalogService implements WaveMusicCatalog {
  Future<WaveMusicHomeData> getHome();
  Future<List<WaveMusicTrack>> getRecommendations({String? seedArtist});
  Future<List<WaveMusicTrack>> getSongs({int offset = 0, int limit = 40});
  Future<List<WaveMusicArtist>> getArtists({int limit = 30});
  Future<WaveMusicArtistDetails> getArtistDetails(String id);
  Future<List<WaveMusicAlbum>> getAlbums({int limit = 30});
  Future<List<WaveMusicPlaylist>> getPlaylists();
  Future<WaveMusicTrack?> getTrack(String id);
  Future<List<WaveMusicTrack>> tracksForIds(List<String> ids);
  Future<List<WaveMusicTrack>> getRelatedTracks(WaveMusicTrack track);
}

/// Playback source is always a legitimate [WaveMusicTrack.audioUrl] / [WaveMusicTrack.streamUrl].
/// Native Media3 remains the only audio engine.
abstract class WaveMusicPlaybackSource {
  Future<String?> resolveAudioUrl(WaveMusicTrack track);
}
