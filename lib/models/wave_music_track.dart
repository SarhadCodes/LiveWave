class WaveMusicTrack {
  final String id;
  final String title;
  final String artist;
  final String artistId;
  final String album;
  final String albumId;
  final String artworkUrl;
  final String audioUrl;
  final int durationMs;
  final bool explicit;
  final String? lyrics;
  final int trackNumber;
  final int year;
  final String provider;
  final String providerId;
  final bool isPreview;
  final String genre;
  final String access;
  final String permalinkUrl;
  final String description;
  final String mimeType;
  final Map<String, String> streamHeaders;

  const WaveMusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.artistId,
    required this.album,
    required this.albumId,
    required this.artworkUrl,
    required this.audioUrl,
    required this.durationMs,
    this.explicit = false,
    this.lyrics,
    this.trackNumber = 0,
    this.year = 0,
    this.provider = '',
    this.providerId = '',
    this.isPreview = false,
    this.genre = '',
    this.access = '',
    this.permalinkUrl = '',
    this.description = '',
    this.mimeType = '',
    this.streamHeaders = const {},
  });

  Duration get duration => Duration(milliseconds: durationMs);

  /// Fully playable according to the catalog. SoundCloud tracks with
  /// `access=playable` are playable even before a temporary stream URL exists.
  bool get isPlayable {
    final state = access.toLowerCase();
    if (state == 'blocked' || state == 'preview') return false;
    if (state == 'playable') return true;
    return audioUrl.trim().isNotEmpty;
  }

  String get streamUrl => audioUrl;

  String get soundCloudId {
    if (providerId.isNotEmpty) return providerId;
    const prefixes = ['sc_user_', 'sc_pl_', 'sc_'];
    for (final prefix in prefixes) {
      if (id.startsWith(prefix)) return id.substring(prefix.length);
    }
    return id;
  }

  String get unavailabilityMessage {
    final state = access.toLowerCase();
    if (state == 'preview' || isPreview) {
      return 'Only a SoundCloud preview is available for this track.';
    }
    if (state == 'blocked') {
      return 'This track is blocked or unavailable to stream.';
    }
    return 'This track is unavailable to stream.';
  }

  factory WaveMusicTrack.fromJson(Map<String, dynamic> json) {
    return WaveMusicTrack(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      artist: json['artist']?.toString() ?? '',
      artistId: json['artistId']?.toString() ?? '',
      album: json['album']?.toString() ?? '',
      albumId: json['albumId']?.toString() ?? '',
      artworkUrl: json['artworkUrl']?.toString() ?? '',
      audioUrl: (json['audioUrl'] ?? json['streamUrl'])?.toString() ?? '',
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      explicit: json['explicit'] == true,
      lyrics: json['lyrics']?.toString(),
      trackNumber: (json['trackNumber'] as num?)?.toInt() ?? 0,
      year: (json['year'] as num?)?.toInt() ?? 0,
      provider: json['provider']?.toString() ?? '',
      providerId: json['providerId']?.toString() ?? '',
      isPreview: json['isPreview'] == true,
      genre: json['genre']?.toString() ?? '',
      access: json['access']?.toString() ?? '',
      permalinkUrl: json['permalinkUrl']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      mimeType: json['mimeType']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    final persistAudio = provider == 'soundcloud' ? '' : audioUrl;
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'artistId': artistId,
      'album': album,
      'albumId': albumId,
      'artworkUrl': artworkUrl,
      'audioUrl': persistAudio,
      'streamUrl': persistAudio,
      'durationMs': durationMs,
      'explicit': explicit,
      'lyrics': lyrics,
      'trackNumber': trackNumber,
      'year': year,
      'provider': provider,
      'providerId': providerId,
      'isPreview': isPreview,
      'genre': genre,
      'access': access,
      'permalinkUrl': permalinkUrl,
      'description': description,
    };
  }

  Map<String, dynamic> toNativeMap() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'audioUrl': audioUrl,
        'durationMs': durationMs,
        'artworkUrl': artworkUrl,
        'mimeType': mimeType.isNotEmpty
            ? mimeType
            : (audioUrl.contains('.m3u8') ? 'application/x-mpegURL' : ''),
        if (streamHeaders.isNotEmpty) 'headers': streamHeaders,
      };

  WaveMusicTrack copyWith({
    String? audioUrl,
    int? durationMs,
    String? artworkUrl,
    String? mimeType,
    String? access,
    String? permalinkUrl,
    Map<String, String>? streamHeaders,
  }) {
    return WaveMusicTrack(
      id: id,
      title: title,
      artist: artist,
      artistId: artistId,
      album: album,
      albumId: albumId,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      durationMs: durationMs ?? this.durationMs,
      explicit: explicit,
      lyrics: lyrics,
      trackNumber: trackNumber,
      year: year,
      provider: provider,
      providerId: providerId,
      isPreview: isPreview,
      genre: genre,
      access: access ?? this.access,
      permalinkUrl: permalinkUrl ?? this.permalinkUrl,
      description: description,
      mimeType: mimeType ?? this.mimeType,
      streamHeaders: streamHeaders ?? this.streamHeaders,
    );
  }
}
