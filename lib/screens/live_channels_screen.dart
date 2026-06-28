import 'dart:async';
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
  final Map<String, GlobalKey<MediaRowState>> _rowMediaKeys = {};
  final Map<int, GlobalKey> _rowAnchorKeys = {};
  int? _focusedRowIndex;
  int? _focusedItemIndexInRow;
  final ScrollController _verticalScrollController = ScrollController();

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
    for (var node in _channelFocusNodes.values) {
      node.dispose();
    }
    _verticalScrollController.dispose();
    super.dispose();
  }

  GlobalKey<MediaRowState> _getRowMediaKey(String category) {
    return _rowMediaKeys.putIfAbsent(category, GlobalKey<MediaRowState>.new);
  }

  GlobalKey _getRowAnchorKey(int rowIndex) {
    return _rowAnchorKeys.putIfAbsent(rowIndex, GlobalKey.new);
  }

  void _onChannelFocused({
    required int rowIndex,
    required int itemIndex,
    required String category,
  }) {
    if (_focusedRowIndex == rowIndex && _focusedItemIndexInRow == itemIndex) {
      _rowMediaKeys[category]?.currentState?.scrollToItem(itemIndex);
      return;
    }

    setState(() {
      _focusedRowIndex = rowIndex;
      _focusedItemIndexInRow = itemIndex;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final anchorContext = _rowAnchorKeys[rowIndex]?.currentContext;
      if (anchorContext != null) {
        Scrollable.ensureVisible(
          anchorContext,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          alignment: 0.28,
        );
      }
      _rowMediaKeys[category]?.currentState?.scrollToItem(itemIndex);
    });
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

  void _openPlayer(Channel channel, List<Channel> channels, int index) {
    PlayerLauncher.launch(
      context: context,
      channel: channel,
      allChannels: channels,
      initialChannelIndex: index,
    );
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
          final categories = provider.categories;
          final horizontalPadding = isMobile ? AppTheme.spacingM : AppTheme.spacingXXL;

          Widget content;

          // If a category is selected, show grid view
          if (_selectedCategory != null) {
            final filteredChannels = provider.filterByCategory(_selectedCategory!);
            content = CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: AppTheme.backgroundColor,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => setState(() => _selectedCategory = null),
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
                      maxCrossAxisExtent: isMobile ? 90 : 85,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: isMobile ? 8 : 8,
                      mainAxisSpacing: isMobile ? 8 : 8,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final channel = filteredChannels[index];
                        return _ChannelCardWithLongPress(
                          channel: channel,
                          isFavorite: provider.isFavorite(channel.id),
                          focusNode: _getChannelFocusNode('grid_${channel.id}'),
                          onTap: () => _openPlayer(channel, filteredChannels, index),
                          onLongPress: () => provider.toggleFavorite(channel.id),
                        );
                      },
                      childCount: filteredChannels.length,
                    ),
                  ),
                ),
              ],
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
                      final isRowActive = _focusedRowIndex == null || _focusedRowIndex == index;
                      final cardHeight = isMobile ? 110.0 : 130.0;
                      final cardWidth = isMobile ? 90.0 : 100.0;

                      return KeyedSubtree(
                        key: _getRowAnchorKey(index),
                        child: MediaRow(
                          key: _getRowMediaKey(category),
                          title: _categoryDisplayName(channels, category),
                          isDimmed: !isRowActive,
                          onSeeMore: () => setState(() => _selectedCategory = category),
                          itemCount: channels.length,
                          customHeight: cardHeight,
                          customWidth: cardWidth,
                          itemBuilder: (context, idx) {
                            final channel = channels[idx];
                            final inActiveRow = _focusedRowIndex == index;
                            final isFocusedItem =
                                inActiveRow && _focusedItemIndexInRow == idx;
                            return _ChannelCardWithLongPress(
                              channel: channel,
                              isFavorite: provider.isFavorite(channel.id),
                              focusNode: _getChannelFocusNode('row_${category}_${channel.id}'),
                              dimmed: inActiveRow && !isFocusedItem,
                              onFocusChange: (focused) {
                                if (focused) {
                                  _onChannelFocused(
                                    rowIndex: index,
                                    itemIndex: idx,
                                    category: category,
                                  );
                                }
                              },
                              onTap: () => _openPlayer(channel, channels, idx),
                              onLongPress: () => provider.toggleFavorite(channel.id),
                            );
                          },
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



// ... (Existing code) Use the tool to insert the import at the top, and then replace the class content below

class _ChannelCardWithLongPress extends StatefulWidget {
  final Channel channel;
  final bool isFavorite;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<bool>? onFocusChange;
  final bool dimmed;

  const _ChannelCardWithLongPress({
    required this.channel,
    required this.isFavorite,
    required this.focusNode,
    required this.onTap,
    required this.onLongPress,
    this.onFocusChange,
    this.dimmed = false,
  });

  @override
  State<_ChannelCardWithLongPress> createState() => _ChannelCardWithLongPressState();
}

class _ChannelCardWithLongPressState extends State<_ChannelCardWithLongPress> {
  bool _isLongPressing = false;
  Timer? _longPressTimer;
  bool _longPressTriggered = false;

  void _handleKeyDown() {
    if (_longPressTimer != null) return; // Already handling
    _longPressTriggered = false;
    setState(() => _isLongPressing = true);
    
    _longPressTimer = Timer(const Duration(milliseconds: 600), () {
      // Long press threshold reached - toggle favorite
      _longPressTriggered = true;
      widget.onLongPress();
      setState(() => _isLongPressing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isFavorite 
                  ? '${widget.channel.name} ${AppLocalizations.of(context).translate('removed_from_fav')}'
                  : '${widget.channel.name} ${AppLocalizations.of(context).translate('added_to_fav')}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: widget.isFavorite 
                ? AppTheme.textSecondary 
                : AppTheme.accentRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    });
  }

  void _handleKeyUp() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    setState(() => _isLongPressing = false);
    
    if (!_longPressTriggered) {
      // Short press - open player
      widget.onTap();
    }
    _longPressTriggered = false;
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: widget.onFocusChange,
      onKeyEvent: (node, event) {
        if (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter) {
          if (event is KeyDownEvent) {
            _handleKeyDown();
            return KeyEventResult.handled;
          } else if (event is KeyUpEvent) {
            _handleKeyUp();
            return KeyEventResult.handled;
          } else if (event is KeyRepeatEvent) {
            // Absorb repeat events to prevent multiple triggers
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          return AnimatedOpacity(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            opacity: widget.dimmed ? 0.45 : 1.0,
            child: GestureDetector(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            child: AnimatedScale(
              scale: isFocused ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  boxShadow: _isLongPressing
                      ? [
                          BoxShadow(
                            color: AppTheme.accentRed.withValues(alpha: 0.5),
                            blurRadius: 30,
                            spreadRadius: 4,
                          ),
                        ]
                      : (isFocused
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 30,
                                offset: const Offset(0, 15),
                              ),
                              BoxShadow(
                                color: AppTheme.primaryColor.withValues(alpha: 0.2),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ]
                          : []),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      border: Border.all(
                        color: _isLongPressing
                            ? AppTheme.accentRed
                            : (isFocused 
                                ? AppTheme.focusColor 
                                : AppTheme.textTertiary.withValues(alpha: 0.1)),
                        width: _isLongPressing ? 3 : (isFocused ? 3 : 1),
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Full Background Logo/Image
                        ChannelLogo(
                          logo: widget.channel.logo,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          memCacheWidth: 250,
                          fallback: Container(
                            color: AppTheme.surfaceColor,
                            child: Icon(
                              Icons.tv_rounded,
                              size: 32,
                              color: AppTheme.textTertiary.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
              
                        // Gradient Overlay for readability
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.2),
                                  Colors.black.withValues(alpha: 0.8),
                                ],
                                stops: const [0.0, 0.4, 1.0],
                              ),
                            ),
                          ),
                        ),
                      
                      // Channel Name at Bottom Left
                      Positioned(
                        bottom: 6,
                        left: 6,
                        right: 6,
                        child: Text(
                          widget.channel.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      
                      // Favorite Icon Overlay (Top Right)
                      if (widget.isFavorite)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: AnimatedScale(
                            scale: _isLongPressing ? 1.3 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.favorite_rounded,
                                color: AppTheme.accentRed,
                                size: 12,
                              ),
                            ),
                          ),
                        ),
                      
                      // Long Press Indicator Overlay
                      if (_isLongPressing)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.accentRed.withOpacity(0.1),
                            ),
                          ),
                        ),
                    ],
                  ),
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
