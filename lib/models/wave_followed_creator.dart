/// A YouTube creator followed inside Live Wave.
/// This is not a YouTube subscription and must never be treated as one.
class WaveFollowedCreator {
  final String youtubeChannelId;
  final String channelTitle;
  final String thumbnailUrl;
  final DateTime followedAt;

  const WaveFollowedCreator({
    required this.youtubeChannelId,
    required this.channelTitle,
    required this.thumbnailUrl,
    required this.followedAt,
  });

  factory WaveFollowedCreator.fromJson(Map<String, dynamic> json) {
    return WaveFollowedCreator(
      youtubeChannelId: json['youtubeChannelId'] as String? ?? '',
      channelTitle: json['channelTitle'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      followedAt: DateTime.tryParse(json['followedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'youtubeChannelId': youtubeChannelId,
      'channelTitle': channelTitle,
      'thumbnailUrl': thumbnailUrl,
      'followedAt': followedAt.toIso8601String(),
    };
  }
}
