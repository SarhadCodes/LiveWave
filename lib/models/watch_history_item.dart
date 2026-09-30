class WatchHistoryItem {
  final String key;
  final int contentId;
  final bool isMovie;
  final String title;
  final String? seriesTitle;
  final String posterPath;
  final String backdropPath;
  final int? tmdbId;
  final int? xtreamSeriesId;
  final String? streamUrl;
  final int? season;
  final int? episode;
  final String? episodeTitle;
  final int positionMs;
  final int durationMs;
  final int lastWatchedMs;
  final int? releaseYear;

  const WatchHistoryItem({
    required this.key,
    required this.contentId,
    required this.isMovie,
    required this.title,
    this.seriesTitle,
    this.posterPath = '',
    this.backdropPath = '',
    this.tmdbId,
    this.xtreamSeriesId,
    this.streamUrl,
    this.season,
    this.episode,
    this.episodeTitle,
    required this.positionMs,
    required this.durationMs,
    required this.lastWatchedMs,
    this.releaseYear,
  });

  double get progress {
    if (durationMs <= 0) return 0;
    return (positionMs / durationMs).clamp(0.0, 1.0);
  }

  int get remainingMs {
    if (durationMs <= 0) return 0;
    final left = durationMs - positionMs;
    return left < 0 ? 0 : left;
  }

  String get episodeLabel {
    if (isMovie || season == null || episode == null) return '';
    return 'S$season:E$episode';
  }

  factory WatchHistoryItem.fromJson(Map<String, dynamic> json) {
    return WatchHistoryItem(
      key: json['key'] as String? ?? '',
      contentId: json['contentId'] as int? ?? 0,
      isMovie: json['isMovie'] as bool? ?? true,
      title: json['title'] as String? ?? '',
      seriesTitle: json['seriesTitle'] as String?,
      posterPath: json['posterPath'] as String? ?? '',
      backdropPath: json['backdropPath'] as String? ?? '',
      tmdbId: json['tmdbId'] as int?,
      xtreamSeriesId: json['xtreamSeriesId'] as int?,
      streamUrl: json['streamUrl'] as String?,
      season: json['season'] as int?,
      episode: json['episode'] as int?,
      episodeTitle: json['episodeTitle'] as String?,
      positionMs: json['positionMs'] as int? ?? 0,
      durationMs: json['durationMs'] as int? ?? 0,
      lastWatchedMs: json['lastWatchedMs'] as int? ?? 0,
      releaseYear: json['releaseYear'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'contentId': contentId,
      'isMovie': isMovie,
      'title': title,
      'seriesTitle': seriesTitle,
      'posterPath': posterPath,
      'backdropPath': backdropPath,
      'tmdbId': tmdbId,
      'xtreamSeriesId': xtreamSeriesId,
      'streamUrl': streamUrl,
      'season': season,
      'episode': episode,
      'episodeTitle': episodeTitle,
      'positionMs': positionMs,
      'durationMs': durationMs,
      'lastWatchedMs': lastWatchedMs,
      'releaseYear': releaseYear,
    };
  }
}
