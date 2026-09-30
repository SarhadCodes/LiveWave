import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../models/channel.dart';
import '../models/movie.dart';
import '../models/tv_show.dart';
import '../providers/channels_provider.dart';
import '../services/tmdb_service.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/channel_logo.dart';
import '../widgets/media_card.dart';
import '../widgets/media_row.dart';
import '../widgets/loading_indicator.dart';
import '../services/player_launcher.dart';
import 'media_grid_screen.dart';
import 'movie_detail_screen.dart';
import 'tv_show_detail_screen.dart';
import '../providers/settings_provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/movies_provider.dart';
import '../providers/tv_shows_provider.dart';
import '../utils/category_row_focus_helper.dart';
import '../utils/tv_row_focus.dart';
import '../widgets/tv_navigation_scope.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => SearchScreenState();
}

class SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final CategoryRowFocusHelper _focusHelper = CategoryRowFocusHelper();
  String _searchQuery = '';

  List<Channel> _searchChannelResults = [];
  List<Movie> _searchMovieResults = [];
  List<TvShow> _searchTvShowResults = [];

  bool _hasSearched = false;
  bool _isLoadingMovies = false;
  bool _isLoadingTvShows = false;

  final Map<String, FocusNode> _focusNodes = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  /// TV: move focus from sidebar into the search field.
  void focusSearchBar() {
    if (!mounted) return;
    _searchFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _focusHelper.dispose();
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  FocusNode _getFocusNode(String uniqueId) {
    return _focusNodes.putIfAbsent(uniqueId, FocusNode.new);
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      _focusHelper.reset();
      if (_searchQuery.isNotEmpty) {
        _performSearch();
      } else {
        _searchChannelResults = [];
        _searchMovieResults = [];
        _searchTvShowResults = [];
        _hasSearched = false;
        _isLoadingMovies = false;
        _isLoadingTvShows = false;
      }
    });
  }

  void _performSearch() {
    final query = _searchQuery.toLowerCase();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final provider = Provider.of<ChannelsProvider>(context, listen: false);
    final moviesProv = Provider.of<MoviesProvider>(context, listen: false);
    final tvProv = Provider.of<TvShowsProvider>(context, listen: false);
    final previewLimited = provider.previewLimited;
    final isXtream = settings.isXtreamSource;

    setState(() {
      _searchChannelResults = provider.channels.where((channel) {
        return channel.name.toLowerCase().contains(query) ||
            channel.category.toLowerCase().contains(query);
      }).toList();
      _hasSearched = true;
    });

    // Playlist mode: search only loaded Xtream catalog — never TMDB / Firestore.
    if (isXtream) {
      setState(() {
        _isLoadingMovies =
            moviesProv.status == MoviesStatus.loading || moviesProv.status == MoviesStatus.initial;
        _isLoadingTvShows =
            tvProv.status == TvShowsStatus.loading || tvProv.status == TvShowsStatus.initial;
        _searchMovieResults = [];
        _searchTvShowResults = [];
      });
      _searchXtreamCatalog(query, moviesProv, tvProv);
      return;
    }

    setState(() {
      _isLoadingMovies = !previewLimited;
      _isLoadingTvShows = !previewLimited;
    });

    if (previewLimited) {
      _searchMovieResults = [];
      _searchTvShowResults = [];
      moviesProv.fetchAllMovies();
      tvProv.fetchAllTvShows();
      return;
    }

    final tmdbService = TmdbService();

    tmdbService.searchMovies(_searchQuery).then((movies) {
      if (mounted) {
        setState(() {
          _searchMovieResults = movies;
          _isLoadingMovies = false;
        });
      }
    }).catchError((_) {
      if (mounted) setState(() => _isLoadingMovies = false);
    });

    tmdbService.searchTvShows(_searchQuery).then((tvShows) {
      if (mounted) {
        setState(() {
          _searchTvShowResults = tvShows;
          _isLoadingTvShows = false;
        });
      }
    }).catchError((_) {
      if (mounted) setState(() => _isLoadingTvShows = false);
    });
  }

  Future<void> _searchXtreamCatalog(
    String query,
    MoviesProvider moviesProv,
    TvShowsProvider tvProv,
  ) async {
    if (moviesProv.status == MoviesStatus.initial) {
      await moviesProv.fetchAllMovies();
    }
    if (tvProv.status == TvShowsStatus.initial) {
      await tvProv.fetchAllTvShows();
    }

    if (!mounted) return;
    setState(() {
      _searchMovieResults = _filterXtreamMovies(moviesProv, query);
      _searchTvShowResults = _filterXtreamTvShows(tvProv, query);
      _isLoadingMovies = false;
      _isLoadingTvShows = false;
    });
  }

  List<Movie> _filterXtreamMovies(MoviesProvider prov, String query) {
    final all = <Movie>[];
    for (final category in prov.categories) {
      all.addAll(prov.moviesInCategory(category));
    }
    return all
        .where((movie) =>
            movie.title.toLowerCase().contains(query) ||
            (movie.categoryName?.toLowerCase().contains(query) ?? false))
        .toList();
  }

  List<TvShow> _filterXtreamTvShows(TvShowsProvider prov, String query) {
    final all = <TvShow>[];
    for (final category in prov.categories) {
      all.addAll(prov.showsInCategory(category));
    }
    return all
        .where((show) =>
            show.name.toLowerCase().contains(query) ||
            (show.categoryName?.toLowerCase().contains(query) ?? false))
        .toList();
  }

  void _focusFirstSearchResult({
    required List<Channel> channels,
    required List<Movie> movies,
    required List<TvShow> tvShows,
  }) {
    if (_searchQuery.isEmpty || !_hasSearched) return;

    var rowIndex = 0;

    if (channels.isNotEmpty) {
      final channel = channels.first;
      _getFocusNode('search_live_${channel.id}').requestFocus();
      _focusHelper.onItemFocused(
        rowIndex: rowIndex,
        itemIndex: 0,
        rowId: 'search_live',
      );
      return;
    }

    if (movies.isNotEmpty) {
      final movie = movies.first;
      _getFocusNode('search_movies_${movie.id}').requestFocus();
      _focusHelper.onItemFocused(
        rowIndex: rowIndex,
        itemIndex: 0,
        rowId: 'search_movies',
      );
      return;
    }

    if (tvShows.isNotEmpty) {
      final show = tvShows.first;
      _getFocusNode('search_tv_${show.id}').requestFocus();
      _focusHelper.onItemFocused(
        rowIndex: rowIndex,
        itemIndex: 0,
        rowId: 'search_tv',
      );
    }
  }

  List<Movie> _mergeMovies(List<Movie> kurdish, List<Movie> remote) {
    final seen = <int>{};
    final merged = <Movie>[];
    for (final movie in kurdish) {
      if (seen.add(movie.id)) merged.add(movie);
    }
    for (final movie in remote) {
      if (seen.add(movie.id)) merged.add(movie);
    }
    return merged;
  }

  List<TvShow> _mergeTvShows(List<TvShow> kurdish, List<TvShow> remote) {
    final seen = <int>{};
    final merged = <TvShow>[];
    for (final show in kurdish) {
      if (seen.add(show.id)) merged.add(show);
    }
    for (final show in remote) {
      if (seen.add(show.id)) merged.add(show);
    }
    return merged;
  }

  void _openPlayer(Channel channel, List<Channel> channels, int index) {
    PlayerLauncher.launch(
      context: context,
      channel: channel,
      allChannels: channels,
      initialChannelIndex: index,
    );
  }

  void _openMovieDetail(Movie movie) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MovieDetailScreen(movie: movie)),
    );
  }

  void _openTvShowDetail(TvShow tvShow) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TvShowDetailScreen(tvShow: tvShow)),
    );
  }

  void _openMovieGrid(String title, List<Movie> items, bool isMobile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MediaGridScreen(
          title: title,
          items: items,
          isMobile: isMobile,
        ),
      ),
    );
  }

  void _openTvGrid(String title, List<TvShow> items, bool isMobile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MediaGridScreen(
          title: title,
          items: items,
          isMobile: isMobile,
        ),
      ),
    );
  }

  void _openChannelGrid(String title, List<Channel> channels, bool isMobile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _SearchChannelGridScreen(
          title: title,
          channels: channels,
          isMobile: isMobile,
        ),
      ),
    );
  }

  Widget _wrapTvRow(int rowIndex, bool enableTvFocus, Widget Function(CategoryRowFocusView? focus) builder) {
    if (!enableTvFocus) return builder(null);

    return KeyedSubtree(
      key: _focusHelper.anchorKeyFor(rowIndex),
      child: CategoryRowFocusScope(
        helper: _focusHelper,
        rowIndex: rowIndex,
        builder: builder,
      ),
    );
  }

  Widget _buildChannelRow({
    required int rowIndex,
    required String rowId,
    required String title,
    required List<Channel> items,
    required ChannelsProvider provider,
    required bool isMobile,
    required bool enableTvFocus,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    final previewItems = items.take(kCategoryPreviewLimit).toList();
    final hasMore = items.length > kCategoryPreviewLimit;
    const cardSize = 130.0;

    FocusNode? rowFocusAt(int i) {
      if (i < previewItems.length) {
        return _getFocusNode('${rowId}_${previewItems[i].id}');
      }
      if (i == previewItems.length && hasMore) {
        return _getFocusNode('${rowId}_see_all');
      }
      return null;
    }

    Widget buildRow(CategoryRowFocusView? focus) {
      return MediaRow(
        key: enableTvFocus ? _focusHelper.mediaKeyFor(rowId) : null,
        title: title,
        isDimmed: focus?.isRowDimmed ?? false,
        customHeight: cardSize,
        customWidth: cardSize,
        onSeeMore: hasMore ? () => _openChannelGrid(title, items, isMobile) : null,
        seeAllFocusNode: hasMore && enableTvFocus ? _getFocusNode('${rowId}_see_all') : null,
        seeAllFocusPrevious:
            hasMore && enableTvFocus && previewItems.isNotEmpty ? rowFocusAt(previewItems.length - 1) : null,
        onSeeAllFocusChange: hasMore && enableTvFocus
            ? (focused) {
                if (focused) {
                  _focusHelper.onItemFocused(
                    rowIndex: rowIndex,
                    itemIndex: previewItems.length,
                    rowId: rowId,
                  );
                }
              }
            : null,
        seeAllDimmed: focus?.isItemDimmed(previewItems.length) ?? false,
        itemCount: previewItems.length,
        itemBuilder: (context, index) {
          final channel = previewItems[index];
          return _SearchFocusableChannelCard(
            channel: channel,
            isFavorite: provider.isFavorite(channel.id),
            focusNode: _getFocusNode('${rowId}_${channel.id}'),
            focusPrevious: enableTvFocus && index > 0 ? rowFocusAt(index - 1) : null,
            focusNext: enableTvFocus && index < previewItems.length - 1
                ? rowFocusAt(index + 1)
                : (hasMore && enableTvFocus ? rowFocusAt(previewItems.length) : null),
            dimmed: focus?.isItemDimmed(index) ?? false,
            onFocusChange: enableTvFocus
                ? (focused) {
                    if (focused) {
                      _focusHelper.onItemFocused(
                        rowIndex: rowIndex,
                        itemIndex: index,
                        rowId: rowId,
                      );
                    }
                  }
                : null,
            onTap: () => _openPlayer(
              channel,
              items,
              items.indexWhere((c) => c.id == channel.id),
            ),
          );
        },
      );
    }

    return _wrapTvRow(rowIndex, enableTvFocus, buildRow);
  }

  Widget _buildMovieRow({
    required int rowIndex,
    required String rowId,
    required String title,
    required List<Movie> items,
    required bool isMobile,
    required bool enableTvFocus,
    required bool isLoading,
    required bool previewLimited,
  }) {
    if (!isLoading && items.isEmpty) return const SizedBox.shrink();

    final previewItems = items.take(kCategoryPreviewLimit).toList();
    final hasMore = items.length > kCategoryPreviewLimit;

    FocusNode? rowFocusAt(int i) {
      if (i < previewItems.length) {
        return _getFocusNode('${rowId}_${previewItems[i].id}');
      }
      if (i == previewItems.length && hasMore) {
        return _getFocusNode('${rowId}_see_all');
      }
      return null;
    }

    Widget buildRow(CategoryRowFocusView? focus) {
      return MediaRow(
        key: enableTvFocus ? _focusHelper.mediaKeyFor(rowId) : null,
        title: title,
        isLoading: isLoading,
        isDimmed: focus?.isRowDimmed ?? false,
        onSeeMore: hasMore ? () => _openMovieGrid(title, items, isMobile) : null,
        seeAllFocusNode: hasMore && enableTvFocus ? _getFocusNode('${rowId}_see_all') : null,
        seeAllFocusPrevious:
            hasMore && enableTvFocus && previewItems.isNotEmpty ? rowFocusAt(previewItems.length - 1) : null,
        onSeeAllFocusChange: hasMore && enableTvFocus
            ? (focused) {
                if (focused) {
                  _focusHelper.onItemFocused(
                    rowIndex: rowIndex,
                    itemIndex: previewItems.length,
                    rowId: rowId,
                  );
                }
              }
            : null,
        seeAllDimmed: focus?.isItemDimmed(previewItems.length) ?? false,
        itemCount: previewItems.length,
        itemBuilder: (context, index) {
          final movie = previewItems[index];
          return MediaCard(
            id: '${rowId}_${movie.id}',
            title: movie.title,
            posterUrl: TmdbService.getPosterUrl(movie.posterPath),
            rating: movie.ratingFormatted,
            year: movie.year,
            isMovie: true,
            forceKurdishBadge: previewLimited,
            focusNode: _getFocusNode('${rowId}_${movie.id}'),
            focusPrevious: enableTvFocus && index > 0 ? rowFocusAt(index - 1) : null,
            focusNext: enableTvFocus && index < previewItems.length - 1
                ? rowFocusAt(index + 1)
                : (hasMore && enableTvFocus ? rowFocusAt(previewItems.length) : null),
            dimmed: focus?.isItemDimmed(index) ?? false,
            onFocusChange: enableTvFocus
                ? (focused) {
                    if (focused) {
                      _focusHelper.onItemFocused(
                        rowIndex: rowIndex,
                        itemIndex: index,
                        rowId: rowId,
                      );
                    }
                  }
                : null,
            onTap: () => _openMovieDetail(movie),
          );
        },
      );
    }

    return _wrapTvRow(rowIndex, enableTvFocus, buildRow);
  }

  Widget _buildTvShowRow({
    required int rowIndex,
    required String rowId,
    required String title,
    required List<TvShow> items,
    required bool isMobile,
    required bool enableTvFocus,
    required bool isLoading,
    required bool previewLimited,
  }) {
    if (!isLoading && items.isEmpty) return const SizedBox.shrink();

    final previewItems = items.take(kCategoryPreviewLimit).toList();
    final hasMore = items.length > kCategoryPreviewLimit;

    FocusNode? rowFocusAt(int i) {
      if (i < previewItems.length) {
        return _getFocusNode('${rowId}_${previewItems[i].id}');
      }
      if (i == previewItems.length && hasMore) {
        return _getFocusNode('${rowId}_see_all');
      }
      return null;
    }

    Widget buildRow(CategoryRowFocusView? focus) {
      return MediaRow(
        key: enableTvFocus ? _focusHelper.mediaKeyFor(rowId) : null,
        title: title,
        isLoading: isLoading,
        isDimmed: focus?.isRowDimmed ?? false,
        onSeeMore: hasMore ? () => _openTvGrid(title, items, isMobile) : null,
        seeAllFocusNode: hasMore && enableTvFocus ? _getFocusNode('${rowId}_see_all') : null,
        seeAllFocusPrevious:
            hasMore && enableTvFocus && previewItems.isNotEmpty ? rowFocusAt(previewItems.length - 1) : null,
        onSeeAllFocusChange: hasMore && enableTvFocus
            ? (focused) {
                if (focused) {
                  _focusHelper.onItemFocused(
                    rowIndex: rowIndex,
                    itemIndex: previewItems.length,
                    rowId: rowId,
                  );
                }
              }
            : null,
        seeAllDimmed: focus?.isItemDimmed(previewItems.length) ?? false,
        itemCount: previewItems.length,
        itemBuilder: (context, index) {
          final show = previewItems[index];
          return MediaCard(
            id: '${rowId}_${show.id}',
            title: show.name,
            posterUrl: TmdbService.getPosterUrl(show.posterPath),
            rating: show.ratingFormatted,
            year: show.year,
            isMovie: false,
            focusNode: _getFocusNode('${rowId}_${show.id}'),
            focusPrevious: enableTvFocus && index > 0 ? rowFocusAt(index - 1) : null,
            focusNext: enableTvFocus && index < previewItems.length - 1
                ? rowFocusAt(index + 1)
                : (hasMore && enableTvFocus ? rowFocusAt(previewItems.length) : null),
            dimmed: focus?.isItemDimmed(index) ?? false,
            onFocusChange: enableTvFocus
                ? (focused) {
                    if (focused) {
                      _focusHelper.onItemFocused(
                        rowIndex: rowIndex,
                        itemIndex: index,
                        rowId: rowId,
                      );
                    }
                  }
                : null,
            onTap: () => _openTvShowDetail(show),
          );
        },
      );
    }

    return _wrapTvRow(rowIndex, enableTvFocus, buildRow);
  }

  List<Widget> _buildResultRows({
    required AppLocalizations l10n,
    required ChannelsProvider provider,
    required bool isMobile,
    required bool previewLimited,
    required bool isXtream,
    required List<Movie> movieResults,
    required List<TvShow> tvResults,
    required bool moviesLoading,
    required bool tvLoading,
  }) {
    final enableTvFocus = !isMobile;
    final showKurdishBadge = previewLimited && !isXtream;
    final rows = <Widget>[];
    var rowIndex = 0;

    final liveRow = _buildChannelRow(
      rowIndex: rowIndex,
      rowId: 'search_live',
      title: l10n.translate('live_tv'),
      items: _searchChannelResults,
      provider: provider,
      isMobile: isMobile,
      enableTvFocus: enableTvFocus,
    );
    if (_searchChannelResults.isNotEmpty) {
      rows.add(liveRow);
      rowIndex++;
    }

    final moviesRow = _buildMovieRow(
      rowIndex: rowIndex,
      rowId: 'search_movies',
      title: l10n.translate('movies'),
      items: movieResults,
      isMobile: isMobile,
      enableTvFocus: enableTvFocus,
      isLoading: moviesLoading,
      previewLimited: showKurdishBadge,
    );
    if (moviesLoading || movieResults.isNotEmpty) {
      rows.add(moviesRow);
      rowIndex++;
    }

    final tvRow = _buildTvShowRow(
      rowIndex: rowIndex,
      rowId: 'search_tv',
      title: l10n.translate('tv_shows'),
      items: tvResults,
      isMobile: isMobile,
      enableTvFocus: enableTvFocus,
      isLoading: tvLoading,
      previewLimited: showKurdishBadge,
    );
    if (tvLoading || tvResults.isNotEmpty) {
      rows.add(tvRow);
    }

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Consumer2<ChannelsProvider, SettingsProvider>(
        builder: (context, provider, settings, _) {
          final isMobile = settings.layoutMode == 'mobile';
          final horizontalPadding = isMobile ? AppTheme.spacingM : AppTheme.spacingXL;
          final previewLimited = provider.previewLimited;
          final isXtream = settings.isXtreamSource;

          final q = _searchQuery.toLowerCase();
          final moviesProv = context.watch<MoviesProvider>();
          final tvProv = context.watch<TvShowsProvider>();
          final kurdishMovieMatches = moviesProv.kurdishMovies
              .where((m) => m.title.toLowerCase().contains(q))
              .toList();
          final kurdishTvMatches = tvProv.kurdishTvShows
              .where((t) => t.name.toLowerCase().contains(q))
              .toList();

          final movieResults = isXtream
              ? _searchMovieResults
              : previewLimited
                  ? kurdishMovieMatches
                  : _mergeMovies(kurdishMovieMatches, _searchMovieResults);
          final tvResults = isXtream
              ? _searchTvShowResults
              : previewLimited
                  ? kurdishTvMatches
                  : _mergeTvShows(kurdishTvMatches, _searchTvShowResults);

          final moviesLoading = isXtream
              ? _isLoadingMovies
              : previewLimited
                  ? moviesProv.status == MoviesStatus.loading
                  : _isLoadingMovies;
          final tvLoading = isXtream
              ? _isLoadingTvShows
              : previewLimited
                  ? tvProv.status == TvShowsStatus.loading
                  : _isLoadingTvShows;

          final noResults = _hasSearched &&
              _searchChannelResults.isEmpty &&
              movieResults.isEmpty &&
              tvResults.isEmpty &&
              !moviesLoading &&
              !tvLoading;

          return CustomScrollView(
            controller: _scrollController,
            physics: isMobile ? const BouncingScrollPhysics() : const ClampingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(horizontalPadding),
                  child: Column(
                    children: [
                      if (isMobile) const SizedBox(height: 12),
                      Text(
                        l10n.translate('search'),
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: isMobile ? 24 : 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: isMobile ? 16 : AppTheme.spacingL),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: SearchBarWidget(
                          controller: _searchController,
                          hintText: l10n.translate('search_hint'),
                          onSearch: () {
                            if (_searchQuery.isNotEmpty) _performSearch();
                          },
                          focusNode: _searchFocusNode,
                          isRtl: settings.isRtl,
                          onMoveToSidebar: isMobile
                              ? null
                              : () => TvNavigationScope.maybeOf(context)?.focusSidebar(),
                          onMoveToResults: _searchQuery.isEmpty
                              ? null
                              : () => _focusFirstSearchResult(
                                    channels: _searchChannelResults,
                                    movies: movieResults,
                                    tvShows: tvResults,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (provider.status == ChannelsStatus.loading)
                SliverFillRemaining(
                  child: Center(child: LoadingIndicator(message: '${l10n.translate('search')}...')),
                )
              else if (_searchQuery.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spacingM,
                        horizontal: AppTheme.spacingL,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_rounded,
                            size: isMobile ? 48 : 64,
                            color: AppTheme.textTertiary.withOpacity(0.5),
                          ),
                          const SizedBox(height: AppTheme.spacingM),
                          Text(
                            l10n.translate('search_placeholder'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: isMobile ? 14 : 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (noResults)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spacingM,
                        horizontal: AppTheme.spacingL,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: isMobile ? 48 : 64,
                            color: AppTheme.textTertiary.withOpacity(0.5),
                          ),
                          const SizedBox(height: AppTheme.spacingM),
                          Text(
                            '${l10n.translate('no_results')} "$_searchQuery"',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: isMobile ? 16 : 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.translate('search_error'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: isMobile ? 12 : 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: SizedBox(height: isMobile ? AppTheme.spacingM : AppTheme.spacingL),
                ),
                SliverList(
                  delegate: SliverChildListDelegate(
                    _buildResultRows(
                      l10n: l10n,
                      provider: provider,
                      isMobile: isMobile,
                      previewLimited: previewLimited,
                      isXtream: isXtream,
                      movieResults: movieResults,
                      tvResults: tvResults,
                      moviesLoading: moviesLoading,
                      tvLoading: tvLoading,
                    ),
                  ),
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SearchFocusableChannelCard extends StatelessWidget {
  final Channel channel;
  final bool isFavorite;
  final FocusNode focusNode;
  final FocusNode? focusPrevious;
  final FocusNode? focusNext;
  final VoidCallback onTap;
  final ValueChanged<bool>? onFocusChange;
  final bool dimmed;

  const _SearchFocusableChannelCard({
    required this.channel,
    required this.isFavorite,
    required this.focusNode,
    this.focusPrevious,
    this.focusNext,
    required this.onTap,
    this.onFocusChange,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      onFocusChange: onFocusChange,
      onKeyEvent: (node, event) {
        final settings = Provider.of<SettingsProvider>(context, listen: false);
        final tvNav = TvNavigationScope.maybeOf(context);
        final rowNav = handleTvRowHorizontalKeys(
          event,
          focusPrevious: focusPrevious,
          focusNext: focusNext,
          onMoveToSidebar: tvNav?.isTvLayout == true ? tvNav?.focusSidebar : null,
          isRtl: settings.isRtl,
        );
        if (rowNav == KeyEventResult.handled) return rowNav;

        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          return AnimatedOpacity(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            opacity: dimmed ? 0.45 : 1.0,
            child: GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  border: Border.all(
                    color: isFocused
                        ? AppTheme.focusColor
                        : AppTheme.textTertiary.withValues(alpha: 0.15),
                    width: isFocused ? 3 : 1,
                  ),
                  boxShadow: isFocused
                      ? [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.25),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM - 1),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ChannelLogo(
                        logo: channel.logo,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        memCacheWidth: 400,
                        fallback: Container(
                          color: AppTheme.surfaceColor,
                          child: Icon(
                            Icons.tv_rounded,
                            size: 36,
                            color: AppTheme.textTertiary.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.75),
                                Colors.black.withValues(alpha: 0.92),
                              ],
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                            child: Text(
                              channel.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (isFavorite)
                        const Positioned(
                          top: 6,
                          right: 6,
                          child: Icon(
                            Icons.favorite_rounded,
                            color: AppTheme.accentRed,
                            size: 16,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SearchChannelGridScreen extends StatefulWidget {
  final String title;
  final List<Channel> channels;
  final bool isMobile;

  const _SearchChannelGridScreen({
    required this.title,
    required this.channels,
    required this.isMobile,
  });

  @override
  State<_SearchChannelGridScreen> createState() => _SearchChannelGridScreenState();
}

class _SearchChannelGridScreenState extends State<_SearchChannelGridScreen> {
  final Map<String, FocusNode> _focusNodes = {};

  @override
  void dispose() {
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  FocusNode _nodeFor(String id) => _focusNodes.putIfAbsent(id, FocusNode.new);

  @override
  Widget build(BuildContext context) {
    final padding = widget.isMobile ? AppTheme.spacingM : AppTheme.spacingXXL;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        title: Text(widget.title, style: const TextStyle(color: AppTheme.textPrimary)),
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: GridView.builder(
        padding: EdgeInsets.all(padding),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: widget.isMobile ? 160 : 200,
          childAspectRatio: 1,
          crossAxisSpacing: AppTheme.spacingM,
          mainAxisSpacing: AppTheme.spacingM,
        ),
        itemCount: widget.channels.length,
        itemBuilder: (context, index) {
          final channel = widget.channels[index];
          return _SearchFocusableChannelCard(
            channel: channel,
            isFavorite: Provider.of<ChannelsProvider>(context, listen: false)
                .isFavorite(channel.id),
            focusNode: _nodeFor(channel.id),
            onTap: () {
              PlayerLauncher.launch(
                context: context,
                channel: channel,
                allChannels: widget.channels,
                initialChannelIndex: index,
              );
            },
          );
        },
      ),
    );
  }
}
