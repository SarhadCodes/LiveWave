class TvShow {
  final int id;
  final String name;
  final String overview;
  final String posterPath;
  final String backdropPath;
  final String firstAirDate;
  final double voteAverage;
  final int voteCount;
  final List<int> genreIds;
  final double popularity;
  /// Xtream series id when loaded from IPTV catalog.
  final int? xtreamSeriesId;
  /// Xtream / M3U category name.
  final String? categoryName;

  TvShow({
    required this.id,
    required this.name,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.firstAirDate,
    required this.voteAverage,
    required this.voteCount,
    required this.genreIds,
    required this.popularity,
    this.xtreamSeriesId,
    this.categoryName,
  });

  bool get isXtream => xtreamSeriesId != null;

  factory TvShow.fromXtream({
    required int seriesId,
    required String name,
    required String overview,
    required String posterPath,
    required String backdropPath,
    required String firstAirDate,
    required double rating,
    required String categoryName,
    required int order,
  }) {
    return TvShow(
      id: -seriesId,
      name: name,
      overview: overview.isNotEmpty ? overview : categoryName,
      posterPath: posterPath,
      backdropPath: backdropPath,
      firstAirDate: firstAirDate,
      voteAverage: rating,
      voteCount: 0,
      genreIds: const [],
      popularity: (1000 - order).toDouble(),
      xtreamSeriesId: seriesId,
      categoryName: categoryName,
    );
  }

  factory TvShow.fromJson(Map<String, dynamic> json) {
    return TvShow(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      overview: json['overview'] ?? '',
      posterPath: json['poster_path'] ?? '',
      backdropPath: json['backdrop_path'] ?? '',
      firstAirDate: json['first_air_date'] ?? '',
      voteAverage: (json['vote_average'] ?? 0).toDouble(),
      voteCount: json['vote_count'] ?? 0,
      genreIds: List<int>.from(json['genre_ids'] ?? []),
      popularity: (json['popularity'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'overview': overview,
      'poster_path': posterPath,
      'backdrop_path': backdropPath,
      'first_air_date': firstAirDate,
      'vote_average': voteAverage,
      'vote_count': voteCount,
      'genre_ids': genreIds,
      'popularity': popularity,
    };
  }

  String get year {
    if (firstAirDate.length >= 4) {
      return firstAirDate.substring(0, 4);
    }
    return '';
  }

  String get ratingFormatted => voteAverage.toStringAsFixed(1);

  static const Map<int, String> genreMap = {
    10759: 'Action & Adventure',
    16: 'Animation',
    35: 'Comedy',
    80: 'Crime',
    99: 'Documentary',
    18: 'Drama',
    10751: 'Family',
    10762: 'Kids',
    9648: 'Mystery',
    10763: 'News',
    10764: 'Reality',
    10765: 'Sci-Fi & Fantasy',
    10766: 'Soap',
    10767: 'Talk',
    10768: 'War & Politics',
    37: 'Western',
  };

  List<String> get genreNames {
    return genreIds
        .map((id) => genreMap[id])
        .where((name) => name != null)
        .cast<String>()
        .toList();
  }
}
