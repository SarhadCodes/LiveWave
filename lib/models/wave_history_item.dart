class WaveHistoryItem {
  final String videoId;
  final String title;
  final String thumbnailUrl;
  final String channelId;
  final String channelTitle;
  final DateTime watchedAt;
  final int? lastKnownPositionSeconds;
  final int? durationSeconds;

  const WaveHistoryItem({
    required this.videoId,
    required this.title,
    required this.thumbnailUrl,
    required this.channelId,
    required this.channelTitle,
    required this.watchedAt,
    this.lastKnownPositionSeconds,
    this.durationSeconds,
  });

  bool get canResume {
    final position = lastKnownPositionSeconds ?? 0;
    final duration = durationSeconds ?? 0;
    if (position < 8) return false;
    if (duration <= 0) return position >= 8;
    return position / duration < 0.92;
  }

  factory WaveHistoryItem.fromJson(Map<String, dynamic> json) {
    return WaveHistoryItem(
      videoId: json['videoId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      channelId: json['channelId'] as String? ?? '',
      channelTitle: json['channelTitle'] as String? ?? '',
      watchedAt: DateTime.tryParse(json['watchedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      lastKnownPositionSeconds:
          (json['lastKnownPositionSeconds'] as num?)?.toInt(),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'videoId': videoId,
      'title': title,
      'thumbnailUrl': thumbnailUrl,
      'channelId': channelId,
      'channelTitle': channelTitle,
      'watchedAt': watchedAt.toIso8601String(),
      'lastKnownPositionSeconds': lastKnownPositionSeconds,
      'durationSeconds': durationSeconds,
    };
  }
}
