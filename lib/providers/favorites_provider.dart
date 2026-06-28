import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/movie.dart';
import '../models/tv_show.dart';

class FavoritesProvider extends ChangeNotifier {
  static const String _favMoviesKey = 'fav_movies';
  static const String _favTvShowsKey = 'fav_tv_shows';

  List<Movie> _favoriteMovies = [];
  List<TvShow> _favoriteTvShows = [];

  List<Movie> get favoriteMovies => _favoriteMovies;
  List<TvShow> get favoriteTvShows => _favoriteTvShows;

  FavoritesProvider() {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final movieStrings = prefs.getStringList(_favMoviesKey) ?? [];
      _favoriteMovies = movieStrings
          .map((s) => Movie.fromJson(json.decode(s)))
          .toList();

      final tvStrings = prefs.getStringList(_favTvShowsKey) ?? [];
      _favoriteTvShows = tvStrings
          .map((s) => TvShow.fromJson(json.decode(s)))
          .toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading favorites: $e');
    }
  }

  bool isMovieFavorite(int id) {
    return _favoriteMovies.any((m) => m.id == id);
  }

  bool isTvShowFavorite(int id) {
    return _favoriteTvShows.any((s) => s.id == id);
  }

  Future<void> toggleMovieFavorite(Movie movie) async {
    final index = _favoriteMovies.indexWhere((m) => m.id == movie.id);
    if (index >= 0) {
      _favoriteMovies.removeAt(index);
    } else {
      _favoriteMovies.add(movie);
    }
    notifyListeners();
    await _saveMovies();
  }

  Future<void> toggleTvShowFavorite(TvShow tvShow) async {
    final index = _favoriteTvShows.indexWhere((s) => s.id == tvShow.id);
    if (index >= 0) {
      _favoriteTvShows.removeAt(index);
    } else {
      _favoriteTvShows.add(tvShow);
    }
    notifyListeners();
    await _saveTvShows();
  }

  Future<void> _saveMovies() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final movieStrings = _favoriteMovies.map((m) => json.encode(m.toJson())).toList();
      await prefs.setStringList(_favMoviesKey, movieStrings);
    } catch (e) {
      debugPrint('Error saving movie favorites: $e');
    }
  }

  Future<void> _saveTvShows() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tvStrings = _favoriteTvShows.map((s) => json.encode(s.toJson())).toList();
      await prefs.setStringList(_favTvShowsKey, tvStrings);
    } catch (e) {
      debugPrint('Error saving tv show favorites: $e');
    }
  }
}
