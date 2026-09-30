import 'package:flutter/foundation.dart';
import '../models/tv_show.dart';
import '../services/tmdb_service.dart';
import '../services/xtream_service.dart';
import 'settings_provider.dart';

enum TvShowsStatus { initial, loading, success, error }

class TvShowsProvider extends ChangeNotifier {
  final TmdbService _tmdbService = TmdbService();
  final XtreamService _xtreamService = XtreamService();

  TvShowsStatus _status = TvShowsStatus.initial;
  String? _errorMessage;
  String _contentSource = SettingsProvider.contentSourceFirestore;

  List<TvShow> _trendingTvShows = [];
  List<TvShow> _popularTvShows = [];
  List<TvShow> _topRatedTvShows = [];
  List<TvShow> _onTheAirTvShows = [];
  List<TvShow> _kurdishTvShows = [];
  List<TvShow> _animeTvShows = [];
  final Map<String, List<TvShow>> _showsByCategory = {};
  List<String> _categories = [];

  /// Trial preview is disabled; full series catalog is always shown.
  bool _previewLimited = false;

  bool get previewLimited => _previewLimited;

  void setPreviewLimited(bool limited) {
    if (!_previewLimited) return;
    _previewLimited = false;
    notifyListeners();
  }

  void _applyPreviewCap() {
    // Trial preview is disabled so every series category stays visible.
  }

  TvShowsStatus get status => _status;
  String? get errorMessage => _errorMessage;

  List<String> get categories => _categories;
  List<TvShow> showsInCategory(String category) =>
      _showsByCategory[category] ?? const [];

  List<TvShow> get trendingTvShows => _trendingTvShows;
  List<TvShow> get popularTvShows => _popularTvShows;
  List<TvShow> get topRatedTvShows => _topRatedTvShows;
  List<TvShow> get onTheAirTvShows => _onTheAirTvShows;
  List<TvShow> get kurdishTvShows => _kurdishTvShows;
  List<TvShow> get animeTvShows => _animeTvShows;

  void setContentSource(String source) {
    _contentSource = source;
  }

  Future<void> fetchAllTvShows({bool force = false}) async {
    if (!force && (_status == TvShowsStatus.loading || _status == TvShowsStatus.success)) {
      return;
    }

    _status = TvShowsStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_contentSource == SettingsProvider.contentSourceXtream) {
        await _fetchFromXtream();
      } else {
        await _fetchFromTmdb();
      }
      _applyPreviewCap();
      _status = TvShowsStatus.success;
    } catch (e) {
      debugPrint('[TvShowsProvider] Error fetching TV shows: $e');
      _status = TvShowsStatus.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<void> _fetchFromXtream() async {
    final shows = await _xtreamService.getSeries();
    _showsByCategory.clear();
    _categories = [];

    for (final show in shows) {
      final category = (show.categoryName?.trim().isNotEmpty == true)
          ? show.categoryName!.trim()
          : 'Series';
      _showsByCategory.putIfAbsent(category, () => []).add(show);
      if (!_categories.contains(category)) {
        _categories.add(category);
      }
    }

    _trendingTvShows = [];
    _popularTvShows = [];
    _topRatedTvShows = [];
    _onTheAirTvShows = [];
    _kurdishTvShows = [];
    _animeTvShows = [];
  }

  Future<void> _fetchFromTmdb() async {
    _showsByCategory.clear();
    _categories = [];

    // Phase 1: hero row first so the screen can paint within a few seconds.
    final trendingFuture = _tmdbService.getTrendingTvShows();
    final restFuture = Future.wait([
      _tmdbService.getPopularTvShows(),
      _tmdbService.getTopRatedTvShows(),
      _tmdbService.getOnTheAirTvShows(),
      _tmdbService.getAnimeTvShows(),
    ]);
    final kurdishFuture = _tmdbService.getListItems('8649243').catchError((e) {
      debugPrint('[TvShowsProvider] Error loading Kurdish list: $e');
      return {'movies': <dynamic>[], 'tvShows': <TvShow>[]};
    });

    _trendingTvShows = await trendingFuture;
    _applyPreviewCap();
    notifyListeners();

    final rest = await restFuture;
    _popularTvShows = rest[0];
    _topRatedTvShows = rest[1];
    _onTheAirTvShows = rest[2];
    _animeTvShows = rest[3];

    try {
      final listData = await kurdishFuture;
      _kurdishTvShows = listData['tvShows'] as List<TvShow>;
    } catch (e) {
      debugPrint('[TvShowsProvider] Error loading Kurdish list: $e');
      _kurdishTvShows = [];
    }
    _applyPreviewCap();
  }

  void reset() {
    _status = TvShowsStatus.initial;
    _trendingTvShows = [];
    _popularTvShows = [];
    _topRatedTvShows = [];
    _onTheAirTvShows = [];
    _kurdishTvShows = [];
    _animeTvShows = [];
    _showsByCategory.clear();
    _categories = [];
    notifyListeners();
  }

  Future<void> retry() async {
    reset();
    await fetchAllTvShows(force: true);
  }
}
