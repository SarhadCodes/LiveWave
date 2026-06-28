import 'package:flutter/foundation.dart';
import '../models/movie.dart';
import '../services/tmdb_service.dart';
import '../services/xtream_service.dart';
import 'settings_provider.dart';

enum MoviesStatus { initial, loading, success, error }

class MoviesProvider extends ChangeNotifier {
  final TmdbService _tmdbService = TmdbService();
  final XtreamService _xtreamService = XtreamService();

  MoviesStatus _status = MoviesStatus.initial;
  String? _errorMessage;
  String _contentSource = SettingsProvider.contentSourceFirestore;

  List<Movie> _trendingMovies = [];
  List<Movie> _popularMovies = [];
  List<Movie> _topRatedMovies = [];
  List<Movie> _nowPlayingMovies = [];
  List<Movie> _kurdishMovies = [];
  List<Movie> _animeMovies = [];
  final Map<String, List<Movie>> _moviesByCategory = {};
  List<String> _categories = [];

  MoviesStatus get status => _status;
  String? get errorMessage => _errorMessage;

  List<String> get categories => _categories;
  List<Movie> moviesInCategory(String category) =>
      _moviesByCategory[category] ?? const [];

  List<Movie> get trendingMovies => _trendingMovies;
  List<Movie> get popularMovies => _popularMovies;
  List<Movie> get topRatedMovies => _topRatedMovies;
  List<Movie> get nowPlayingMovies => _nowPlayingMovies;
  List<Movie> get kurdishMovies => _kurdishMovies;
  List<Movie> get animeMovies => _animeMovies;

  void setContentSource(String source) {
    _contentSource = source;
  }

  Future<void> fetchAllMovies({bool force = false}) async {
    if (!force && (_status == MoviesStatus.loading || _status == MoviesStatus.success)) {
      return;
    }

    _status = MoviesStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_contentSource == SettingsProvider.contentSourceXtream) {
        await _fetchFromXtream();
      } else {
        await _fetchFromTmdb();
      }
      _status = MoviesStatus.success;
    } catch (e) {
      debugPrint('[MoviesProvider] Error fetching movies: $e');
      _status = MoviesStatus.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<void> _fetchFromXtream() async {
    final movies = await _xtreamService.getVodMovies();
    _moviesByCategory.clear();
    _categories = [];

    for (final movie in movies) {
      final category = (movie.categoryName?.trim().isNotEmpty == true)
          ? movie.categoryName!.trim()
          : 'Movies';
      _moviesByCategory.putIfAbsent(category, () => []).add(movie);
      if (!_categories.contains(category)) {
        _categories.add(category);
      }
    }

    _trendingMovies = [];
    _popularMovies = [];
    _topRatedMovies = [];
    _nowPlayingMovies = [];
    _kurdishMovies = [];
    _animeMovies = [];
  }

  Future<void> _fetchFromTmdb() async {
    _moviesByCategory.clear();
    _categories = [];
    final futures = await Future.wait([
      _tmdbService.getTrendingMovies(),
      _tmdbService.getPopularMovies(),
      _tmdbService.getTopRatedMovies(),
      _tmdbService.getNowPlayingMovies(),
      _tmdbService.getAnimeMovies(),
    ]);

    _trendingMovies = futures[0] as List<Movie>;
    _popularMovies = futures[1] as List<Movie>;
    _topRatedMovies = futures[2] as List<Movie>;
    _nowPlayingMovies = futures[3] as List<Movie>;
    _animeMovies = futures[4] as List<Movie>;

    try {
      final listData = await _tmdbService.getListItems('8649243');
      _kurdishMovies = listData['movies'] as List<Movie>;
    } catch (e) {
      debugPrint('[MoviesProvider] Error loading Kurdish list: $e');
      _kurdishMovies = [];
    }
  }

  void reset() {
    _status = MoviesStatus.initial;
    _trendingMovies = [];
    _popularMovies = [];
    _topRatedMovies = [];
    _nowPlayingMovies = [];
    _kurdishMovies = [];
    _animeMovies = [];
    _moviesByCategory.clear();
    _categories = [];
    notifyListeners();
  }

  Future<void> retry() async {
    reset();
    await fetchAllMovies(force: true);
  }
}
