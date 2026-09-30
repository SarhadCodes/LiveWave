enum WaveLiveState { none, upcoming, live, ended }

class WaveVideo {
  final String videoId;
  final String title;
  final String channelId;
  final String channelTitle;
  final String thumbnailUrl;
  final String? channelThumbnailUrl;
  final DateTime? publishedAt;
  final Duration? duration;
  final int? viewCount;
  final int? concurrentViewers;
  final WaveLiveState liveState;
  final bool embeddable;
  final String? description;

  const WaveVideo({
    required this.videoId,
    required this.title,
    required this.channelId,
    required this.channelTitle,
    required this.thumbnailUrl,
    this.channelThumbnailUrl,
    this.publishedAt,
    this.duration,
    this.viewCount,
    this.concurrentViewers,
    this.liveState = WaveLiveState.none,
    this.embeddable = true,
    this.description,
  });

  bool get isLive => liveState == WaveLiveState.live;

  String get watchUrl => 'https://www.youtube.com/watch?v=$videoId';

  WaveVideo copyWith({
    String? channelThumbnailUrl,
    String? description,
    bool? embeddable,
  }) {
    return WaveVideo(
      videoId: videoId,
      title: title,
      channelId: channelId,
      channelTitle: channelTitle,
      thumbnailUrl: thumbnailUrl,
      channelThumbnailUrl: channelThumbnailUrl ?? this.channelThumbnailUrl,
      publishedAt: publishedAt,
      duration: duration,
      viewCount: viewCount,
      concurrentViewers: concurrentViewers,
      liveState: liveState,
      embeddable: embeddable ?? this.embeddable,
      description: description ?? this.description,
    );
  }

  factory WaveVideo.fromJson(Map<String, dynamic> json) {
    return WaveVideo(
      videoId: json['videoId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      channelId: json['channelId'] as String? ?? '',
      channelTitle: json['channelTitle'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      channelThumbnailUrl: json['channelThumbnailUrl'] as String?,
      publishedAt: _parseDate(json['publishedAt']),
      duration: json['durationSeconds'] is num
          ? Duration(seconds: (json['durationSeconds'] as num).toInt())
          : null,
      viewCount: (json['viewCount'] as num?)?.toInt(),
      concurrentViewers: (json['concurrentViewers'] as num?)?.toInt(),
      liveState: WaveLiveState.values.firstWhere(
        (value) => value.name == json['liveState'],
        orElse: () => WaveLiveState.none,
      ),
      embeddable: json['embeddable'] as bool? ?? true,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'videoId': videoId,
      'title': title,
      'channelId': channelId,
      'channelTitle': channelTitle,
      'thumbnailUrl': thumbnailUrl,
      'channelThumbnailUrl': channelThumbnailUrl,
      'publishedAt': publishedAt?.toIso8601String(),
      'durationSeconds': duration?.inSeconds,
      'viewCount': viewCount,
      'concurrentViewers': concurrentViewers,
      'liveState': liveState.name,
      'embeddable': embeddable,
      'description': description,
    };
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

class WavePage<T> {
  final List<T> items;
  final String? nextPageToken;

  const WavePage({required this.items, this.nextPageToken});

  bool get hasMore => nextPageToken != null && nextPageToken!.isNotEmpty;
}
