class WaveMusicArtist {
  final String id;
  final String name;
  final String artworkUrl;
  final String bio;
  final List<String> albumIds;
  final List<String> popularTrackIds;
  final List<String> relatedArtistIds;
  final String genre;
  final String provider;
  final String providerId;
  final int trackCount;

  const WaveMusicArtist({
    required this.id,
    required this.name,
    required this.artworkUrl,
    this.bio = '',
    this.albumIds = const [],
    this.popularTrackIds = const [],
    this.relatedArtistIds = const [],
    this.genre = '',
    this.provider = '',
    this.providerId = '',
    this.trackCount = 0,
  });

  WaveMusicArtist copyWith({
    String? name,
    String? artworkUrl,
    String? bio,
    List<String>? albumIds,
    List<String>? popularTrackIds,
    List<String>? relatedArtistIds,
    String? genre,
    int? trackCount,
  }) {
    return WaveMusicArtist(
      id: id,
      name: name ?? this.name,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      bio: bio ?? this.bio,
      albumIds: albumIds ?? this.albumIds,
      popularTrackIds: popularTrackIds ?? this.popularTrackIds,
      relatedArtistIds: relatedArtistIds ?? this.relatedArtistIds,
      genre: genre ?? this.genre,
      provider: provider,
      providerId: providerId,
      trackCount: trackCount ?? this.trackCount,
    );
  }

  factory WaveMusicArtist.fromJson(Map<String, dynamic> json) {
    return WaveMusicArtist(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      artworkUrl: json['artworkUrl']?.toString() ?? '',
      bio: json['bio']?.toString() ?? '',
      albumIds: (json['albumIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      popularTrackIds: (json['popularTrackIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      relatedArtistIds: (json['relatedArtistIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      genre: json['genre']?.toString() ?? '',
      provider: json['provider']?.toString() ?? '',
      providerId: json['providerId']?.toString() ?? '',
      trackCount: (json['trackCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'artworkUrl': artworkUrl,
        'bio': bio,
        'albumIds': albumIds,
        'popularTrackIds': popularTrackIds,
        'relatedArtistIds': relatedArtistIds,
        'genre': genre,
        'provider': provider,
        'providerId': providerId,
        'trackCount': trackCount,
      };
}
