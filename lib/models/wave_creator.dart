class WaveCreator {
  final String youtubeChannelId;
  final String title;
  final String thumbnailUrl;
  final String? description;
  final int? subscriberCount;
  final int? videoCount;
  final String? uploadsPlaylistId;

  const WaveCreator({
    required this.youtubeChannelId,
    required this.title,
    required this.thumbnailUrl,
    this.description,
    this.subscriberCount,
    this.videoCount,
    this.uploadsPlaylistId,
  });

  factory WaveCreator.fromJson(Map<String, dynamic> json) {
    return WaveCreator(
      youtubeChannelId: json['youtubeChannelId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      description: json['description'] as String?,
      subscriberCount: (json['subscriberCount'] as num?)?.toInt(),
      videoCount: (json['videoCount'] as num?)?.toInt(),
      uploadsPlaylistId: json['uploadsPlaylistId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'youtubeChannelId': youtubeChannelId,
      'title': title,
      'thumbnailUrl': thumbnailUrl,
      'description': description,
      'subscriberCount': subscriberCount,
      'videoCount': videoCount,
      'uploadsPlaylistId': uploadsPlaylistId,
    };
  }
}
