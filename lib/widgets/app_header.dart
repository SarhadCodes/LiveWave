import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../config/app_theme.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/movies_provider.dart';
import '../providers/tv_shows_provider.dart';
import '../screens/movie_detail_screen.dart';
import '../screens/tv_show_detail_screen.dart';
import '../l10n/app_localizations.dart';
import '../l10n/app_localizations.dart';

class AppHeader extends StatefulWidget {
  final String statusText;
  final bool showSurpriseMe;
  final String surpriseType; // 'movie' or 'tv'

  const AppHeader({
    super.key,
    this.statusText = 'GLOBAL STREAM OPTIMIZED',
    this.showSurpriseMe = false,
    this.surpriseType = 'movie',
  });

  @override
  State<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends State<AppHeader> {
  late String _timeString;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timeString = _formatTime(DateTime.now());
    _timer = Timer.periodic(const Duration(minutes: 1), (Timer t) => _updateTime());
    _updateTime();
  }

  void _updateTime() {
    final DateTime now = DateTime.now();
    final String formattedTime = _formatTime(now);
    if (mounted && formattedTime != _timeString) {
      setState(() {
        _timeString = formattedTime;
      });
    }
  }

  String _formatTime(DateTime time) {
    return DateFormat('hh:mm a').format(time).toUpperCase();
  }

  void _handleSurpriseMe(BuildContext context) {
    final moviesProvider = Provider.of<MoviesProvider>(context, listen: false);
    final tvShowsProvider = Provider.of<TvShowsProvider>(context, listen: false);
    final random = Random();

    if (widget.surpriseType == 'movie' && moviesProvider.trendingMovies.isNotEmpty) {
      final movie = moviesProvider.trendingMovies[random.nextInt(moviesProvider.trendingMovies.length)];
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => MovieDetailScreen(movie: movie)),
      );
    } else if (widget.surpriseType == 'tv' && tvShowsProvider.trendingTvShows.isNotEmpty) {
      final show = tvShowsProvider.trendingTvShows[random.nextInt(tvShowsProvider.trendingTvShows.length)];
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => TvShowDetailScreen(tvShow: show)),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isMobile = settings.layoutMode == 'mobile';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? AppTheme.spacingM : AppTheme.spacingXL,
        vertical: isMobile ? AppTheme.spacingM : 6.0, // Reduced from spacingM for TV
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'LIVE WAVE',
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontSize: isMobile ? 18 : 16, // Reduced from 22
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
          
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.showSurpriseMe)
                _buildSurpriseButton(context, isMobile)
              else
                _buildStatusIndicator(isMobile),
                
              const SizedBox(width: AppTheme.spacingL),
              Text(
                _timeString,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: isMobile ? 12 : 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSurpriseButton(BuildContext context, bool isMobile) {
    final l10n = AppLocalizations.of(context);
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && 
           (event.logicalKey == LogicalKeyboardKey.enter || 
            event.logicalKey == LogicalKeyboardKey.select)) {
          _handleSurpriseMe(context);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          return GestureDetector(
            onTap: () => _handleSurpriseMe(context),
            child: AnimatedScale(
              scale: isFocused ? 1.05 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isFocused ? AppTheme.primaryColor : AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isFocused ? Colors.white : AppTheme.primaryColor.withOpacity(0.5), 
                    width: isFocused ? 2 : 1
                  ),
                  boxShadow: isFocused ? [
                    BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 10, spreadRadius: 1)
                  ] : [],
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: isFocused ? Colors.black : AppTheme.primaryColor, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      l10n.translate('surprise_me').toUpperCase(),
                      style: TextStyle(
                        color: isFocused ? Colors.black : AppTheme.primaryColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusIndicator(bool isMobile) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: AppTheme.accentGreen,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentGreen.withOpacity(0.5),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          isMobile ? l10n.translate('online').toUpperCase() : l10n.translate('stream_optimized').toUpperCase(),
          style: TextStyle(
            color: AppTheme.textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
