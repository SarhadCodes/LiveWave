import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';
import '../config/app_theme.dart';
import '../models/movie.dart';
import '../services/tmdb_service.dart';
import 'media_custom_player_screen.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/favorites_provider.dart';
import '../services/download_service.dart';
import '../l10n/app_localizations.dart';

class MovieDetailScreen extends StatefulWidget {
  final Movie movie;

  const MovieDetailScreen({super.key, required this.movie});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  final TmdbService _tmdbService = TmdbService();
  bool _isLoadingTrailer = true;
  String? _trailerUrl;

  final FocusNode _backButtonFocus = FocusNode(debugLabel: 'backButton');
  final FocusNode _watchNowFocus = FocusNode(debugLabel: 'watchNow');
  final FocusNode _favoriteFocus = FocusNode(debugLabel: 'favorite');
  final FocusNode _trailerFocus = FocusNode(debugLabel: 'trailer');
  final FocusNode _downloadFocus = FocusNode(debugLabel: 'download');

  @override
  void initState() {
    super.initState();
    _loadTrailer();
  }

  Future<void> _loadTrailer() async {
    try {
      final videos = await _tmdbService.getMovieVideos(widget.movie.id);
      if (videos.isNotEmpty && mounted) {
        setState(() {
          _trailerUrl = 'https://www.youtube.com/watch?v=${videos.first['key']}';
          _isLoadingTrailer = false;
        });
      } else if (mounted) {
        setState(() => _isLoadingTrailer = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingTrailer = false);
    }
  }

  void _playMovie() {
    final downloadService = Provider.of<DownloadService>(context, listen: false);
    final downloadId = downloadService.generateId(widget.movie.id, true);
    final download = downloadService.getDownload(downloadId);
    final isDownloaded = download?.status == DownloadStatus.completed;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MediaCustomPlayerScreen(
          tmdbId: widget.movie.isXtream ? null : widget.movie.id,
          isMovie: true,
          title: widget.movie.title,
          releaseYear: int.tryParse(widget.movie.year),
          customUrl: widget.movie.isXtream
              ? widget.movie.streamUrl
              : (isDownloaded ? 'file://${download!.localVideoPath}' : null),
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
    _watchNowFocus.dispose();
    _favoriteFocus.dispose();
    _trailerFocus.dispose();
    _downloadFocus.dispose();
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
          // 1. Immersive Backdrop
          Positioned.fill(
            child: Stack(
              children: [
                if (TmdbService.getBackdropUrl(widget.movie.backdropPath).isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: TmdbService.getBackdropUrl(widget.movie.backdropPath),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  )
                else
                  Container(color: AppTheme.surfaceColor),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.3),
                        Colors.black.withOpacity(0.8),
                        Colors.black,
                      ],
                      stops: const [0.0, 0.4, 0.9],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Content
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  pinned: false,
                  leadingWidth: 70,
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 16, top: 8),
                    child: _buildFocusableIconButton(
                      focusNode: _backButtonFocus,
                      icon: Icons.arrow_back_ios_new_rounded,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTV ? 60.0 : 24.0,
                      vertical: 20.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMainInfo(l10n, isTV),
                        const SizedBox(height: 60),
                        _buildGenresSection(),
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
                  widget.movie.title.toUpperCase(),
                  style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1, height: 1.1),
                ),
                const SizedBox(height: 16),
                _buildMetadataRow(),
                const SizedBox(height: 40),
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
            tag: 'poster_${widget.movie.id}',
            child: Container(
              width: 180,
              height: 270,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, offset: const Offset(0, 15))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: TmdbService.getPosterUrl(widget.movie.posterPath).isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: TmdbService.getPosterUrl(widget.movie.posterPath),
                        fit: BoxFit.cover,
                      )
                    : Container(color: AppTheme.surfaceColor),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          widget.movie.title.toUpperCase(),
          textAlign: TextAlign.start,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5, height: 1.1),
        ),
        const SizedBox(height: 16),
        _buildMetadataRow(),
        const SizedBox(height: 40),
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
        _buildMetaTag(widget.movie.year),
        _buildMetaTag('MOVIE'),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, color: AppTheme.primaryColor, size: 22),
            const SizedBox(width: 4),
            Text(
              widget.movie.ratingFormatted,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons(AppLocalizations l10n) {
    return Consumer<DownloadService>(
      builder: (context, downloadService, child) {
        final downloadId = downloadService.generateId(widget.movie.id, true);
        final download = downloadService.getDownload(downloadId);
        
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
                onPressed: _playMovie,
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
            _buildDownloadAction(downloadService, download),
            _buildFavoriteAction(),
          ],
        );
      },
    );
  }

  Widget _buildDownloadAction(DownloadService service, DownloadItem? download) {
    final isDownloading = download?.status == DownloadStatus.downloading;
    final isDownloaded = download?.status == DownloadStatus.completed;
    
    return Focus(
      focusNode: _downloadFocus,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.select)) {
          if (!isDownloading && !isDownloaded) {
            service.startDownload(
              tmdbId: widget.movie.id,
              isMovie: true,
              title: widget.movie.title,
              releaseYear: int.tryParse(widget.movie.year),
              posterPath: widget.movie.posterPath,
            );
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(builder: (context) {
        final isFocused = Focus.of(context).hasFocus;
        
        Widget icon;
        if (isDownloading) {
          icon = SizedBox(
            width: 24, height: 24,
            child: CircularProgressIndicator(
              value: download!.progress > 0 ? download.progress : null,
              color: isFocused ? Colors.black : Colors.white,
              strokeWidth: 3,
            ),
          );
        } else if (isDownloaded) {
          icon = Icon(Icons.download_done_rounded, color: isFocused ? Colors.black : Colors.greenAccent, size: 28);
        } else {
          icon = Icon(Icons.download_rounded, color: isFocused ? Colors.black : Colors.white, size: 28);
        }

        return GestureDetector(
          onTap: () {
            if (!isDownloading && !isDownloaded) {
              service.startDownload(
                tmdbId: widget.movie.id,
                isMovie: true,
                title: widget.movie.title,
                releaseYear: int.tryParse(widget.movie.year),
                posterPath: widget.movie.posterPath,
              );
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isFocused ? Colors.white : Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
              border: Border.all(color: isFocused ? Colors.white : Colors.white24, width: 2),
              boxShadow: isFocused ? [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.5), blurRadius: 15)] : [],
            ),
            child: icon,
          ),
        );
      }),
    );
  }

  Widget _buildMetaTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
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
          transform: isFocused ? (Matrix4.identity()..scale(1.08)) : Matrix4.identity(),
          child: ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 28),
            label: Text(label.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary 
                  ? (isFocused ? Colors.white : AppTheme.primaryColor)
                  : (isFocused ? Colors.white24 : Colors.transparent),
              foregroundColor: primary 
                  ? (isFocused ? Colors.black : Colors.black)
                  : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: isFocused ? const BorderSide(color: Colors.white, width: 3) : (primary ? BorderSide.none : const BorderSide(color: Colors.white24)),
              ),
              elevation: isFocused ? 25 : 0,
              shadowColor: AppTheme.primaryColor.withOpacity(0.6),
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
          final isFavorite = favorites.isMovieFavorite(widget.movie.id);
          final isFocused = _favoriteFocus.hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: isFocused ? (Matrix4.identity()..scale(1.15)) : Matrix4.identity(),
            decoration: BoxDecoration(
              color: isFavorite ? Colors.red.withOpacity(0.3) : Colors.white10,
              shape: BoxShape.circle,
              border: Border.all(color: isFocused ? Colors.white : Colors.white24, width: 2),
              boxShadow: isFocused ? [BoxShadow(color: Colors.white24, blurRadius: 15)] : [],
            ),
            child: IconButton(
              icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.red : Colors.white, size: 28),
              onPressed: () => favorites.toggleMovieFavorite(widget.movie),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGenresSection() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: widget.movie.genreNames.map((g) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white10),
          color: Colors.white.withOpacity(0.05),
        ),
        child: Text(g, style: const TextStyle(color: Colors.white60, fontSize: 14)),
      )).toList(),
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
