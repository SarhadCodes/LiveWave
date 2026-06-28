import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/movie.dart';
import '../models/tv_show.dart';

class TmdbService {
  // TODO: Replace with your actual TMDB API key
  static const String _apiKey = 'ebdc5880060530e71d89c0dab80a2d84';
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static const String _imageBaseUrl = 'https://image.tmdb.org/t/p';

  /// Get full image URL from TMDB path or pass through absolute URLs (Xtream).
  static String getImageUrl(String? path, {String size = 'w500'}) {
    if (path == null || path.isEmpty) {
      return '';
    }
    final trimmed = path.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return _validUrl(trimmed);
    }
    if (trimmed.startsWith('//')) {
      return _validUrl('https:$trimmed');
    }
    // TMDB paths always start with /
    if (!trimmed.startsWith('/')) {
      return '';
    }
    return _validUrl('$_imageBaseUrl/$size$trimmed');
  }

  static String _validUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.hasScheme && uri.host.isNotEmpty) return url;
    } catch (_) {}
    return '';
  }

  /// Get backdrop image URL (larger size)
  static String getBackdropUrl(String? path) {
    return getImageUrl(path, size: 'w1280');
  }

  /// Get poster image URL
  static String getPosterUrl(String? path) {
    return getImageUrl(path, size: 'w500');
  }

  // ============ MOVIE METHODS ============

  /// Get trending movies (weekly)
  Future<List<Movie>> getTrendingMovies({int page = 1}) async {
    final url = '$_baseUrl/trending/movie/week?api_key=$_apiKey&page=$page';
    return _fetchMovies(url);
  }

  /// Get popular movies
  Future<List<Movie>> getPopularMovies({int page = 1}) async {
    final url = '$_baseUrl/movie/popular?api_key=$_apiKey&page=$page';
    return _fetchMovies(url);
  }

  /// Get top rated movies
  Future<List<Movie>> getTopRatedMovies({int page = 1}) async {
    final url = '$_baseUrl/movie/top_rated?api_key=$_apiKey&page=$page';
    return _fetchMovies(url);
  }

  /// Get now playing movies
  Future<List<Movie>> getNowPlayingMovies({int page = 1}) async {
    final url = '$_baseUrl/movie/now_playing?api_key=$_apiKey&page=$page';
    return _fetchMovies(url);
  }

  /// Get upcoming movies
  Future<List<Movie>> getUpcomingMovies({int page = 1}) async {
    final url = '$_baseUrl/movie/upcoming?api_key=$_apiKey&page=$page';
    return _fetchMovies(url);
  }

  /// Search movies
  Future<List<Movie>> searchMovies(String query, {int page = 1}) async {
    final encodedQuery = Uri.encodeComponent(query);
    final url = '$_baseUrl/search/movie?api_key=$_apiKey&query=$encodedQuery&page=$page';
    return _fetchMovies(url);
  }

  /// Get anime movies
  Future<List<Movie>> getAnimeMovies({int page = 1}) async {
    final url = '$_baseUrl/discover/movie?api_key=$_apiKey&with_genres=16&with_original_language=ja&page=$page';
    return _fetchMovies(url);
  }

  /// Get movie videos (trailers)
  Future<List<Map<String, dynamic>>> getMovieVideos(int movieId) async {
    final url = '$_baseUrl/movie/$movieId/videos?api_key=$_apiKey';
    return _fetchVideos(url);
  }

  // ============ TV SHOW METHODS ============

  /// Get trending TV shows (weekly)
  Future<List<TvShow>> getTrendingTvShows({int page = 1}) async {
    final url = '$_baseUrl/trending/tv/week?api_key=$_apiKey&page=$page';
    return _fetchTvShows(url);
  }

  /// Get popular TV shows
  Future<List<TvShow>> getPopularTvShows({int page = 1}) async {
    final url = '$_baseUrl/tv/popular?api_key=$_apiKey&page=$page';
    return _fetchTvShows(url);
  }

  /// Get top rated TV shows
  Future<List<TvShow>> getTopRatedTvShows({int page = 1}) async {
    final url = '$_baseUrl/tv/top_rated?api_key=$_apiKey&page=$page';
    return _fetchTvShows(url);
  }

  /// Get on the air TV shows
  Future<List<TvShow>> getOnTheAirTvShows({int page = 1}) async {
    final url = '$_baseUrl/tv/on_the_air?api_key=$_apiKey&page=$page';
    return _fetchTvShows(url);
  }

  /// Search TV shows
  Future<List<TvShow>> searchTvShows(String query, {int page = 1}) async {
    final encodedQuery = Uri.encodeComponent(query);
    final url = '$_baseUrl/search/tv?api_key=$_apiKey&query=$encodedQuery&page=$page';
    return _fetchTvShows(url);
  }

  /// Get anime TV shows
  Future<List<TvShow>> getAnimeTvShows({int page = 1}) async {
    final url = '$_baseUrl/discover/tv?api_key=$_apiKey&with_genres=16&with_original_language=ja&page=$page';
    return _fetchTvShows(url);
  }

  /// Get TV show videos (trailers)
  Future<List<Map<String, dynamic>>> getTvShowVideos(int tvShowId) async {
    final url = '$_baseUrl/tv/$tvShowId/videos?api_key=$_apiKey';
    return _fetchVideos(url);
  }

  /// Get TV show full details (seasons, episodes counts, etc.)
  Future<Map<String, dynamic>> getTvShowDetails(int tvShowId) async {
    try {
      final url = '$_baseUrl/tv/$tvShowId?api_key=$_apiKey';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  /// Get TV show season details (episodes)
  Future<Map<String, dynamic>> getTvSeasonDetails(int tvShowId, int seasonNumber) async {
    try {
      final url = '$_baseUrl/tv/$tvShowId/season/$seasonNumber?api_key=$_apiKey';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  // ============ LIST METHODS ============

  /// Get items from a custom TMDB list (supports pagination)
  Future<Map<String, List<dynamic>>> getListItems(String listId) async {
    final List<Movie> movies = [];
    final List<TvShow> tvShows = [];
    int currentPage = 1;
    int totalPages = 1;

    try {
      do {
        final url = '$_baseUrl/list/$listId?api_key=$_apiKey&page=$currentPage';
        final response = await http.get(Uri.parse(url));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final items = data['items'] as List<dynamic>;
          totalPages = data['total_pages'] ?? 1;
          
          debugPrint('[TmdbService] List $listId Page $currentPage/$totalPages contains ${items.length} items');
          
          for (final item in items) {
            try {
              final mediaType = item['media_type']?.toString().toLowerCase();
              final title = item['title']?.toString();
              final name = item['name']?.toString();
              
              // More robust detection: 
              // V3 lists often return movies in a way that can be ambiguous.
              // If we have a 'title', it's almost certainly a movie.
              // If it only has 'name', it's likely a TV show (unless it's a weird V3 response).
              if (mediaType == 'movie' || title != null) {
                movies.add(Movie.fromJson(item));
              } else if (mediaType == 'tv' || name != null) {
                tvShows.add(TvShow.fromJson(item));
              }
            } catch (e) {
              debugPrint('[TmdbService] Error parsing list item: $e');
            }
          }
          currentPage++;
        } else {
          break; // Stop if error
        }
      } while (currentPage <= totalPages);

      debugPrint('[TmdbService] Final Filtered: ${movies.length} movies, ${tvShows.length} tvShows');
      
      return {
        'movies': movies,
        'tvShows': tvShows,
      };
    } catch (e) {
      debugPrint('[TmdbService] Global list fetch error: $e');
      return {'movies': [], 'tvShows': []};
    }
  }

  // ============ PRIVATE HELPERS ============

  Future<List<Movie>> _fetchMovies(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>;
        return results.map((json) => Movie.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load movies: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch movies: $e');
    }
  }

  Future<List<TvShow>> _fetchTvShows(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>;
        return results.map((json) => TvShow.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load TV shows: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch TV shows: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchVideos(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>;
        return results
            .where((v) => v['site'] == 'YouTube' && v['type'] == 'Trailer')
            .map((v) => {
                  'key': v['key'] as String,
                  'name': v['name'] as String,
                  'type': v['type'] as String,
                })
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
