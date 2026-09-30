import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/wave_config.dart';
import '../models/wave_creator.dart';
import '../models/wave_video.dart';
import '../services/wave_youtube_parser.dart';
import '../services/youtube_api_service.dart';
import 'wave_library_provider.dart';

enum WaveLoadStatus { idle, loading, ready, error }

enum WaveSearchTab { videos, creators, live }

class WaveProvider extends ChangeNotifier {
  WaveProvider({
    YouTubeApiService? api,
    required WaveLibraryProvider library,
  })  : _api = api ?? YouTubeApiService(),
        _library = library;

  final YouTubeApiService _api;
  final WaveLibraryProvider _library;

  WaveFeedKind _selectedChip = WaveFeedKind.forYou;
  WaveLoadStatus _homeStatus = WaveLoadStatus.idle;
  WaveApiException? _homeError;
  bool _hasApiKey = false;

  List<WaveVideo> _trending = [];
  List<WaveVideo> _liveNow = [];
  List<WaveVideo> _followedVideos = [];
  List<WaveVideo> _chipVideos = [];
  String? _chipNextPageToken;
  bool _chipLoadingMore = false;

  WaveLoadStatus _searchStatus = WaveLoadStatus.idle;
  WaveSearchTab _searchTab = WaveSearchTab.videos;
  String _searchQuery = '';
  List<WaveVideo> _searchVideos = [];
  List<WaveCreator> _searchCreators = [];
  String? _searchNextPageToken;
  bool _searchLoadingMore = false;
  Timer? _searchDebounce;

  WaveFeedKind get selectedChip => _selectedChip;
  WaveLoadStatus get homeStatus => _homeStatus;
  WaveApiException? get homeError => _homeError;
  bool get hasApiKey => _hasApiKey;
  List<WaveVideo> get trending => List.unmodifiable(_trending);
  List<WaveVideo> get liveNow => List.unmodifiable(_liveNow);
  List<WaveVideo> get followedVideos => List.unmodifiable(_followedVideos);
  List<WaveVideo> get chipVideos => List.unmodifiable(_chipVideos);
  bool get chipHasMore => _chipNextPageToken != null && _chipNextPageToken!.isNotEmpty;
  bool get chipLoadingMore => _chipLoadingMore;
  WaveVideo? get heroVideo =>
      _trending.isNotEmpty ? _trending.first : (_chipVideos.isNotEmpty ? _chipVideos.first : null);

  WaveLoadStatus get searchStatus => _searchStatus;
  WaveSearchTab get searchTab => _searchTab;
  String get searchQuery => _searchQuery;
  List<WaveVideo> get searchVideos => List.unmodifiable(_searchVideos);
  List<WaveCreator> get searchCreators => List.unmodifiable(_searchCreators);
  bool get searchHasMore =>
      _searchNextPageToken != null && _searchNextPageToken!.isNotEmpty;
  bool get searchLoadingMore => _searchLoadingMore;

  Future<void> loadHomeIfNeeded() async {
    if (_homeStatus == WaveLoadStatus.ready || _homeStatus == WaveLoadStatus.loading) {
      return;
    }
    await refreshHome();
  }

  Future<void> refreshHome({bool force = false}) async {
    _homeStatus = WaveLoadStatus.loading;
    _homeError = null;
    notifyListeners();

    try {
      await _library.ensureLoaded();
      _hasApiKey = await WaveConfig.hasApiKey();
      if (!_hasApiKey) {
        _homeStatus = WaveLoadStatus.ready;
        notifyListeners();
        return;
      }

      final trendingPage = await _api.trending(forceRefresh: force);
      _trending = trendingPage.items;

      try {
        final livePage = await _api.categoryFeed(WaveFeedKind.live, forceRefresh: force);
        _liveNow = livePage.items;
      } on WaveApiException {
        _liveNow = const [];
      }

      final followedIds =
          _library.followedCreators.map((item) => item.youtubeChannelId).toList();
      if (followedIds.isNotEmpty) {
        try {
          _followedVideos = await _api.recentFromChannels(followedIds);
        } on WaveApiException {
          _followedVideos = const [];
        }
      } else {
        _followedVideos = const [];
      }

      if (_selectedChip == WaveFeedKind.forYou) {
        _chipVideos = _trending;
        _chipNextPageToken = trendingPage.nextPageToken;
      } else {
        await selectChip(_selectedChip, force: force);
      }

      _homeStatus = WaveLoadStatus.ready;
    } on WaveApiException catch (error) {
      _homeError = error;
      _homeStatus = WaveLoadStatus.error;
    } catch (error) {
      debugPrint('Wave home error: $error');
      _homeError = const WaveApiException(
        WaveApiErrorKind.unknown,
        'Wave couldn\'t load this content.',
      );
      _homeStatus = WaveLoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> selectChip(WaveFeedKind chip, {bool force = false}) async {
    _selectedChip = chip;
    if (chip == WaveFeedKind.forYou) {
      _chipVideos = _trending;
      notifyListeners();
      return;
    }

    _homeStatus = WaveLoadStatus.loading;
    _homeError = null;
    notifyListeners();
    try {
      final page = await _api.categoryFeed(chip, forceRefresh: force);
      _chipVideos = page.items;
      _chipNextPageToken = page.nextPageToken;
      _homeStatus = WaveLoadStatus.ready;
    } on WaveApiException catch (error) {
      _homeError = error;
      _homeStatus = WaveLoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> loadMoreChip() async {
    if (_chipLoadingMore || !chipHasMore || _selectedChip == WaveFeedKind.forYou) {
      return;
    }
    _chipLoadingMore = true;
    notifyListeners();
    try {
      final page = await _api.categoryFeed(
        _selectedChip,
        pageToken: _chipNextPageToken,
      );
      _chipVideos = [..._chipVideos, ...page.items];
      _chipNextPageToken = page.nextPageToken;
    } on WaveApiException {
      // Keep existing items; user can retry by scrolling again.
    } finally {
      _chipLoadingMore = false;
      notifyListeners();
    }
  }

  void setSearchTab(WaveSearchTab tab) {
    if (_searchTab == tab) return;
    _searchTab = tab;
    if (_searchQuery.trim().isNotEmpty) {
      _runSearch(_searchQuery);
    } else {
      notifyListeners();
    }
  }

  void onSearchQueryChanged(String query) {
    _searchQuery = query;
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      _searchVideos = const [];
      _searchCreators = const [];
      _searchStatus = WaveLoadStatus.idle;
      _searchNextPageToken = null;
      notifyListeners();
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      _runSearch(query);
    });
  }

  Future<void> submitSearch(String query) {
    _searchDebounce?.cancel();
    return _runSearch(query);
  }

  Future<void> _runSearch(String query) async {
    final trimmed = query.trim();
    _searchQuery = query;
    if (trimmed.isEmpty) return;
    _searchStatus = WaveLoadStatus.loading;
    notifyListeners();
    try {
      if (_searchTab == WaveSearchTab.creators) {
        final page = await _api.searchCreators(query: trimmed);
        _searchCreators = page.items;
        _searchVideos = const [];
        _searchNextPageToken = page.nextPageToken;
      } else {
        final page = await _api.searchVideos(
          query: trimmed,
          eventType: _searchTab == WaveSearchTab.live ? 'live' : null,
        );
        _searchVideos = page.items;
        _searchCreators = const [];
        _searchNextPageToken = page.nextPageToken;
      }
      _searchStatus = WaveLoadStatus.ready;
    } on WaveApiException catch (error) {
      _homeError = error;
      _searchStatus = WaveLoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> loadMoreSearch() async {
    if (_searchLoadingMore || !searchHasMore || _searchQuery.trim().isEmpty) {
      return;
    }
    _searchLoadingMore = true;
    notifyListeners();
    try {
      if (_searchTab == WaveSearchTab.creators) {
        final page = await _api.searchCreators(
          query: _searchQuery.trim(),
          pageToken: _searchNextPageToken,
        );
        _searchCreators = [..._searchCreators, ...page.items];
        _searchNextPageToken = page.nextPageToken;
      } else {
        final page = await _api.searchVideos(
          query: _searchQuery.trim(),
          eventType: _searchTab == WaveSearchTab.live ? 'live' : null,
          pageToken: _searchNextPageToken,
        );
        _searchVideos = [..._searchVideos, ...page.items];
        _searchNextPageToken = page.nextPageToken;
      }
    } on WaveApiException {
      // Keep current results.
    } finally {
      _searchLoadingMore = false;
      notifyListeners();
    }
  }

  Future<WaveCreator?> loadCreator(String channelId) {
    return _api.channelById(channelId);
  }

  Future<WavePage<WaveVideo>> creatorVideos({
    required WaveCreator creator,
    String? pageToken,
    String order = 'date',
  }) async {
    if (order == 'viewCount') {
      return _api.searchVideos(
        query: '',
        channelId: creator.youtubeChannelId,
        order: 'viewCount',
        pageToken: pageToken,
      );
    }
    final playlistId = creator.uploadsPlaylistId;
    if (playlistId == null || playlistId.isEmpty) {
      return _api.searchVideos(
        query: '',
        channelId: creator.youtubeChannelId,
        order: 'date',
        pageToken: pageToken,
      );
    }
    return _api.channelUploads(
      uploadsPlaylistId: playlistId,
      pageToken: pageToken,
    );
  }

  Future<WavePage<WaveVideo>> creatorLive(WaveCreator creator, {String? pageToken}) {
    return _api.searchVideos(
      query: '',
      channelId: creator.youtubeChannelId,
      eventType: 'live',
      pageToken: pageToken,
    );
  }

  Future<List<WaveVideo>> moreFromCreator(String channelId, {String? excludeVideoId}) async {
    final creator = await _api.channelById(channelId);
    if (creator == null) return const [];
    final page = await creatorVideos(creator: creator);
    return page.items.where((video) => video.videoId != excludeVideoId).take(12).toList();
  }

  Future<List<WaveVideo>> relatedVideos(WaveVideo video) async {
    final query = video.title
        .split(RegExp(r'\s+'))
        .where((part) => part.length > 2)
        .take(6)
        .join(' ');
    if (query.isEmpty) return const [];
    final page = await _api.searchVideos(query: query, maxResults: 12);
    return page.items.where((item) => item.videoId != video.videoId).take(12).toList();
  }

  Future<WaveVideo?> hydrateVideo(WaveVideo video) async {
    final hydrated = await _api.videosByIds([video.videoId]);
    if (hydrated.isEmpty) return video.embeddable ? video : null;
    var result = hydrated.first;
    if (result.channelThumbnailUrl == null && result.channelId.isNotEmpty) {
      final creator = await _api.channelById(result.channelId);
      if (creator != null) {
        result = result.copyWith(channelThumbnailUrl: creator.thumbnailUrl);
      }
    }
    return result.embeddable ? result : null;
  }

  Future<void> saveApiKeyAndReload(String key) async {
    await WaveConfig.saveApiKey(key);
    _api.clearCache();
    _homeStatus = WaveLoadStatus.idle;
    await refreshHome(force: true);
  }

  YouTubeApiService get api => _api;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}
