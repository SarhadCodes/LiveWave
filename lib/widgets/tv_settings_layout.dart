import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_theme.dart';

class TvSettingsEntry {
  final String id;
  final String section;
  final String title;
  final String subtitle;
  final IconData icon;

  const TvSettingsEntry({
    required this.id,
    required this.section,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

/// Master-detail settings shell for TV: category list left, options right.
class TvSettingsLayout extends StatefulWidget {
  final String title;
  final List<TvSettingsEntry> entries;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final Widget Function(String selectedId) detailBuilder;
  final Widget? footer;

  final String? initialFocusId;

  const TvSettingsLayout({
    super.key,
    required this.title,
    required this.entries,
    required this.selectedId,
    required this.onSelected,
    required this.detailBuilder,
    this.footer,
    this.initialFocusId,
  });

  @override
  State<TvSettingsLayout> createState() => _TvSettingsLayoutState();
}

class _TvSettingsLayoutState extends State<TvSettingsLayout> {
  final Map<String, FocusNode> _navFocusNodes = {};
  final ScrollController _listScrollController = ScrollController();
  final ScrollController _detailScrollController = ScrollController();
  bool _initialFocusApplied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyInitialFocus());
  }

  @override
  void dispose() {
    _listScrollController.dispose();
    _detailScrollController.dispose();
    for (final node in _navFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  FocusNode _nodeFor(String id) =>
      _navFocusNodes.putIfAbsent(id, () => FocusNode(debugLabel: 'settings_$id'));

  void _focusEntry(int index) {
    if (index < 0 || index >= widget.entries.length) return;
    final entry = widget.entries[index];
    widget.onSelected(entry.id);
    _nodeFor(entry.id).requestFocus();
  }

  void _applyInitialFocus() {
    if (_initialFocusApplied || !mounted || widget.entries.isEmpty) return;
    _initialFocusApplied = true;

    var index = 0;
    final targetId = widget.initialFocusId;
    if (targetId != null) {
      final found = widget.entries.indexWhere((entry) => entry.id == targetId);
      if (found >= 0) index = found;
    }
    _focusEntry(index);
  }

  void _scrollToFocused(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.45,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selectedId;
    TvSettingsEntry? selectedEntry;
    if (selected != null) {
      for (final entry in widget.entries) {
        if (entry.id == selected) {
          selectedEntry = entry;
          break;
        }
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 11,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 28, 20, 8),
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _listScrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 16, 24),
                  itemCount: _listItemCount(),
                  itemBuilder: (context, index) => _buildListItemAt(index),
                ),
              ),
              if (widget.footer != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 16, 20),
                  child: widget.footer!,
                ),
            ],
          ),
        ),
        Container(width: 1, color: Colors.white.withOpacity(0.08)),
        Expanded(
          flex: 13,
          child: selectedEntry == null
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 36, 32, 20),
                      child: Text(
                        selectedEntry.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _detailScrollController,
                        padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                        child: widget.detailBuilder(selectedEntry.id),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  int _listItemCount() {
    var count = 0;
    String? lastSection;
    for (final entry in widget.entries) {
      if (entry.section != lastSection) {
        count += 1;
        lastSection = entry.section;
      }
      count += 1;
    }
    return count;
  }

  Widget _buildListItemAt(int listIndex) {
    var cursor = 0;
    String? lastSection;
    for (var i = 0; i < widget.entries.length; i++) {
      final entry = widget.entries[i];
      if (entry.section != lastSection) {
        if (cursor == listIndex) {
          return Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8, left: 4),
            child: Text(
              entry.section.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
          );
        }
        cursor += 1;
        lastSection = entry.section;
      }
      if (cursor == listIndex) {
        return _TvSettingsNavTile(
          entry: entry,
          isSelected: widget.selectedId == entry.id,
          focusNode: _nodeFor(entry.id),
          onFocus: () => widget.onSelected(entry.id),
          onScrollIntoView: _scrollToFocused,
          onMoveUp: i > 0 ? () => _focusEntry(i - 1) : null,
          onMoveDown:
              i < widget.entries.length - 1 ? () => _focusEntry(i + 1) : null,
        );
      }
      cursor += 1;
    }
    return const SizedBox.shrink();
  }
}

class _TvSettingsNavTile extends StatefulWidget {
  final TvSettingsEntry entry;
  final bool isSelected;
  final FocusNode focusNode;
  final VoidCallback onFocus;
  final void Function(BuildContext context) onScrollIntoView;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const _TvSettingsNavTile({
    required this.entry,
    required this.isSelected,
    required this.focusNode,
    required this.onFocus,
    required this.onScrollIntoView,
    this.onMoveUp,
    this.onMoveDown,
  });

  @override
  State<_TvSettingsNavTile> createState() => _TvSettingsNavTileState();
}

class _TvSettingsNavTileState extends State<_TvSettingsNavTile> {
  final GlobalKey _tileKey = GlobalKey();

  void _handleFocusChange(bool focused) {
    if (!focused) return;
    widget.onFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _tileKey.currentContext;
      if (ctx != null) widget.onScrollIntoView(ctx);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: _tileKey,
      padding: const EdgeInsets.only(bottom: 10),
      child: Focus(
        focusNode: widget.focusNode,
        onFocusChange: _handleFocusChange,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            widget.onMoveUp?.call();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            widget.onMoveDown?.call();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Builder(
          builder: (context) {
            final isFocused = Focus.of(context).hasFocus;
            final highlighted = isFocused || widget.isSelected;
            return GestureDetector(
              onTap: () {
                widget.onFocus();
                widget.focusNode.requestFocus();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isFocused
                      ? Colors.white
                      : (widget.isSelected
                          ? AppTheme.cardColor.withOpacity(0.9)
                          : AppTheme.cardColor.withOpacity(0.55)),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isFocused
                        ? Colors.white
                        : Colors.white.withOpacity(widget.isSelected ? 0.18 : 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.entry.icon,
                      size: 22,
                      color: highlighted
                          ? (isFocused ? Colors.black87 : Colors.white70)
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.entry.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isFocused ? Colors.black : Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.entry.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isFocused
                                  ? Colors.black54
                                  : AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Full-width TV option row (used in the right-hand detail panel).
class TvSettingsDetailOption extends StatefulWidget {
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onSelect;
  final IconData? icon;
  final String? imageAsset;
  final bool autofocus;

  const TvSettingsDetailOption({
    super.key,
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onSelect,
    this.icon,
    this.imageAsset,
    this.autofocus = false,
  });

  @override
  State<TvSettingsDetailOption> createState() => _TvSettingsDetailOptionState();
}

class _TvSettingsDetailOptionState extends State<TvSettingsDetailOption> {
  bool _focused = false;
  final GlobalKey _tileKey = GlobalKey();

  void _handleFocusChange(bool focused) {
    setState(() => _focused = focused);
    if (!focused) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _tileKey.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.45,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isHighlighted = widget.selected || _focused;
    final useLightFill = widget.selected || _focused;
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: _handleFocusChange,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.select)) {
          widget.onSelect();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onSelect,
        child: AnimatedContainer(
          key: _tileKey,
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 64,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: useLightFill
                ? Colors.white
                : AppTheme.cardColor.withOpacity(0.55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHighlighted ? Colors.white : Colors.white.withOpacity(0.08),
              width: _focused && !widget.selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              if (widget.imageAsset != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    widget.imageAsset!,
                    width: 32,
                    height: 22,
                    fit: BoxFit.cover,
                  ),
                )
              else if (widget.icon != null)
                Icon(
                  widget.icon,
                  color: useLightFill ? Colors.black87 : Colors.white70,
                  size: 22,
                ),
              if (widget.imageAsset != null || widget.icon != null)
                const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: useLightFill ? Colors.black : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
                        style: TextStyle(
                          color: useLightFill
                              ? Colors.black54
                              : AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TvSettingsActionButton extends StatefulWidget {
  final String label;
  final String? subtitle;
  final VoidCallback onPressed;
  final IconData icon;
  final bool autofocus;

  const TvSettingsActionButton({
    super.key,
    required this.label,
    this.subtitle,
    required this.onPressed,
    required this.icon,
    this.autofocus = false,
  });

  @override
  State<TvSettingsActionButton> createState() => _TvSettingsActionButtonState();
}

class _TvSettingsActionButtonState extends State<TvSettingsActionButton> {
  bool _focused = false;
  final GlobalKey _tileKey = GlobalKey();

  void _handleFocusChange(bool focused) {
    setState(() => _focused = focused);
    if (!focused) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _tileKey.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.45,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: _handleFocusChange,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.select)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          key: _tileKey,
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: widget.subtitle != null ? 72 : 64,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: _focused
                ? Colors.white
                : AppTheme.cardColor.withOpacity(0.55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _focused ? Colors.white : Colors.white.withOpacity(0.08),
              width: _focused ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                color: _focused ? Colors.black87 : Colors.white70,
                size: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: _focused ? Colors.black : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
                        style: TextStyle(
                          color: _focused
                              ? Colors.black54
                              : AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
