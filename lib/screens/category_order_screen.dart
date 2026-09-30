import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/channels_provider.dart';
import '../providers/movies_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tv_shows_provider.dart';
import '../utils/category_order_utils.dart';

class CategoryOrderScreen extends StatefulWidget {
  const CategoryOrderScreen({super.key});

  @override
  State<CategoryOrderScreen> createState() => _CategoryOrderScreenState();
}

class _CategoryOrderScreenState extends State<CategoryOrderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<CategoryOrderSection, List<CategoryOrderItem>> _items = {};
  final Map<CategoryOrderSection, List<FocusNode>> _focusNodes = {};
  final Map<CategoryOrderSection, int?> _selectedIndex = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final nodes in _focusNodes.values) {
      for (final node in nodes) {
        node.dispose();
      }
    }
    super.dispose();
  }

  CategoryOrderSection _sectionForIndex(int index) {
    switch (index) {
      case 0:
        return CategoryOrderSection.liveTv;
      case 1:
        return CategoryOrderSection.movies;
      default:
        return CategoryOrderSection.tvShows;
    }
  }

  int? _selectionFor(CategoryOrderSection section) => _selectedIndex[section];

  List<CategoryOrderItem> _defaultLiveItems(ChannelsProvider provider) {
    return provider.categories
        .map((category) {
          final channels = provider.filterByCategory(category);
          final label = channels.isNotEmpty
              ? (channels.first.category.trim().isNotEmpty
                  ? channels.first.category
                  : category)
              : category;
          return CategoryOrderItem(id: category, label: label);
        })
        .toList();
  }

  List<CategoryOrderItem> _defaultMovieItems(
    MoviesProvider provider,
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
    if (settings.isXtreamSource) {
      return provider.categories
          .map((c) => CategoryOrderItem(id: c, label: c))
          .toList();
    }

    final items = <CategoryOrderItem>[];
    if (provider.kurdishMovies.isNotEmpty) {
      items.add(CategoryOrderItem(
        id: 'kurdish',
        label: l10n.translate('kurdish_subtitled'),
      ));
    }
    if (provider.trendingMovies.length > 1) {
      items.add(CategoryOrderItem(
        id: 'trending',
        label: l10n.translate('trending_movies'),
      ));
    }
    if (provider.animeMovies.isNotEmpty) {
      items.add(CategoryOrderItem(
        id: 'anime',
        label: l10n.translate('anime'),
      ));
    }
    if (provider.popularMovies.isNotEmpty) {
      items.add(CategoryOrderItem(
        id: 'popular',
        label: '${l10n.translate('movies')} ${l10n.translate('featured')}',
      ));
    }
    if (provider.nowPlayingMovies.isNotEmpty) {
      items.add(CategoryOrderItem(
        id: 'now_playing',
        label: l10n.translate('watch_now'),
      ));
    }
    return items;
  }

  List<CategoryOrderItem> _defaultTvShowItems(
    TvShowsProvider provider,
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
    if (settings.isXtreamSource) {
      return provider.categories
          .map((c) => CategoryOrderItem(id: c, label: c))
          .toList();
    }

    final items = <CategoryOrderItem>[];
    if (provider.kurdishTvShows.isNotEmpty) {
      items.add(CategoryOrderItem(
        id: 'kurdish',
        label: l10n.translate('kurdish_subtitled'),
      ));
    }
    if (provider.trendingTvShows.length > 1) {
      items.add(CategoryOrderItem(
        id: 'trending',
        label: l10n.translate('trending_tv'),
      ));
    }
    if (provider.animeTvShows.isNotEmpty) {
      items.add(CategoryOrderItem(
        id: 'anime',
        label: l10n.translate('anime'),
      ));
    }
    if (provider.popularTvShows.isNotEmpty) {
      items.add(CategoryOrderItem(
        id: 'popular',
        label: '${l10n.translate('tv_shows')} ${l10n.translate('featured')}',
      ));
    }
    if (provider.onTheAirTvShows.isNotEmpty) {
      items.add(CategoryOrderItem(
        id: 'on_the_air',
        label: l10n.translate('watch_now'),
      ));
    }
    return items;
  }

  List<CategoryOrderItem> _itemsForSection(
    CategoryOrderSection section,
    SettingsProvider settings,
    ChannelsProvider channels,
    MoviesProvider movies,
    TvShowsProvider tvShows,
    AppLocalizations l10n,
  ) {
    if (_items.containsKey(section)) {
      return _items[section]!;
    }

    final defaults = switch (section) {
      CategoryOrderSection.liveTv => _defaultLiveItems(channels),
      CategoryOrderSection.movies => _defaultMovieItems(movies, settings, l10n),
      CategoryOrderSection.tvShows => _defaultTvShowItems(tvShows, settings, l10n),
    };

    return orderItems(defaults, settings.getCategoryOrder(section));
  }

  void _ensureFocusNodes(CategoryOrderSection section, int count) {
    final existing = _focusNodes.putIfAbsent(section, () => []);
    while (existing.length < count) {
      existing.add(FocusNode());
    }
    while (existing.length > count) {
      existing.removeLast().dispose();
    }
  }

  Future<void> _persistSection(
    CategoryOrderSection section,
    List<CategoryOrderItem> items,
  ) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    await settings.setCategoryOrder(
      section,
      items.map((e) => e.id).toList(),
    );
    _items[section] = List<CategoryOrderItem>.from(items);
  }

  void _toggleSelection(CategoryOrderSection section, int index) {
    setState(() {
      if (_selectedIndex[section] == index) {
        _selectedIndex[section] = null;
      } else {
        _selectedIndex[section] = index;
      }
    });
  }

  void _clearSelection(CategoryOrderSection section) {
    if (_selectedIndex[section] == null) return;
    setState(() => _selectedIndex[section] = null);
  }

  void _moveSelected(CategoryOrderSection section, int delta) {
    final selected = _selectedIndex[section];
    if (selected == null) return;

    final items = List<CategoryOrderItem>.from(_items[section] ?? const []);
    final target = selected + delta;
    if (target < 0 || target >= items.length) return;

    final item = items.removeAt(selected);
    items.insert(target, item);
    setState(() {
      _items[section] = items;
      _selectedIndex[section] = target;
    });
    _persistSection(section, items);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNodes[section]?[target].requestFocus();
    });
  }

  Future<void> _resetSection(CategoryOrderSection section) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    await settings.resetCategoryOrder(section);
    setState(() {
      _items.remove(section);
      _selectedIndex[section] = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = Provider.of<SettingsProvider>(context);
    final section = _sectionForIndex(_tabController.index);
    final hasSelection = _selectionFor(section) != null;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.translate('category_order'),
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          onTap: (_) => setState(() {}),
          tabs: [
            Tab(text: l10n.translate('live_tv')),
            Tab(text: l10n.translate('movies')),
            Tab(text: l10n.translate('tv_shows')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _resetSection(section),
            child: Text(
              l10n.translate('reset_order'),
              style: const TextStyle(color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              settings.layoutMode == 'tv' ? AppTheme.spacingXXL : AppTheme.spacingM,
              12,
              settings.layoutMode == 'tv' ? AppTheme.spacingXXL : AppTheme.spacingM,
              8,
            ),
            child: Text(
              hasSelection
                  ? l10n.translate('category_order_selected')
                  : l10n.translate('category_order_hint'),
              style: TextStyle(
                color: hasSelection ? AppTheme.primaryColor : AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSectionList(CategoryOrderSection.liveTv, l10n),
                _buildSectionList(CategoryOrderSection.movies, l10n),
                _buildSectionList(CategoryOrderSection.tvShows, l10n),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionList(
    CategoryOrderSection section,
    AppLocalizations l10n,
  ) {
    final settings = Provider.of<SettingsProvider>(context);
    final channels = Provider.of<ChannelsProvider>(context);
    final movies = Provider.of<MoviesProvider>(context);
    final tvShows = Provider.of<TvShowsProvider>(context);
    final isTv = settings.layoutMode == 'tv';
    final selected = _selectionFor(section);

    final items = _itemsForSection(
      section,
      settings,
      channels,
      movies,
      tvShows,
      l10n,
    );
    _ensureFocusNodes(section, items.length);
    _items[section] = items;

    if (items.isEmpty) {
      return Center(
        child: Text(
          l10n.translate('no_categories_to_order'),
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(isTv ? AppTheme.spacingXXL : AppTheme.spacingM),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = selected == index;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _CategoryOrderTile(
            key: ValueKey('${section.name}_${item.id}'),
            label: item.label,
            index: index,
            total: items.length,
            isSelected: isSelected,
            isMovingMode: selected != null,
            focusNode: _focusNodes[section]![index],
            onSelect: () => _toggleSelection(section, index),
            onMoveUp: isSelected && index > 0
                ? () => _moveSelected(section, -1)
                : null,
            onMoveDown: isSelected && index < items.length - 1
                ? () => _moveSelected(section, 1)
                : null,
            onNavigateUp: selected == null && index > 0
                ? () => _focusNodes[section]![index - 1].requestFocus()
                : null,
            onNavigateDown: selected == null && index < items.length - 1
                ? () => _focusNodes[section]![index + 1].requestFocus()
                : null,
          ),
        );
      },
    );
  }
}

class _CategoryOrderTile extends StatelessWidget {
  final String label;
  final int index;
  final int total;
  final bool isSelected;
  final bool isMovingMode;
  final FocusNode focusNode;
  final VoidCallback onSelect;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onNavigateUp;
  final VoidCallback? onNavigateDown;

  const _CategoryOrderTile({
    super.key,
    required this.label,
    required this.index,
    required this.total,
    required this.isSelected,
    required this.isMovingMode,
    required this.focusNode,
    required this.onSelect,
    this.onMoveUp,
    this.onMoveDown,
    this.onNavigateUp,
    this.onNavigateDown,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyRepeatEvent) return KeyEventResult.handled;
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        if (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter) {
          onSelect();
          return KeyEventResult.handled;
        }

        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          if (isSelected && onMoveUp != null) {
            onMoveUp!();
            return KeyEventResult.handled;
          }
          if (!isMovingMode && onNavigateUp != null) {
            onNavigateUp!();
            return KeyEventResult.handled;
          }
          return KeyEventResult.handled;
        }

        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          if (isSelected && onMoveDown != null) {
            onMoveDown!();
            return KeyEventResult.handled;
          }
          if (!isMovingMode && onNavigateDown != null) {
            onNavigateDown!();
            return KeyEventResult.handled;
          }
          return KeyEventResult.handled;
        }

        if (event.logicalKey == LogicalKeyboardKey.escape ||
            event.logicalKey == LogicalKeyboardKey.goBack) {
          if (isSelected) {
            onSelect();
            return KeyEventResult.handled;
          }
        }

        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final focused = Focus.of(context).hasFocus;
          final borderColor = isSelected
              ? AppTheme.primaryColor
              : (focused ? AppTheme.focusColor : AppTheme.textTertiary.withValues(alpha: 0.2));
          final borderWidth = isSelected || focused ? 2.5 : 1.0;

          return GestureDetector(
            onTap: onSelect,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor.withValues(alpha: 0.15)
                    : AppTheme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: borderWidth),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.35),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: isSelected ? AppTheme.primaryColor : AppTheme.textTertiary.withValues(alpha: 0.5),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                      ),
                    ),
                  ),
                  if (isSelected) ...[
                    IconButton(
                      tooltip: l10n.translate('move_up'),
                      onPressed: onMoveUp,
                      icon: Icon(
                        Icons.keyboard_arrow_up_rounded,
                        color: onMoveUp != null ? AppTheme.primaryColor : Colors.white24,
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.translate('move_down'),
                      onPressed: onMoveDown,
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: onMoveDown != null ? AppTheme.primaryColor : Colors.white24,
                      ),
                    ),
                  ],
                  Text(
                    '${index + 1}/$total',
                    style: TextStyle(
                      color: AppTheme.textTertiary.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
