import 'package:flutter/foundation.dart';
import '../models/movie.dart';
import '../services/telegram_ingest_service.dart';
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

  /// Trial preview is disabled; full movie catalog is always shown.
  bool _previewLimited = false;

  bool get previewLimited => _previewLimited;

  void setPreviewLimited(bool limited) {
    if (!_previewLimited) return;
    _previewLimited = false;
    notifyListeners();
  }

  void _applyPreviewCap() {
    // Trial preview is disabled so every movie category stays visible.
  }

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
      await _mergeTelegramMovies();
      _applyPreviewCap();
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

    // Phase 1: hero row first so the screen can paint within a few seconds.
    final trendingFuture = _tmdbService.getTrendingMovies();
    final restFuture = Future.wait([
      _tmdbService.getPopularMovies(),
      _tmdbService.getTopRatedMovies(),
      _tmdbService.getNowPlayingMovies(),
      _tmdbService.getAnimeMovies(),
    ]);
    final kurdishFuture = _tmdbService.getListItems('8649243').catchError((e) {
      debugPrint('[MoviesProvider] Error loading Kurdish list: $e');
      return {'movies': <Movie>[], 'tvShows': <dynamic>[]};
    });

    _trendingMovies = await trendingFuture;
    _applyPreviewCap();
    notifyListeners();

    final rest = await restFuture;
    _popularMovies = rest[0];
    _topRatedMovies = rest[1];
    _nowPlayingMovies = rest[2];
    _animeMovies = rest[3];

    try {
      final listData = await kurdishFuture;
      _kurdishMovies = listData['movies'] as List<Movie>;
    } catch (e) {
      debugPrint('[MoviesProvider] Error loading Kurdish list: $e');
      _kurdishMovies = [];
    }
    _applyPreviewCap();
  }

  Future<void> _mergeTelegramMovies() async {
    final telegram = await TelegramIngestService.fetchPublished();
    if (telegram.isEmpty) return;
    if (_contentSource == SettingsProvider.contentSourceXtream) {
      _moviesByCategory.putIfAbsent('WAVE', () => []);
      _moviesByCategory['WAVE'] = [...telegram, ..._moviesByCategory['WAVE']!];
      if (!_categories.contains('WAVE')) _categories.insert(0, 'WAVE');
    } else {
      _kurdishMovies = [...telegram, ..._kurdishMovies];
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
