import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../widgets/channel_logo.dart';
import '../config/app_theme.dart';
import '../models/channel.dart';
import '../providers/channels_provider.dart';
import '../widgets/category_chip.dart';
import '../widgets/loading_indicator.dart';
import '../services/player_launcher.dart';
import '../providers/settings_provider.dart';
import 'player_screen.dart';

import '../widgets/media_row.dart';
import '../utils/tv_row_focus.dart';
import '../utils/tv_grid_focus.dart';
import '../utils/category_row_focus_helper.dart';
import '../utils/category_order_utils.dart';
import '../widgets/tv_navigation_scope.dart';

import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import '../l10n/app_localizations.dart';

String _categoryDisplayName(List<Channel> channels, String fallback) {
  if (channels.isNotEmpty && channels.first.category.trim().isNotEmpty) {
    return channels.first.category;
  }
  return fallback;
}

class LiveChannelsScreen extends StatefulWidget {
  const LiveChannelsScreen({super.key});

  @override
  State<LiveChannelsScreen> createState() => _LiveChannelsScreenState();
}

class _LiveChannelsScreenState extends State<LiveChannelsScreen> {
  String? _selectedCategory; // null = HOME view (all categories as rows)
  final Map<String, FocusNode> _channelFocusNodes = {};
  final CategoryRowFocusHelper _focusHelper = CategoryRowFocusHelper();
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _gridScrollController = ScrollController();
  final TvGridFocusScheduler _gridFocusScheduler = TvGridFocusScheduler();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ChannelsProvider>(context, listen: false);
      if (provider.status == ChannelsStatus.initial) {
        provider.fetchChannels();
      }
    });
  }

  @override
  void dispose() {
    _focusHelper.dispose();
    for (var node in _channelFocusNodes.values) {
      node.dispose();
    }
    _verticalScrollController.dispose();
    _gridScrollController.dispose();
    _gridFocusScheduler.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    final provider = Provider.of<ChannelsProvider>(context, listen: false);
    await provider.fetchChannels();
  }

  FocusNode _getChannelFocusNode(String id) {
    if (!_channelFocusNodes.containsKey(id)) {
      _channelFocusNodes[id] = FocusNode();
    }
    return _channelFocusNodes[id]!;
  }

  Future<void> _openPlayer(
    Channel channel,
    List<Channel> channels,
    int index, {
    required FocusNode restoreFocusNode,
    int? restoreRowIndex,
    int? restoreItemIndex,
    String? restoreRowId,
    void Function(int gridIndex)? scrollGridToIndex,
    int? gridIndex,
  }) async {
    final isTv =
        Provider.of<SettingsProvider>(context, listen: false).layoutMode == 'tv';

    await PlayerLauncher.launch(
      context: context,
      channel: channel,
      allChannels: channels,
      initialChannelIndex: index,
    );

    if (!mounted || !isTv) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 48), () {
        if (!mounted) return;
        if (restoreRowIndex != null &&
            restoreItemIndex != null &&
            restoreRowId != null) {
          _focusHelper.onItemFocused(
            rowIndex: restoreRowIndex,
            itemIndex: restoreItemIndex,
            rowId: restoreRowId,
          );
        }
        if (scrollGridToIndex != null && gridIndex != null) {
          scrollGridToIndex(gridIndex);
        }
        if (restoreFocusNode.canRequestFocus) {
          restoreFocusNode.requestFocus();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Consumer2<ChannelsProvider, SettingsProvider>(
        builder: (context, provider, settings, _) {
          if (provider.status == ChannelsStatus.loading) {
            return LoadingIndicator(message: '${l10n.translate('live_tv')}...');
          }

          if (provider.status == ChannelsStatus.error) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.accentRed, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      provider.errorMessage ?? l10n.translate('content_source_error'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => provider.fetchChannels(),
                      child: Text(l10n.translate('retry')),
                    ),
                  ],
                ),
              ),
            );
          }

          if (provider.categories.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.live_tv_rounded, color: Colors.white38, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      settings.isXtreamSource
                          ? l10n.translate('xtream_empty')
                          : l10n.translate('no_results'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => provider.fetchChannels(),
                      child: Text(l10n.translate('retry')),
                    ),
                  ],
                ),
              ),
            );
          }

          final isMobile = settings.layoutMode == 'mobile';
          final categories = settings.orderedCategoryIds(
            CategoryOrderSection.liveTv,
            provider.categories,
          );
          final horizontalPadding = isMobile ? AppTheme.spacingM : AppTheme.spacingXXL;

          Widget content;

          // If a category is selected, show grid view
          if (_selectedCategory != null) {
            final filteredChannels = provider.filterByCategory(_selectedCategory!);
            final maxCrossAxisExtent = isMobile ? 160.0 : 180.0;
            final crossAxisSpacing = isMobile ? 10.0 : 12.0;
            final mainAxisSpacing = crossAxisSpacing;

            content = LayoutBuilder(
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
                );
                final headerExtent = kToolbarHeight + horizontalPadding;

                FocusNode gridFocusAt(int i) =>
                    _getChannelFocusNode('grid_${filteredChannels[i].id}');

                void scrollGridToIndex(int index) {
                  scrollCategoryGridToIndex(
                    _gridScrollController,
                    index: index,
                    columnCount: columnCount,
                    rowExtent: rowExtent,
                    headerExtent: headerExtent,
                  );
                }

                return CustomScrollView(
                  controller: _gridScrollController,
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
                          setState(() => _selectedCategory = null);
                        },
                      ),
                      title: Text(
                        _categoryDisplayName(filteredChannels, _selectedCategory!),
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: isMobile ? 20 : 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.all(horizontalPadding),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: maxCrossAxisExtent,
                          childAspectRatio: 1.0,
                          crossAxisSpacing: crossAxisSpacing,
                          mainAxisSpacing: mainAxisSpacing,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final channel = filteredChannels[index];
                            return _FocusableChannelCard(
                              channel: channel,
                              isFavorite: provider.isFavorite(channel.id),
                              focusNode: gridFocusAt(index),
                              gridIndex: index,
                              gridItemCount: filteredChannels.length,
                              gridColumnCount: columnCount,
                              focusNodeAtIndex: gridFocusAt,
                              gridFocusScheduler: _gridFocusScheduler,
                              onPrepareGridTarget: (target, {required vertical}) {
                                if (vertical) scrollGridToIndex(target);
                              },
                              onTap: () => _openPlayer(
                                channel,
                                filteredChannels,
                                index,
                                restoreFocusNode: gridFocusAt(index),
                                gridIndex: index,
                                scrollGridToIndex: scrollGridToIndex,
                              ),
                            );
                          },
                          childCount: filteredChannels.length,
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          } else {
            // Otherwise show Rows View
            content = CustomScrollView(
              controller: _verticalScrollController,
              physics: const ClampingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(height: isMobile ? AppTheme.spacingM : AppTheme.spacingXXL),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final category = categories[index];
                      final channels = provider.filterByCategory(category);
                      final previewChannels = channels.take(kCategoryPreviewLimit).toList();
                      final hasMore = channels.length > kCategoryPreviewLimit;
                      final cardSize = isMobile ? 100.0 : 130.0;
                      final cardHeight = cardSize;
                      final cardWidth = cardSize;

                      FocusNode? rowFocusAt(int i) {
                        if (i < previewChannels.length) {
                          return _getChannelFocusNode(
                              'row_${category}_${previewChannels[i].id}');
                        }
                        if (i == previewChannels.length && hasMore) {
                          return _getChannelFocusNode('row_${category}_see_all');
                        }
                        return null;
                      }

                      return KeyedSubtree(
                        key: _focusHelper.anchorKeyFor(index),
                        child: CategoryRowFocusScope(
                          helper: _focusHelper,
                          rowIndex: index,
                          builder: (focus) => MediaRow(
                            key: _focusHelper.mediaKeyFor(category),
                            title: _categoryDisplayName(channels, category),
                            isDimmed: focus.isRowDimmed,
                            onSeeMore: hasMore
                                ? () {
                                    _gridFocusScheduler.cancel();
                                    setState(() => _selectedCategory = category);
                                  }
                                : null,
                            seeAllFocusNode: hasMore
                                ? _getChannelFocusNode('row_${category}_see_all')
                                : null,
                            seeAllFocusPrevious: hasMore && previewChannels.isNotEmpty
                                ? rowFocusAt(previewChannels.length - 1)
                                : null,
                            onSeeAllFocusChange: hasMore
                                ? (focused) {
                                    if (focused) {
                                      _focusHelper.onItemFocused(
                                        rowIndex: index,
                                        itemIndex: previewChannels.length,
                                        rowId: category,
                                      );
                                    }
                                  }
                                : null,
                            seeAllDimmed: focus.isItemDimmed(previewChannels.length),
                            itemCount: previewChannels.length,
                            customHeight: cardHeight,
                            customWidth: cardWidth,
                            itemBuilder: (context, idx) {
                              final channel = previewChannels[idx];
                              return _FocusableChannelCard(
                                channel: channel,
                                isFavorite: provider.isFavorite(channel.id),
                                focusNode: _getChannelFocusNode('row_${category}_${channel.id}'),
                                focusPrevious: idx > 0 ? rowFocusAt(idx - 1) : null,
                                focusNext: idx < previewChannels.length - 1
                                    ? rowFocusAt(idx + 1)
                                    : (hasMore ? rowFocusAt(previewChannels.length) : null),
                                dimmed: focus.isItemDimmed(idx),
                                onFocusChange: (focused) {
                                  if (focused) {
                                    _focusHelper.onItemFocused(
                                      rowIndex: index,
                                      itemIndex: idx,
                                      rowId: category,
                                    );
                                  }
                                },
                                onTap: () => _openPlayer(
                                  channel,
                                  channels,
                                  channels.indexWhere((c) => c.id == channel.id),
                                  restoreFocusNode:
                                      _getChannelFocusNode('row_${category}_${channel.id}'),
                                  restoreRowIndex: index,
                                  restoreItemIndex: idx,
                                  restoreRowId: category,
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                    childCount: categories.length,
                  ),
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
              ],
            );
          }

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



class _FocusableChannelCard extends StatelessWidget {
  final Channel channel;
  final bool isFavorite;
  final FocusNode focusNode;
  final FocusNode? focusPrevious;
  final FocusNode? focusNext;
  final int? gridIndex;
  final int? gridItemCount;
  final int? gridColumnCount;
  final FocusNode Function(int index)? focusNodeAtIndex;
  final TvGridFocusScheduler? gridFocusScheduler;
  final void Function(int targetIndex, {required bool vertical})? onPrepareGridTarget;
  final VoidCallback onTap;
  final ValueChanged<bool>? onFocusChange;
  final bool dimmed;

  const _FocusableChannelCard({
    required this.channel,
    required this.isFavorite,
    required this.focusNode,
    this.focusPrevious,
    this.focusNext,
    this.gridIndex,
    this.gridItemCount,
    this.gridColumnCount,
    this.focusNodeAtIndex,
    this.gridFocusScheduler,
    this.onPrepareGridTarget,
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

        if (gridIndex != null &&
            gridItemCount != null &&
            gridColumnCount != null &&
            focusNodeAtIndex != null) {
          final gridNav = handleTvGridKeys(
            event,
            index: gridIndex!,
            itemCount: gridItemCount!,
            columnCount: gridColumnCount!,
            focusNodeAt: focusNodeAtIndex!,
            onMoveToSidebar: tvNav?.isTvLayout == true ? tvNav?.focusSidebar : null,
            isRtl: settings.isRtl,
            onPrepareTarget: onPrepareGridTarget,
            scheduler: gridFocusScheduler,
          );
          if (gridNav == KeyEventResult.handled) return gridNav;
        } else {
          final rowNav = handleTvRowHorizontalKeys(
            event,
            focusPrevious: focusPrevious,
            focusNext: focusNext,
            onMoveToSidebar: tvNav?.isTvLayout == true ? tvNav?.focusSidebar : null,
            isRtl: settings.isRtl,
          );
          if (rowNav == KeyEventResult.handled) return rowNav;
        }

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
              child: SizedBox.expand(
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
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
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
                              padding: const EdgeInsets.fromLTRB(8, 16, 8, 7),
                              child: Text(
                                channel.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  height: 1.1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        if (isFavorite)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.favorite_rounded,
                                color: AppTheme.accentRed,
                                size: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
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
