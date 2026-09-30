class WavePlaybackProgress {
  final String videoId;
  final int positionSeconds;
  final int? durationSeconds;
  final DateTime updatedAt;

  const WavePlaybackProgress({
    required this.videoId,
    required this.positionSeconds,
    this.durationSeconds,
    required this.updatedAt,
  });

  factory WavePlaybackProgress.fromJson(Map<String, dynamic> json) {
    return WavePlaybackProgress(
      videoId: json['videoId'] as String? ?? '',
      positionSeconds: (json['positionSeconds'] as num?)?.toInt() ?? 0,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'videoId': videoId,
      'positionSeconds': positionSeconds,
      'durationSeconds': durationSeconds,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
