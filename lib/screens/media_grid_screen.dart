import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../widgets/media_card.dart';
import '../services/tmdb_service.dart';
import '../models/movie.dart';
import '../models/tv_show.dart';
import '../utils/tv_grid_focus.dart';
import 'movie_detail_screen.dart';
import 'tv_show_detail_screen.dart';

class MediaGridScreen extends StatefulWidget {
  final String title;
  final List<dynamic> items;
  final bool isMobile;

  const MediaGridScreen({
    super.key,
    required this.title,
    required this.items,
    required this.isMobile,
  });

  @override
  State<MediaGridScreen> createState() => _MediaGridScreenState();
}

class _MediaGridScreenState extends State<MediaGridScreen> {
  final Map<String, FocusNode> _focusNodes = {};
  final ScrollController _scrollController = ScrollController();
  final TvGridFocusScheduler _gridFocusScheduler = TvGridFocusScheduler();

  @override
  void dispose() {
    _gridFocusScheduler.dispose();
    _scrollController.dispose();
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  FocusNode _getFocusNode(String id) {
    return _focusNodes.putIfAbsent(id, FocusNode.new);
  }

  void _openItem(dynamic item) {
    if (item is Movie) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => MovieDetailScreen(movie: item)),
      );
    } else if (item is TvShow) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => TvShowDetailScreen(tvShow: item)),
      );
    }
  }

  Widget _buildMobileGrid() {
    return GridView.builder(
      padding: EdgeInsets.all(widget.isMobile ? AppTheme.spacingM : AppTheme.spacingXXL),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.isMobile ? 3 : 5,
        childAspectRatio: widget.isMobile ? 0.7 : 0.68,
        crossAxisSpacing: widget.isMobile ? 12 : 20,
        mainAxisSpacing: widget.isMobile ? 12 : 24,
      ),
      itemCount: widget.items.length,
      itemBuilder: (context, index) => _buildCard(widget.items[index], index),
    );
  }

  Widget _buildTvGrid() {
    final horizontalPadding = AppTheme.spacingXXL;
    const maxCrossAxisExtent = 160.0;
    const crossAxisSpacing = 16.0;
    const mainAxisSpacing = 20.0;
    const posterAspectRatio = 0.68;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - horizontalPadding * 2;
        final columnCount = tvGridColumnCount(
          availableWidth: availableWidth,
          maxCrossAxisExtent: maxCrossAxisExtent,
          crossAxisSpacing: crossAxisSpacing,
        );
        final rowExtent = tvGridMainAxisStride(
          availableWidth: availableWidth,
          maxCrossAxisExtent: maxCrossAxisExtent,
          crossAxisSpacing: crossAxisSpacing,
          mainAxisSpacing: mainAxisSpacing,
          childAspectRatio: posterAspectRatio,
        );
        final headerExtent = kToolbarHeight + horizontalPadding;

        FocusNode gridFocusAt(int i) {
          final item = widget.items[i];
          final id = item is Movie ? item.id : (item as TvShow).id;
          return _getFocusNode('grid_$id');
        }

        void scrollGridToIndex(int index) {
          scrollCategoryGridToIndex(
            _scrollController,
            index: index,
            columnCount: columnCount,
            rowExtent: rowExtent,
            headerExtent: headerExtent,
          );
        }

        return CustomScrollView(
          controller: _scrollController,
          physics: const ClampingScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: AppTheme.backgroundColor,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  _gridFocusScheduler.cancel();
                  Navigator.pop(context);
                },
              ),
              title: Text(
                widget.title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.all(horizontalPadding),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: maxCrossAxisExtent,
                  childAspectRatio: posterAspectRatio,
                  crossAxisSpacing: crossAxisSpacing,
                  mainAxisSpacing: mainAxisSpacing,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildCard(
                    widget.items[index],
                    index,
                    gridFocusAt: gridFocusAt,
                    columnCount: columnCount,
                    onPrepareGridTarget: (target, {required vertical}) {
                      if (vertical) scrollGridToIndex(target);
                    },
                  ),
                  childCount: widget.items.length,
                ),
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
          ],
        );
      },
    );
  }

  Widget _buildCard(
    dynamic item,
    int index, {
    FocusNode Function(int i)? gridFocusAt,
    int? columnCount,
    void Function(int targetIndex, {required bool vertical})? onPrepareGridTarget,
  }) {
    final isMovie = item is Movie;
    final movie = isMovie ? item as Movie : null;
    final tvShow = isMovie ? null : item as TvShow;
    final id = isMovie ? movie!.id : tvShow!.id;
    final title = isMovie ? movie!.title : tvShow!.name;
    final posterPath = isMovie ? movie!.posterPath : tvShow!.posterPath;
    final rating = isMovie ? movie!.ratingFormatted : tvShow!.ratingFormatted;
    final year = isMovie ? movie!.year : tvShow!.year;

    return MediaCard(
      id: 'grid_$id',
      title: title,
      posterUrl: TmdbService.getPosterUrl(posterPath),
      rating: rating,
      year: year,
      isMovie: isMovie,
      focusNode: gridFocusAt != null ? gridFocusAt(index) : null,
      gridIndex: gridFocusAt != null ? index : null,
      gridItemCount: gridFocusAt != null ? widget.items.length : null,
      gridColumnCount: columnCount,
      focusNodeAtIndex: gridFocusAt,
      gridFocusScheduler: gridFocusAt != null ? _gridFocusScheduler : null,
      onPrepareGridTarget: onPrepareGridTarget,
      onTap: () => _openItem(item),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isMobile) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            widget.title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _buildMobileGrid(),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _buildTvGrid(),
    );
  }
}
