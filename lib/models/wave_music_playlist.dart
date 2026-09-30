import 'wave_music_album.dart';
import 'wave_music_artist.dart';
import 'wave_music_track.dart';

class WaveMusicPlaylist {
  final String id;
  final String title;
  final String description;
  final String artworkUrl;
  final List<String> trackIds;
  final bool userCreated;
  final String provider;
  final String providerId;

  const WaveMusicPlaylist({
    required this.id,
    required this.title,
    this.description = '',
    this.artworkUrl = '',
    this.trackIds = const [],
    this.userCreated = false,
    this.provider = '',
    this.providerId = '',
  });

  WaveMusicPlaylist copyWith({
    String? title,
    String? description,
    String? artworkUrl,
    List<String>? trackIds,
  }) {
    return WaveMusicPlaylist(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      trackIds: trackIds ?? this.trackIds,
      userCreated: userCreated,
      provider: provider,
      providerId: providerId,
    );
  }

  factory WaveMusicPlaylist.fromJson(Map<String, dynamic> json) {
    return WaveMusicPlaylist(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      artworkUrl: json['artworkUrl']?.toString() ?? '',
      trackIds: (json['trackIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      userCreated: json['userCreated'] == true,
      provider: json['provider']?.toString() ?? '',
      providerId: json['providerId']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'artworkUrl': artworkUrl,
        'trackIds': trackIds,
        'userCreated': userCreated,
        'provider': provider,
        'providerId': providerId,
      };
}

class WaveMusicSearchResult {
  final List<WaveMusicTrack> tracks;
  final List<WaveMusicArtist> artists;
  final List<WaveMusicAlbum> albums;
  final List<WaveMusicPlaylist> playlists;
  final bool hasMore;
  final int nextOffset;

  const WaveMusicSearchResult({
    this.tracks = const [],
    this.artists = const [],
    this.albums = const [],
    this.playlists = const [],
    this.hasMore = false,
    this.nextOffset = 0,
  });
}

class WaveMusicHomeData {
  final List<WaveMusicTrack> quickPicks;
  final List<WaveMusicTrack> popularSongs;
  final List<WaveMusicTrack> trending;
  final List<WaveMusicArtist> popularArtists;
  final List<WaveMusicAlbum> newReleases;
  final List<WaveMusicAlbum> albums;
  final List<WaveMusicPlaylist> playlists;
  final List<WaveMusicTrack> recommended;

  const WaveMusicHomeData({
    this.quickPicks = const [],
    this.popularSongs = const [],
    this.trending = const [],
    this.popularArtists = const [],
    this.newReleases = const [],
    this.albums = const [],
    this.playlists = const [],
    this.recommended = const [],
  });
}

class WaveMusicArtistDetails {
  final WaveMusicArtist artist;
  final List<WaveMusicTrack> popular;
  final List<WaveMusicAlbum> albums;
  final List<WaveMusicAlbum> singles;
  final List<WaveMusicArtist> related;
  final List<WaveMusicPlaylist> playlists;

  const WaveMusicArtistDetails({
    required this.artist,
    this.popular = const [],
    this.albums = const [],
    this.singles = const [],
    this.related = const [],
    this.playlists = const [],
  });
}
