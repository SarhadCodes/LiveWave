import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/movie.dart';
import '../models/tv_show.dart';
import '../services/tmdb_service.dart';
import 'movie_detail_screen.dart';
import 'tv_show_detail_screen.dart';

class PersonDetailScreen extends StatefulWidget {
  final int personId;
  final String name;
  final String profilePath;

  const PersonDetailScreen({
    super.key,
    required this.personId,
    required this.name,
    this.profilePath = '',
  });

  @override
  State<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends State<PersonDetailScreen> {
  final TmdbService _tmdb = TmdbService();
  final FocusNode _backButtonFocus = FocusNode(debugLabel: 'personBack');

  bool _loading = true;
  String _name = '';
  String _bio = '';
  String _profilePath = '';
  List<Movie> _movies = const [];
  List<TvShow> _tvShows = const [];

  @override
  void initState() {
    super.initState();
    _name = widget.name;
    _profilePath = widget.profilePath;
    _load();
  }

  Future<void> _load() async {
    try {
      final details = await _tmdb.getPersonDetails(widget.personId);
      final credits = await _tmdb.getPersonFilmography(widget.personId);
      if (!mounted) return;
      setState(() {
        if (details['name'] != null && details['name'].toString().isNotEmpty) {
          _name = details['name'].toString();
        }
        _bio = (details['biography'] ?? '').toString();
        final path = (details['profile_path'] ?? '').toString();
        if (path.isNotEmpty) _profilePath = path;
        _movies = credits.movies;
        _tvShows = credits.tvShows;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _backButtonFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isTV = MediaQuery.sizeOf(context).width >= 900;
    final photoUrl = TmdbService.getImageUrl(_profilePath, size: 'w300');

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leadingWidth: 70,
              leading: Padding(
                padding: const EdgeInsets.only(left: 16, top: 8),
                child: _BackButton(
                  focusNode: _backButtonFocus,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isTV ? 60 : 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(
                            width: isTV ? 160 : 110,
                            height: isTV ? 240 : 165,
                            child: photoUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: photoUrl,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 300,
                                    errorWidget: (context, url, error) => _photoFallback(),
                                  )
                                : _photoFallback(),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _name.toUpperCase(),
                                style: TextStyle(
                                  fontSize: isTV ? 36 : 26,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.translate('cast'),
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_bio.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        l10n.translate('biography').toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _bio,
                        maxLines: isTV ? 8 : 6,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, height: 1.45, fontSize: 14),
                      ),
                    ],
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(color: AppTheme.primaryColor),
                        ),
                      )
                    else ...[
                      const SizedBox(height: 36),
                      _CreditRow(
                        title: l10n.translate('acted_in_movies'),
                        isTV: isTV,
                        emptyLabel: l10n.translate('no_filmography'),
                        children: _movies
                            .map(
                              (m) => _PosterTile(
                                title: m.title,
                                year: m.year,
                                posterPath: m.posterPath,
                                isTV: isTV,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MovieDetailScreen(movie: m),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 28),
                      _CreditRow(
                        title: l10n.translate('acted_in_tv'),
                        isTV: isTV,
                        emptyLabel: l10n.translate('no_filmography'),
                        children: _tvShows
                            .map(
                              (s) => _PosterTile(
                                title: s.name,
                                year: s.year,
                                posterPath: s.posterPath,
                                isTV: isTV,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TvShowDetailScreen(tvShow: s),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoFallback() {
    return Container(
      color: AppTheme.surfaceColor,
      child: const Icon(Icons.person_rounded, color: Colors.white38, size: 48),
    );
  }
}

class _CreditRow extends StatelessWidget {
  final String title;
  final bool isTV;
  final String emptyLabel;
  final List<Widget> children;

  const _CreditRow({
    required this.title,
    required this.isTV,
    required this.emptyLabel,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 16),
        if (children.isEmpty)
          Text(emptyLabel, style: const TextStyle(color: Colors.white38))
        else
          SizedBox(
            height: isTV ? 250 : 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: children.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, i) => children[i],
            ),
          ),
      ],
    );
  }
}

class _PosterTile extends StatelessWidget {
  final String title;
  final String year;
  final String posterPath;
  final bool isTV;
  final VoidCallback onTap;

  const _PosterTile({
    required this.title,
    required this.year,
    required this.posterPath,
    required this.isTV,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = isTV ? 130.0 : 110.0;
    final height = isTV ? 195.0 : 165.0;
    final url = TmdbService.getPosterUrl(posterPath);

    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.select)) {
          onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(builder: (context) {
        final focused = Focus.of(context).hasFocus;
        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: width,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: focused ? Colors.white : Colors.transparent, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: url.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            width: width,
                            height: height,
                            memCacheWidth: 300,
                            errorWidget: (context, url, error) => Container(color: AppTheme.surfaceColor),
                          )
                        : Container(color: AppTheme.surfaceColor),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                ),
                if (year.isNotEmpty)
                  Text(year, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _BackButton extends StatelessWidget {
  final FocusNode focusNode;
  final VoidCallback onPressed;

  const _BackButton({required this.focusNode, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.select)) {
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
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: isFocused ? Colors.black : Colors.white,
              size: 22,
            ),
          ),
        );
      }),
    );
  }
}
