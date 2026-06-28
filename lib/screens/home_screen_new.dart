import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../models/channel.dart';
import '../models/ad.dart';
import '../providers/channels_provider.dart';
import '../services/firestore_service.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/ad_slideshow.dart';
import '../widgets/channel_card.dart';
import '../services/player_launcher.dart';
import '../providers/settings_provider.dart';
import 'player_screen.dart';
import '../providers/favorites_provider.dart';
import '../models/movie.dart';
import '../models/tv_show.dart';
import '../widgets/media_card.dart';
import '../services/tmdb_service.dart';
import 'movie_detail_screen.dart';
import 'tv_show_detail_screen.dart';

import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import '../l10n/app_localizations.dart';

class HomeScreenNew extends StatefulWidget {
  const HomeScreenNew({super.key});

  @override
  State<HomeScreenNew> createState() => _HomeScreenNewState();
}

class _HomeScreenNewState extends State<HomeScreenNew> {
  final FirestoreService _firestoreService = FirestoreService();
  List<Ad> _ads = [];
  bool _isLoadingAds = true;
  final Map<String, FocusNode> _focusNodes = {};

  @override
  void initState() {
    super.initState();
    _loadAds();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ChannelsProvider>(context, listen: false);
      if (provider.status == ChannelsStatus.initial) {
        provider.fetchChannels();
      }
    });
  }

  @override
  void dispose() {
    for (var node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAds() async {
    try {
      final ads = await _firestoreService.getActiveAds();
      if (mounted) {
        setState(() {
          _ads = ads;
          _isLoadingAds = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingAds = false);
    }
  }

  Future<void> _handleRefresh() async {
    final channelsProv = Provider.of<ChannelsProvider>(context, listen: false);
    await Future.wait([
      _loadAds(),
      channelsProv.fetchChannels(),
    ]);
  }

  FocusNode _getFocusNode(String id) {
    if (!_focusNodes.containsKey(id)) {
      _focusNodes[id] = FocusNode();
    }
    return _focusNodes[id]!;
  }

  void _openPlayer(Channel channel, List<Channel> channels, int index) {
    PlayerLauncher.launch(
      context: context,
      channel: channel,
      allChannels: channels,
      initialChannelIndex: index,
    );
  }

  Widget _buildSectionTitle(String title, bool isMobile) {
    return Row(
      children: [
        Container(
          width: 4,
          height: isMobile ? 20 : 24,
          decoration: BoxDecoration(
            color: AppTheme.accentRed,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: isMobile ? 16 : 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Consumer3<ChannelsProvider, SettingsProvider, FavoritesProvider>(
        builder: (context, channelProv, settings, favorites, _) {
          final isMobile = settings.layoutMode == 'mobile';
          final horizontalPadding = isMobile ? AppTheme.spacingM : AppTheme.spacingXXL;

          Widget content = SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ad Slideshow
                _isLoadingAds
                    ? Container(
                        height: isMobile ? 220 : 350,
                        child: Center(child: LoadingIndicator(message: '${l10n.translate('featured')}...')),
                      )
                    : AdSlideshow(ads: _ads),
                
                const SizedBox(height: AppTheme.spacingL),

                // --- FAVORITE TV CHANNELS ---
                if (channelProv.favoriteChannels.isNotEmpty) ...[
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle(l10n.translate('live_tv').toUpperCase(), isMobile),
                        const SizedBox(height: 16),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: isMobile ? 120 : 110,
                            childAspectRatio: 1.1,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: channelProv.favoriteChannels.length,
                          itemBuilder: (context, index) {
                            final channel = channelProv.favoriteChannels[index];
                            return ChannelCard(
                              channel: channel,
                              onTap: () => _openPlayer(channel, channelProv.favoriteChannels, index),
                              isTVMode: !isMobile,
                              focusNode: _getFocusNode('ch_${channel.id}'),
                              isFavorite: true,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                // --- FAVORITE MOVIES ---
                if (favorites.favoriteMovies.isNotEmpty) ...[
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle(l10n.translate('movies').toUpperCase(), isMobile),
                        const SizedBox(height: 16),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: isMobile ? 120 : 120,
                            childAspectRatio: isMobile ? 0.7 : 0.65,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: favorites.favoriteMovies.length,
                          itemBuilder: (context, index) {
                            final movie = favorites.favoriteMovies[index];
                            return MediaCard(
                              id: movie.id.toString(),
                              title: movie.title,
                              posterUrl: TmdbService.getPosterUrl(movie.posterPath),
                              rating: movie.ratingFormatted,
                              year: movie.year,
                              isMovie: true,
                              focusNode: _getFocusNode('mov_${movie.id}'),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => MovieDetailScreen(movie: movie)),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                // --- FAVORITE TV SHOWS ---
                if (favorites.favoriteTvShows.isNotEmpty) ...[
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle(l10n.translate('tv_shows').toUpperCase(), isMobile),
                        const SizedBox(height: 16),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: isMobile ? 120 : 120,
                            childAspectRatio: isMobile ? 0.7 : 0.65,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: favorites.favoriteTvShows.length,
                          itemBuilder: (context, index) {
                            final show = favorites.favoriteTvShows[index];
                            return MediaCard(
                              id: show.id.toString(),
                              title: show.name,
                              posterUrl: TmdbService.getPosterUrl(show.posterPath),
                              rating: show.ratingFormatted,
                              year: show.year,
                              isMovie: false,
                              focusNode: _getFocusNode('tv_${show.id}'),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => TvShowDetailScreen(tvShow: show)),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                // If everything is empty, show a unified placeholder
                if (channelProv.favoriteChannels.isEmpty && 
                    favorites.favoriteMovies.isEmpty && 
                    favorites.favoriteTvShows.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 40),
                      child: Column(
                        children: [
                          Icon(Icons.favorite_border, size: 64, color: Colors.white.withOpacity(0.1)),
                          const SizedBox(height: 20),
                          Text(
                            l10n.translate('no_favorites'),
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.translate('error_try_again'),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textTertiary, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                const SizedBox(height: 40),
              ],
            ),
          );

          if (isMobile) {
            return LiquidPullToRefresh(
              onRefresh: _handleRefresh,
              color: Colors.white,
              backgroundColor: AppTheme.cardColor,
              showChildOpacityTransition: false,
              child: content,
            );
          }

          return content;
        },
      ),
    );
  }
}
