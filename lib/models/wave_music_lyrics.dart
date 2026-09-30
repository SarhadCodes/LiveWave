class WaveMusicLyricLine {
  final Duration at;
  final String text;
  const WaveMusicLyricLine({required this.at, required this.text});
}

class WaveMusicLyrics {
  final String trackId;
  final String? plain;
  final List<WaveMusicLyricLine> synced;

  const WaveMusicLyrics({
    required this.trackId,
    this.plain,
    this.synced = const [],
  });

  bool get isEmpty => (plain == null || plain!.trim().isEmpty) && synced.isEmpty;
  bool get isSynced => synced.isNotEmpty;
}
