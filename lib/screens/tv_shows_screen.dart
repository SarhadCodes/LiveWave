import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/tv_shows_provider.dart';
import '../services/tmdb_service.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/media_card.dart';
import '../widgets/media_row.dart';
import 'tv_show_detail_screen.dart';
import '../models/tv_show.dart';

import '../providers/settings_provider.dart';
import '../providers/watch_history_provider.dart';
import '../widgets/continue_watching_row.dart';
import '../models/watch_history_item.dart';
import '../widgets/hero_slideshow.dart';
import 'media_grid_screen.dart';

import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import '../l10n/app_localizations.dart';
import '../utils/category_row_focus_helper.dart';
import '../utils/category_order_utils.dart';

class TvShowsScreen extends StatefulWidget {
  const TvShowsScreen({super.key});

  @override
  State<TvShowsScreen> createState() => _TvShowsScreenState();
}

class _TvShowsScreenState extends State<TvShowsScreen> {
  final Map<String, FocusNode> _focusNodes = {};
  final CategoryRowFocusHelper _focusHelper = CategoryRowFocusHelper();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<TvShowsProvider>(context, listen: false);
      provider.fetchAllTvShows();
    });
  }

  @override
  void dispose() {
    _focusHelper.dispose();
    for (var node in _focusNodes.values) {
      node.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    final provider = Provider.of<TvShowsProvider>(context, listen: false);
    _focusHelper.reset();
    provider.reset(); 
    await provider.fetchAllTvShows();
  }

  FocusNode _getFocusNode(String id) {
    if (!_focusNodes.containsKey(id)) {
      _focusNodes[id] = FocusNode(debugLabel: id);
    }
    return _focusNodes[id]!;
  }

  void _openTvShowDetail(TvShow tvShow) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TvShowDetailScreen(tvShow: tvShow),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Consumer3<TvShowsProvider, SettingsProvider, WatchHistoryProvider>(
        builder: (context, provider, settings, history, _) {
          if (provider.status == TvShowsStatus.loading && provider.trendingTvShows.isEmpty && provider.categories.isEmpty) {
            return LoadingIndicator(message: '${l10n.translate('tv_shows')}...');
          }

          final isMobile = settings.layoutMode == 'mobile';
          final isXtream = settings.isXtreamSource;

          Widget content = CustomScrollView(
            controller: _scrollController,
            physics: isMobile ? const BouncingScrollPhysics() : const ClampingScrollPhysics(),
            slivers: [
              if (!isXtream && provider.trendingTvShows.isNotEmpty)
                SliverToBoxAdapter(
                  child: HeroSlideshow(
                    items: provider.trendingTvShows.take(5).toList(),
                    isMobile: isMobile,
                    onTap: (tv) => _openTvShowDetail(tv),
                  ),
                ),

              SliverPadding(
                padding: EdgeInsets.symmetric(
                  vertical: isMobile ? 20 : 40,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    _buildCategoryRows(
                      provider: provider,
                      settings: settings,
                      isMobile: isMobile,
                      isXtream: isXtream,
                      l10n: l10n,
                      continueWatching: history.continueSeries,
                    ),
                  ),
                ),
              ),
            ],
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

  List<Widget> _buildCategoryRows({
    required TvShowsProvider provider,
    required SettingsProvider settings,
    required bool isMobile,
    required bool isXtream,
    required AppLocalizations l10n,
    required List<WatchHistoryItem> continueWatching,
  }) {
    final configs = isXtream
        ? _xtreamRowConfigs(provider, settings, l10n)
        : _tmdbRowConfigs(provider, settings, l10n);

    if (configs.isEmpty && continueWatching.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              l10n.translate('no_results'),
              style: const TextStyle(color: Colors.white54),
            ),
          ),
        ),
      ];
    }

    final widgets = <Widget>[];
    if (continueWatching.isNotEmpty) {
      widgets.add(ContinueWatchingRow(
        items: continueWatching,
        isMobile: isMobile,
      ));
      widgets.add(const SizedBox(height: 8));
    }
    for (var i = 0; i < configs.length; i++) {
      final config = configs[i];
      widgets.add(
        _buildPremiumRow(
          rowIndex: i,
          rowId: config.rowId,
          title: config.title,
          items: config.items,
          isMobile: isMobile,
          prefix: config.prefix,
          forceKurdish: config.forceKurdish,
          enableTvFocus: !isMobile,
        ),
      );
      widgets.add(const SizedBox(height: 32));
    }
    widgets.add(const SizedBox(height: 100));
    return widgets;
  }

  List<_TvShowRowConfig> _xtreamRowConfigs(
    TvShowsProvider provider,
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
    final orderedCategories = settings.orderedCategoryIds(
      CategoryOrderSection.tvShows,
      provider.categories,
    );
    return orderedCategories
        .map((category) {
          final items = provider.showsInCategory(category);
          if (items.isEmpty) return null;
          return _TvShowRowConfig(
            rowId: 'xtream_$category',
            title: category.toUpperCase(),
            items: items,
            prefix: 'xtream_${category.hashCode}',
          );
        })
        .whereType<_TvShowRowConfig>()
        .toList();
  }

  List<_TvShowRowConfig> _tmdbRowConfigs(
    TvShowsProvider provider,
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
    final configs = <_TvShowRowConfig>[];
    if (provider.kurdishTvShows.isNotEmpty) {
      configs.add(_TvShowRowConfig(
        rowId: 'kurdish',
        title: l10n.translate('kurdish_subtitled').toUpperCase(),
        items: provider.kurdishTvShows,
        prefix: 'kurdish_tv',
        forceKurdish: true,
      ));
    }
    configs.add(_TvShowRowConfig(
      rowId: 'trending',
      title: l10n.translate('trending_tv').toUpperCase(),
      items: provider.trendingTvShows.skip(1).toList(),
      prefix: 'trending',
    ));
    if (provider.animeTvShows.isNotEmpty) {
      configs.add(_TvShowRowConfig(
        rowId: 'anime',
        title: l10n.translate('anime').toUpperCase(),
        items: provider.animeTvShows,
        prefix: 'anime',
      ));
    }
    configs.add(_TvShowRowConfig(
      rowId: 'popular',
      title: '${l10n.translate('tv_shows')} ${l10n.translate('featured')}'.toUpperCase(),
      items: provider.popularTvShows,
      prefix: 'popular',
    ));
    configs.add(_TvShowRowConfig(
      rowId: 'on_the_air',
      title: l10n.translate('watch_now').toUpperCase(),
      items: provider.onTheAirTvShows,
      prefix: 'on_the_air',
    ));
    final filtered = configs.where((c) => c.items.isNotEmpty).toList();
    final orderedIds = settings.orderedCategoryIds(
      CategoryOrderSection.tvShows,
      filtered.map((c) => c.rowId).toList(),
    );
    final byId = {for (final c in filtered) c.rowId: c};
    return orderedIds.map((id) => byId[id]).whereType<_TvShowRowConfig>().toList();
  }

  Widget _buildPremiumRow({
    required int rowIndex,
    required String rowId,
    required String title,
    required List<TvShow> items,
    required bool isMobile,
    required String prefix,
    bool forceKurdish = false,
    bool enableTvFocus = false,
  }) {
    final previewItems = items.take(kCategoryPreviewLimit).toList();
    final hasMore = items.length > kCategoryPreviewLimit;

    void openSeeAll() {
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

    FocusNode? rowFocusAt(int i) {
      if (i < previewItems.length) {
        return _getFocusNode('${prefix}_${previewItems[i].id}');
      }
      if (i == previewItems.length && hasMore) {
        return _getFocusNode('${prefix}_see_all');
      }
      return null;
    }

    Widget buildRowContent(CategoryRowFocusView? focus) {
      final l10n = AppLocalizations.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 60),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.5), blurRadius: 8)],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                if (hasMore && !enableTvFocus) ...[
                  const SizedBox(width: 12),
                  SeeAllHeaderButton(
                    onTap: openSeeAll,
                    label: l10n.translate('see_all'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          MediaRow(
            key: enableTvFocus ? _focusHelper.mediaKeyFor(rowId) : null,
            title: '',
            isLoading: false,
            isDimmed: focus?.isRowDimmed ?? false,
            onSeeMore: hasMore && enableTvFocus ? openSeeAll : null,
            seeAllFocusNode: hasMore && enableTvFocus
                ? _getFocusNode('${prefix}_see_all')
                : null,
            seeAllFocusPrevious: hasMore && enableTvFocus && previewItems.isNotEmpty
                ? rowFocusAt(previewItems.length - 1)
                : null,
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
              final tv = previewItems[index];
              return MediaCard(
                id: '${prefix}_${tv.id}',
                title: tv.name,
                posterUrl: TmdbService.getPosterUrl(tv.posterPath),
                rating: tv.ratingFormatted,
                year: tv.year,
                isMovie: false,
                forceKurdishBadge: forceKurdish,
                focusNode: _getFocusNode('${prefix}_${tv.id}'),
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
                onTap: () => _openTvShowDetail(tv),
              );
            },
          ),
        ],
      );
    }

    if (!enableTvFocus) return buildRowContent(null);

    return KeyedSubtree(
      key: _focusHelper.anchorKeyFor(rowIndex),
      child: CategoryRowFocusScope(
        helper: _focusHelper,
        rowIndex: rowIndex,
        builder: buildRowContent,
      ),
    );
  }
}

class _TvShowRowConfig {
  final String rowId;
  final String title;
  final List<TvShow> items;
  final String prefix;
  final bool forceKurdish;

  const _TvShowRowConfig({
    required this.rowId,
    required this.title,
    required this.items,
    required this.prefix,
    this.forceKurdish = false,
  });
}
