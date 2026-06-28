import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../models/channel.dart';
import '../models/movie.dart';
import '../models/tv_show.dart';
import '../providers/channels_provider.dart';
import '../services/tmdb_service.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/channel_card.dart';
import '../widgets/media_card.dart';
import '../widgets/loading_indicator.dart';
import '../services/player_launcher.dart';
import 'player_screen.dart';
import 'movie_detail_screen.dart';
import 'tv_show_detail_screen.dart';
import '../providers/settings_provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/movies_provider.dart';
import '../providers/tv_shows_provider.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
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

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _focusNodes.values.forEach((node) => node.dispose());
    super.dispose();
  }

  FocusNode _getFocusNode(String uniqueId) {
    if (!_focusNodes.containsKey(uniqueId)) {
      _focusNodes[uniqueId] = FocusNode();
    }
    return _focusNodes[uniqueId]!;
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      if (_searchQuery.isNotEmpty) {
        _performSearch();
      } else {
        _searchChannelResults = [];
        _searchMovieResults = [];
        _searchTvShowResults = [];
        _hasSearched = false;
      }
    });
  }

  void _performSearch() {
    final query = _searchQuery.toLowerCase();
    final provider = Provider.of<ChannelsProvider>(context, listen: false);
    
    setState(() {
      _searchChannelResults = provider.channels.where((channel) {
        return channel.name.toLowerCase().contains(query) ||
               channel.category.toLowerCase().contains(query);
      }).toList();
      _hasSearched = true;
      _isLoadingMovies = true;
      _isLoadingTvShows = true;
    });

    final tmdbService = TmdbService();
    
    tmdbService.searchMovies(_searchQuery).then((movies) {
      if (mounted) {
        setState(() {
          _searchMovieResults = movies;
          _isLoadingMovies = false;
        });
      }
    }).catchError((_) {
      if (mounted) {
        setState(() {
          _isLoadingMovies = false;
        });
      }
    });

    tmdbService.searchTvShows(_searchQuery).then((tvShows) {
      if (mounted) {
        setState(() {
          _searchTvShowResults = tvShows;
          _isLoadingTvShows = false;
        });
      }
    }).catchError((_) {
      if (mounted) {
        setState(() {
          _isLoadingTvShows = false;
        });
      }
    });
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Consumer2<ChannelsProvider, SettingsProvider>(
        builder: (context, provider, settings, _) {
          final isMobile = settings.layoutMode == 'mobile';
          final horizontalPadding = isMobile ? AppTheme.spacingM : AppTheme.spacingXL;

          bool noResults = _hasSearched &&
              _searchChannelResults.isEmpty &&
              _searchMovieResults.isEmpty &&
              _searchTvShowResults.isEmpty &&
              !_isLoadingMovies &&
              !_isLoadingTvShows;

          return CustomScrollView(
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
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: isMobile ? 48 : 64,
                          color: AppTheme.textTertiary.withOpacity(0.5),
                        ),
                        const SizedBox(height: AppTheme.spacingM),
                        Text(
                          l10n.translate('search_placeholder'),
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: isMobile ? 14 : 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (noResults)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: isMobile ? 48 : 64,
                          color: AppTheme.textTertiary.withOpacity(0.5),
                        ),
                        const SizedBox(height: AppTheme.spacingM),
                        Text(
                          '${l10n.translate('no_results')} "$_searchQuery"',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: isMobile ? 16 : 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            l10n.translate('search_error'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: isMobile ? 12 : 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                // Kurdish Subtitled Matches (Movies)
                Consumer<MoviesProvider>(
                  builder: (context, moviesProv, _) {
                    final matchingKurdishMovies = moviesProv.kurdishMovies.where((m) {
                      final q = _searchQuery.toLowerCase();
                      return m.title.toLowerCase().contains(q);
                    }).toList();
                    
                    if (matchingKurdishMovies.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                    
                    return SliverMainAxisGroup(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: AppTheme.spacingM),
                            child: Row(
                              children: [
                                const Icon(Icons.subtitles_rounded, color: AppTheme.primaryColor, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  "KURDISH SUBTITLED MOVIES",
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: isMobile ? 14 : 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                          sliver: SliverGrid(
                            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: isMobile ? 110 : 160,
                              childAspectRatio: 0.7,
                              crossAxisSpacing: isMobile ? AppTheme.spacingM : AppTheme.spacingL,
                              mainAxisSpacing: isMobile ? AppTheme.spacingM : AppTheme.spacingL,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final movie = matchingKurdishMovies[index];
                                return MediaCard(
                                  id: 'search_kurdish_movie_${movie.id}',
                                  title: movie.title,
                                  posterUrl: TmdbService.getPosterUrl(movie.posterPath),
                                  rating: movie.ratingFormatted,
                                  year: movie.year,
                                  isMovie: true,
                                  forceKurdishBadge: true,
                                  focusNode: _getFocusNode('search_kurdish_movie_${movie.id}'),
                                  onTap: () => _openMovieDetail(movie),
                                );
                              },
                              childCount: matchingKurdishMovies.length,
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacingXL)),
                      ],
                    );
                  },
                ),

                // Kurdish Subtitled Matches (TV Shows)
                Consumer<TvShowsProvider>(
                  builder: (context, tvProv, _) {
                    final matchingKurdishTv = tvProv.kurdishTvShows.where((t) {
                      final q = _searchQuery.toLowerCase();
                      return t.name.toLowerCase().contains(q);
                    }).toList();

                    if (matchingKurdishTv.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                    
                    return SliverMainAxisGroup(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: AppTheme.spacingM),
                            child: Row(
                              children: [
                                const Icon(Icons.subtitles_rounded, color: AppTheme.primaryColor, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  "KURDISH SUBTITLED TV SHOWS",
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: isMobile ? 14 : 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                          sliver: SliverGrid(
                            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: isMobile ? 110 : 160,
                              childAspectRatio: 0.7,
                              crossAxisSpacing: isMobile ? AppTheme.spacingM : AppTheme.spacingL,
                              mainAxisSpacing: isMobile ? AppTheme.spacingM : AppTheme.spacingL,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final tv = matchingKurdishTv[index];
                                return MediaCard(
                                  id: 'search_kurdish_tv_${tv.id}',
                                  title: tv.name,
                                  posterUrl: TmdbService.getPosterUrl(tv.posterPath),
                                  rating: tv.ratingFormatted,
                                  year: tv.year,
                                  isMovie: false,
                                  focusNode: _getFocusNode('search_kurdish_tv_${tv.id}'),
                                  onTap: () => _openTvShowDetail(tv),
                                );
                              },
                              childCount: matchingKurdishTv.length,
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacingXL)),
                      ],
                    );
                  },
                ),

                // Channels Section
                if (_searchChannelResults.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: AppTheme.spacingM),
                      child: Text(
                        l10n.translate('live_tv'),
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: isMobile ? 20 : 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: isMobile ? 120 : 200,
                        childAspectRatio: 1.1,
                        crossAxisSpacing: isMobile ? AppTheme.spacingM : AppTheme.spacingL,
                        mainAxisSpacing: isMobile ? AppTheme.spacingM : AppTheme.spacingL,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final channel = _searchChannelResults[index];
                          return ChannelCard(
                            channel: channel,
                            onTap: () => _openPlayer(channel, _searchChannelResults, index),
                            isTVMode: !isMobile,
                            focusNode: _getFocusNode('channel_${channel.id}'),
                            isFavorite: provider.isFavorite(channel.id),
                          );
                        },
                        childCount: _searchChannelResults.length,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacingXL)),
                ],

                // Movies Section
                if (_isLoadingMovies)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(AppTheme.spacingXL),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (_searchMovieResults.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: AppTheme.spacingM),
                      child: Text(
                        l10n.translate('movies'),
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: isMobile ? 20 : 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: isMobile ? 110 : 160,
                        childAspectRatio: 0.7,
                        crossAxisSpacing: isMobile ? AppTheme.spacingM : AppTheme.spacingL,
                        mainAxisSpacing: isMobile ? AppTheme.spacingM : AppTheme.spacingL,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final movie = _searchMovieResults[index];
                          return MediaCard(
                            id: 'movie_${movie.id}',
                            title: movie.title,
                            posterUrl: TmdbService.getPosterUrl(movie.posterPath),
                            rating: movie.ratingFormatted,
                            year: movie.year,
                            isMovie: true,
                            focusNode: _getFocusNode('movie_${movie.id}'),
                            onTap: () => _openMovieDetail(movie),
                          );
                        },
                        childCount: _searchMovieResults.length,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacingXL)),
                ],

                // TV Shows Section
                if (_isLoadingTvShows)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(AppTheme.spacingXL),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (_searchTvShowResults.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: AppTheme.spacingM),
                      child: Text(
                        l10n.translate('tv_shows'),
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: isMobile ? 20 : 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: isMobile ? 110 : 160,
                        childAspectRatio: 0.7,
                        crossAxisSpacing: isMobile ? AppTheme.spacingM : AppTheme.spacingL,
                        mainAxisSpacing: isMobile ? AppTheme.spacingM : AppTheme.spacingL,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final show = _searchTvShowResults[index];
                          return MediaCard(
                            id: 'tvshow_${show.id}',
                            title: show.name,
                            posterUrl: TmdbService.getPosterUrl(show.posterPath),
                            rating: show.ratingFormatted,
                            year: show.year,
                            isMovie: false,
                            focusNode: _getFocusNode('tvshow_${show.id}'),
                            onTap: () => _openTvShowDetail(show),
                          );
                        },
                        childCount: _searchTvShowResults.length,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacingXXL)),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}
