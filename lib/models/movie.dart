class Movie {
  final int id;
  final String title;
  final String overview;
  final String posterPath;
  final String backdropPath;
  final String releaseDate;
  final double voteAverage;
  final int voteCount;
  final List<int> genreIds;
  final double popularity;
  /// Direct play URL when loaded from Xtream Codes VOD or Telegram ingest.
  final String? streamUrl;
  /// Xtream / M3U category name.
  final String? categoryName;

  Movie({
    required this.id,
    required this.title,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.releaseDate,
    required this.voteAverage,
    required this.voteCount,
    required this.genreIds,
    required this.popularity,
    this.streamUrl,
    this.categoryName,
  });

  bool get isXtream => streamUrl != null && streamUrl!.isNotEmpty;

  factory Movie.fromXtream({
    required int streamId,
    required String title,
    required String overview,
    required String posterPath,
    required String backdropPath,
    required String releaseDate,
    required double rating,
    required String streamUrl,
    required String categoryName,
    required int order,
  }) {
    return Movie(
      id: -streamId,
      title: title,
      overview: overview.isNotEmpty ? overview : categoryName,
      posterPath: posterPath,
      backdropPath: backdropPath,
      releaseDate: releaseDate,
      voteAverage: rating,
      voteCount: 0,
      genreIds: const [],
      popularity: (1000 - order).toDouble(),
      streamUrl: streamUrl,
      categoryName: categoryName,
    );
  }

  factory Movie.fromTelegram(Map<String, dynamic> json) {
    final genres = (json['genres'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
    final mappedIds = genres.map(genreIdForName).whereType<int>().toList();
    final poster = (json['posterUrl'] ?? '').toString();
    final year = json['year'];
    return Movie(
      id: json['id'] ?? 0,
      title: (json['title'] ?? json['originalTitle'] ?? 'Untitled').toString(),
      overview: (json['description'] ?? '').toString(),
      posterPath: poster,
      backdropPath: poster,
      releaseDate: year != null ? '$year-01-01' : '',
      voteAverage: (json['rating'] is num) ? (json['rating'] as num).toDouble() : 0,
      voteCount: 0,
      genreIds: mappedIds,
      popularity: 950,
      streamUrl: (json['playUrl'] ?? '').toString(),
      categoryName: 'WAVE',
    );
  }

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      overview: json['overview'] ?? '',
      posterPath: json['poster_path'] ?? '',
      backdropPath: json['backdrop_path'] ?? '',
      releaseDate: json['release_date'] ?? '',
      voteAverage: (json['vote_average'] ?? 0).toDouble(),
      voteCount: json['vote_count'] ?? 0,
      genreIds: List<int>.from(json['genre_ids'] ?? []),
      popularity: (json['popularity'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'overview': overview,
      'poster_path': posterPath,
      'backdrop_path': backdropPath,
      'release_date': releaseDate,
      'vote_average': voteAverage,
      'vote_count': voteCount,
      'genre_ids': genreIds,
      'popularity': popularity,
    };
  }

  String get year {
    if (releaseDate.length >= 4) {
      return releaseDate.substring(0, 4);
    }
    return '';
  }

  String get ratingFormatted => voteAverage.toStringAsFixed(1);

  static const Map<int, String> genreMap = {
    28: 'Action',
    12: 'Adventure',
    16: 'Animation',
    35: 'Comedy',
    80: 'Crime',
    99: 'Documentary',
    18: 'Drama',
    10751: 'Family',
    14: 'Fantasy',
    36: 'History',
    27: 'Horror',
    10402: 'Music',
    9648: 'Mystery',
    10749: 'Romance',
    878: 'Science Fiction',
    10770: 'TV Movie',
    53: 'Thriller',
    10752: 'War',
    37: 'Western',
  };

  List<String> get genreNames {
    return genreIds
        .map((id) => genreMap[id])
        .where((name) => name != null)
        .cast<String>()
        .toList();
  }

  static int? genreIdForName(String name) {
    for (final entry in genreMap.entries) {
      if (entry.value.toLowerCase() == name.toLowerCase()) return entry.key;
    }
    return null;
  }
}
