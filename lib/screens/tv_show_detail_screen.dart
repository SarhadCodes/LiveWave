import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';
import '../config/app_theme.dart';
import '../models/tv_show.dart';
import '../services/tmdb_service.dart';
import '../services/xtream_service.dart';
import 'media_custom_player_screen.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/favorites_provider.dart';
import '../services/download_service.dart';
import '../l10n/app_localizations.dart';

class TvShowDetailScreen extends StatefulWidget {
  final TvShow tvShow;

  const TvShowDetailScreen({super.key, required this.tvShow});

  @override
  State<TvShowDetailScreen> createState() => _TvShowDetailScreenState();
}

class _TvShowDetailScreenState extends State<TvShowDetailScreen> {
  final TmdbService _tmdbService = TmdbService();
  final XtreamService _xtreamService = XtreamService();
  bool _isLoadingTrailer = true;
  bool _isLoadingDetails = true;
  bool _isLoadingEpisodes = false;
  String? _trailerUrl;
  
  int _selectedSeason = 1;
  List<dynamic> _seasonsData = [];
  List<dynamic> _episodesData = [];
  Map<int, Map<int, String>> _xtreamEpisodeUrls = {};

  final FocusNode _backButtonFocus = FocusNode(debugLabel: 'backButton');
  final FocusNode _trailerFocus = FocusNode(debugLabel: 'trailer');
  final FocusNode _favoriteFocus = FocusNode(debugLabel: 'favorite');
  final FocusNode _watchNowFocus = FocusNode(debugLabel: 'watchNow');
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    if (widget.tvShow.isXtream && widget.tvShow.xtreamSeriesId != null) {
      await _loadXtreamDetails();
      return;
    }

    try {
      final details = await _tmdbService.getTvShowDetails(widget.tvShow.id);
      if (details.isNotEmpty) {
        final seasons = details['seasons'] as List<dynamic>? ?? [];
        List<dynamic> validSeasons = seasons.where((s) => (s['season_number'] ?? 0) > 0).toList();
        if (validSeasons.isEmpty) validSeasons = seasons;

        if (mounted) {
          setState(() {
            _seasonsData = validSeasons;
            if (validSeasons.isNotEmpty) {
               _selectedSeason = validSeasons.first['season_number'] ?? 1;
            }
            _isLoadingDetails = false;
          });
          _loadSeasonEpisodes(_selectedSeason);
        }
      }
      
      final videos = await _tmdbService.getTvShowVideos(widget.tvShow.id);
      if (videos.isNotEmpty && mounted) {
        setState(() {
          _trailerUrl = 'https://www.youtube.com/watch?v=${videos.first['key']}';
          _isLoadingTrailer = false;
        });
      } else if (mounted) {
        setState(() => _isLoadingTrailer = false);
      }
    } catch (e) {
      if (mounted) setState(() { _isLoadingDetails = false; _isLoadingTrailer = false; });
    }
  }

  Future<void> _loadXtreamDetails() async {
    try {
      final episodes = await _xtreamService.getSeriesEpisodes(widget.tvShow.xtreamSeriesId!);
      if (!mounted) return;

      final seasons = episodes.keys.toList()..sort();
      _xtreamEpisodeUrls = episodes;

      setState(() {
        _seasonsData = seasons
            .map((s) => {'season_number': s, 'name': 'Season $s'})
            .toList();
        _selectedSeason = seasons.isNotEmpty ? seasons.first : 1;
        _isLoadingDetails = false;
        _isLoadingTrailer = false;
      });

      if (seasons.isNotEmpty) {
        _loadXtreamSeasonEpisodes(_selectedSeason);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDetails = false;
          _isLoadingTrailer = false;
        });
      }
    }
  }

  void _loadXtreamSeasonEpisodes(int seasonNumber) {
    final seasonEpisodes = _xtreamEpisodeUrls[seasonNumber] ?? {};
    final episodeNumbers = seasonEpisodes.keys.toList()..sort();

    setState(() {
      _selectedSeason = seasonNumber;
      _isLoadingEpisodes = false;
      _episodesData = episodeNumbers
          .map((num) => {
                'episode_number': num,
                'name': 'Episode $num',
              })
          .toList();
    });
  }

  Future<void> _loadSeasonEpisodes(int seasonNumber) async {
    if (widget.tvShow.isXtream) {
      setState(() => _isLoadingEpisodes = true);
      _loadXtreamSeasonEpisodes(seasonNumber);
      return;
    }

    if (!mounted) return;
    setState(() { _isLoadingEpisodes = true; _selectedSeason = seasonNumber; });
    try {
      final seasonDetails = await _tmdbService.getTvSeasonDetails(widget.tvShow.id, seasonNumber);
      if (mounted) {
        setState(() {
          _episodesData = seasonDetails['episodes'] as List<dynamic>? ?? [];
          _isLoadingEpisodes = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingEpisodes = false);
    }
  }

  void _playEpisode(int season, int episode, String epTitle) {
    final downloadService = Provider.of<DownloadService>(context, listen: false);
    final downloadId = downloadService.generateId(widget.tvShow.id, false, season: season, episode: episode);
    final download = downloadService.getDownload(downloadId);
    final isDownloaded = download?.status == DownloadStatus.completed;
    final xtreamUrl = _xtreamEpisodeUrls[season]?[episode];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MediaCustomPlayerScreen(
          tmdbId: widget.tvShow.isXtream ? null : widget.tvShow.id,
          isMovie: false,
          season: season,
          episode: episode,
          title: '${widget.tvShow.name} - $epTitle',
          seriesTitle: widget.tvShow.name,
          releaseYear: int.tryParse(widget.tvShow.year),
          customUrl: xtreamUrl ?? (isDownloaded ? 'file://${download!.localVideoPath}' : null),
          customSubtitleUrl: isDownloaded && download!.localSubtitlePath != null ? 'file://${download.localSubtitlePath}' : null,
        ),
      ),
    );
  }

  Future<void> _launchTrailer() async {
    if (_trailerUrl != null) {
      final url = Uri.parse(_trailerUrl!);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  void dispose() {
    _backButtonFocus.dispose();
    _trailerFocus.dispose();
    _favoriteFocus.dispose();
    _watchNowFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isTV = settings.layoutMode == 'tv';
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Immersive Backdrop with gradient
          _buildBackdrop(),

          // 2. Main Content
          SafeArea(
            top: false,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildSliverAppBar(l10n, isTV),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTV ? 60.0 : 20.0,
                      vertical: 20.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMainInfo(l10n, isTV),
                        const SizedBox(height: 40),
                        _buildSeasonSection(l10n, isTV),
                        const SizedBox(height: 30),
                        _buildEpisodesSection(l10n, isTV),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackdrop() {
    final String url = TmdbService.getBackdropUrl(widget.tvShow.backdropPath);
    return Positioned.fill(
      child: Stack(
        children: [
          if (url.isNotEmpty)
            CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            )
          else
            Container(color: AppTheme.surfaceColor),
          // Deep cinematic gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.1),
                  Colors.black.withOpacity(0.7),
                  Colors.black,
                ],
                stops: const [0.0, 0.4, 0.8],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(AppLocalizations l10n, bool isTV) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: false,
      leadingWidth: 70,
      expandedHeight: 0,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16, top: 8),
        child: _buildFocusableIconButton(
          focusNode: _backButtonFocus,
          icon: Icons.arrow_back_ios_new_rounded,
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Widget _buildMainInfo(AppLocalizations l10n, bool isTV) {
    if (isTV) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.tvShow.name.toUpperCase(),
                  style: const TextStyle(fontSize: 54, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1, height: 1.1),
                ),
                const SizedBox(height: 16),
                _buildMetadataRow(),
                const SizedBox(height: 24),
                _buildActionButtons(l10n),
              ],
            ),
          ),
        ],
      );
    }

    // Mobile Layout: Vertical Stack
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Hero(
            tag: 'poster_${widget.tvShow.id}',
            child: Container(
              width: 180,
              height: 270,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, offset: const Offset(0, 15))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: TmdbService.getPosterUrl(widget.tvShow.posterPath).isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: TmdbService.getPosterUrl(widget.tvShow.posterPath),
                        fit: BoxFit.cover,
                      )
                    : Container(color: AppTheme.surfaceColor),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          widget.tvShow.name.toUpperCase(),
          textAlign: TextAlign.start,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5, height: 1.1),
        ),
        const SizedBox(height: 16),
        _buildMetadataRow(),
        const SizedBox(height: 32),
        _buildActionButtons(l10n),
      ],
    );
  }

  Widget _buildMetadataRow() {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        _buildMetaTag(widget.tvShow.year),
        _buildMetaTag('TV SERIES'),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, color: AppTheme.primaryColor, size: 20),
            const SizedBox(width: 4),
            Text(
              widget.tvShow.ratingFormatted,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons(AppLocalizations l10n) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        SizedBox(
          width: double.infinity,
          child: _buildPremiumAction(
            label: l10n.translate('watch_now'),
            icon: Icons.play_arrow_rounded,
            focusNode: _watchNowFocus,
            onPressed: () {
              if (_episodesData.isNotEmpty) {
                final ep = _episodesData.first;
                _playEpisode(_selectedSeason, ep['episode_number'] ?? 1, 'S$_selectedSeason:E${ep['episode_number']}');
              }
            },
            primary: true,
          ),
        ),
        _buildPremiumAction(
          label: l10n.translate('watch_trailer'),
          icon: Icons.movie_filter_rounded,
          focusNode: _trailerFocus,
          onPressed: _launchTrailer,
          primary: false,
        ),
        _buildFavoriteAction(),
      ],
    );
  }

  Widget _buildMetaTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPremiumAction({
    required String label,
    required IconData icon,
    required FocusNode focusNode,
    required VoidCallback onPressed,
    bool primary = false,
  }) {
    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.select)) {
          onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(builder: (context) {
        final isFocused = Focus.of(context).hasFocus;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: isFocused ? (Matrix4.identity()..scale(1.05)) : Matrix4.identity(),
          child: ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 24),
            label: Text(label.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary 
                  ? (isFocused ? Colors.white : AppTheme.primaryColor)
                  : (isFocused ? Colors.white24 : Colors.transparent),
              foregroundColor: primary 
                  ? (isFocused ? Colors.black : Colors.black)
                  : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: !primary || isFocused ? const BorderSide(color: Colors.white, width: 2) : BorderSide.none,
              ),
              elevation: isFocused ? 20 : 0,
              shadowColor: AppTheme.primaryColor.withOpacity(0.5),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildFavoriteAction() {
    return Focus(
      focusNode: _favoriteFocus,
      child: Consumer<FavoritesProvider>(
        builder: (context, favorites, _) {
          final isFavorite = favorites.isTvShowFavorite(widget.tvShow.id);
          final isFocused = _favoriteFocus.hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: isFocused ? (Matrix4.identity()..scale(1.1)) : Matrix4.identity(),
            decoration: BoxDecoration(
              color: isFavorite ? Colors.red.withOpacity(0.2) : Colors.white10,
              shape: BoxShape.circle,
              border: Border.all(color: isFocused ? Colors.white : Colors.white24, width: 2),
            ),
            child: IconButton(
              icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.red : Colors.white),
              onPressed: () => favorites.toggleTvShowFavorite(widget.tvShow),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSeasonSection(AppLocalizations l10n, bool isTV) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.translate('seasons').toUpperCase(),
          style: const TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _seasonsData.length,
            itemBuilder: (context, index) {
              final season = _seasonsData[index];
              final num = season['season_number'] ?? 0;
              final isSelected = _selectedSeason == num;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _buildSeasonChip(num, isSelected),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSeasonChip(int number, bool selected) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.select)) {
          _loadSeasonEpisodes(number);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(builder: (context) {
        final isFocused = Focus.of(context).hasFocus;
        return GestureDetector(
          onTap: () => _loadSeasonEpisodes(number),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isFocused ? Colors.white : (selected ? AppTheme.primaryColor : Colors.white10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isFocused ? Colors.white : (selected ? Colors.white38 : Colors.transparent)),
            ),
            child: Text(
              '${AppLocalizations.of(context).translate('season').toUpperCase()} $number',
              style: TextStyle(
                color: isFocused ? Colors.black : (selected ? Colors.black : Colors.white70),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildEpisodesSection(AppLocalizations l10n, bool isTV) {
    if (_isLoadingEpisodes) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${l10n.translate('episodes').toUpperCase()} ($_selectedSeason)',
          style: const TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        const SizedBox(height: 16),
        if (isTV)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.85, // Taller cards to prevent vertical overflow
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
            ),
            itemCount: _episodesData.length,
            itemBuilder: (context, index) => _buildEpisodeTile(_episodesData[index], true),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _episodesData.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) => _buildEpisodeTile(_episodesData[index], false),
          ),
      ],
    );
  }

  Widget _buildEpisodeTile(dynamic ep, bool isTV) {
    final num = ep['episode_number'] ?? 0;
    final name = ep['name'] ?? '';
    final still = ep['still_path'];
    
    return Consumer<DownloadService>(
      builder: (context, downloadService, _) {
        final downloadId = downloadService.generateId(widget.tvShow.id, false, season: _selectedSeason, episode: num);
        final download = downloadService.getDownload(downloadId);
        final isDownloading = download?.status == DownloadStatus.downloading;
        final isDownloaded = download?.status == DownloadStatus.completed;

        Widget downloadIcon;
        if (isDownloading) {
          downloadIcon = SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(
              value: download!.progress > 0 ? download.progress : null,
              color: Colors.white,
              strokeWidth: 2,
            ),
          );
        } else if (isDownloaded) {
          downloadIcon = const Icon(Icons.download_done_rounded, color: Colors.greenAccent, size: 24);
        } else {
          downloadIcon = const Icon(Icons.download_rounded, color: Colors.white70, size: 24);
        }

        final downloadButton = IconButton(
          icon: downloadIcon,
          onPressed: () {
            if (!isDownloading && !isDownloaded) {
              final s = _selectedSeason.toString().padLeft(2, '0');
              final e = num.toString().padLeft(2, '0');
              downloadService.startDownload(
                tmdbId: widget.tvShow.id,
                isMovie: false,
                title: '${widget.tvShow.name} S${s}E$e',
                seriesTitle: widget.tvShow.name,
                season: _selectedSeason,
                episode: num,
                releaseYear: int.tryParse(widget.tvShow.year),
                posterPath: widget.tvShow.posterPath,
              );
            }
          },
        );

        return Focus(
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.select)) {
              _playEpisode(_selectedSeason, num, 'S$_selectedSeason:E$num $name');
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Builder(builder: (context) {
            final isFocused = Focus.of(context).hasFocus;
            return GestureDetector(
              onTap: () => _playEpisode(_selectedSeason, num, 'S$_selectedSeason:E$num $name'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isFocused ? Colors.white.withOpacity(0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isFocused ? Colors.white : Colors.white10, width: isFocused ? 2 : 1),
                ),
                child: isTV 
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              child: TmdbService.getImageUrl(still, size: 'w300').isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: TmdbService.getImageUrl(still, size: 'w300'),
                                      width: double.infinity,
                                      height: 120,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(width: double.infinity, height: 120, color: Colors.white10),
                            ),
                            Positioned(
                              top: 4, right: 4,
                              child: Container(
                                decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                child: downloadButton,
                              ),
                            ),
                            if (isFocused)
                              Positioned.fill(
                                child: Container(
                                  color: Colors.black45,
                                  child: const Center(child: Icon(Icons.play_circle_filled, color: Colors.white, size: 40)),
                                ),
                              ),
                          ],
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'E$num. $name',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: TmdbService.getImageUrl(still, size: 'w300').isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: TmdbService.getImageUrl(still, size: 'w300'),
                                      width: 120,
                                      height: 80,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(width: 120, height: 80, color: Colors.white10),
                            ),
                            if (isFocused)
                              Positioned.fill(
                                child: Container(
                                  color: Colors.black45,
                                  child: const Center(child: Icon(Icons.play_circle_filled, color: Colors.white, size: 40)),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'E$num. $name',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        downloadButton,
                        const SizedBox(width: 8),
                      ],
                    ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildFocusableIconButton({
    required FocusNode focusNode,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.select)) {
          onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(builder: (context) {
        final isFocused = Focus.of(context).hasFocus;
        return GestureDetector(
          onTap: onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isFocused ? Colors.white : Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
              border: Border.all(color: isFocused ? Colors.white : Colors.white24, width: 2),
              boxShadow: isFocused ? [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.5), blurRadius: 15)] : [],
            ),
            child: Icon(
              icon,
              color: isFocused ? Colors.black : Colors.white,
              size: 22,
            ),
          ),
        );
      }),
    );
  }
}

class _ScrollHintIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(child: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white24, size: 32));
  }
}
