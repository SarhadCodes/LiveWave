class WaveMusicAlbum {
  final String id;
  final String title;
  final String artist;
  final String artistId;
  final String artworkUrl;
  final int year;
  final List<String> trackIds;
  final int trackCount;
  final bool isSingle;
  final String provider;
  final String providerId;

  const WaveMusicAlbum({
    required this.id,
    required this.title,
    required this.artist,
    required this.artistId,
    required this.artworkUrl,
    required this.year,
    this.trackIds = const [],
    this.trackCount = 0,
    this.isSingle = false,
    this.provider = '',
    this.providerId = '',
  });

  factory WaveMusicAlbum.fromJson(Map<String, dynamic> json) {
    return WaveMusicAlbum(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      artist: json['artist']?.toString() ?? '',
      artistId: json['artistId']?.toString() ?? '',
      artworkUrl: json['artworkUrl']?.toString() ?? '',
      year: (json['year'] as num?)?.toInt() ?? 0,
      trackIds: (json['trackIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      trackCount: (json['trackCount'] as num?)?.toInt() ?? 0,
      isSingle: json['isSingle'] == true,
      provider: json['provider']?.toString() ?? '',
      providerId: json['providerId']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'artistId': artistId,
        'artworkUrl': artworkUrl,
        'year': year,
        'trackIds': trackIds,
        'trackCount': trackCount,
        'isSingle': isSingle,
        'provider': provider,
        'providerId': providerId,
      };
}
