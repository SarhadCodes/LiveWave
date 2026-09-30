class WaveSavedVideo {
  final String videoId;
  final String title;
  final String thumbnailUrl;
  final String channelId;
  final String channelTitle;
  final DateTime savedAt;
  final bool watchLater;

  const WaveSavedVideo({
    required this.videoId,
    required this.title,
    required this.thumbnailUrl,
    required this.channelId,
    required this.channelTitle,
    required this.savedAt,
    this.watchLater = false,
  });

  factory WaveSavedVideo.fromJson(Map<String, dynamic> json) {
    return WaveSavedVideo(
      videoId: json['videoId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      channelId: json['channelId'] as String? ?? '',
      channelTitle: json['channelTitle'] as String? ?? '',
      savedAt: DateTime.tryParse(json['savedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      watchLater: json['watchLater'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'videoId': videoId,
      'title': title,
      'thumbnailUrl': thumbnailUrl,
      'channelId': channelId,
      'channelTitle': channelTitle,
      'savedAt': savedAt.toIso8601String(),
      'watchLater': watchLater,
    };
  }
}
