import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_theme.dart';
import '../l10n/app_localizations.dart';

class SearchBarWidget extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final VoidCallback onSearch;
  final FocusNode? focusNode;
  final VoidCallback? onMoveToResults;
  final VoidCallback? onMoveToSidebar;
  final bool isRtl;

  const SearchBarWidget({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onSearch,
    this.focusNode,
    this.onMoveToResults,
    this.onMoveToSidebar,
    this.isRtl = false,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  bool _isFocused = false;
  late FocusNode _internalFocusNode;
  FocusOnKeyEventCallback? _previousKeyHandler;

  @override
  void initState() {
    super.initState();
    _internalFocusNode = widget.focusNode ?? FocusNode();
    _internalFocusNode.addListener(_onFocusChange);
    _previousKeyHandler = _internalFocusNode.onKeyEvent;
    _internalFocusNode.onKeyEvent = _handleKeyEvent;
  }

  @override
  void dispose() {
    _internalFocusNode.removeListener(_onFocusChange);
    _internalFocusNode.onKeyEvent = _previousKeyHandler;
    if (widget.focusNode == null) {
      _internalFocusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = _internalFocusNode.hasFocus;
      });
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        widget.onMoveToResults?.call();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft && !widget.isRtl) {
        widget.onMoveToSidebar?.call();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowRight && widget.isRtl) {
        widget.onMoveToSidebar?.call();
        return KeyEventResult.handled;
      }
    }
    return _previousKeyHandler?.call(node, event) ?? KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _internalFocusNode.requestFocus();
      },
      child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: _isFocused 
                  ? AppTheme.primaryColor 
                  : AppTheme.textTertiary.withOpacity(0.2),
              width: _isFocused ? 2 : 1,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.25),
                      blurRadius: 12,
                      spreadRadius: 2,
                    )
                  ]
                : [],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _internalFocusNode,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) {
                    widget.onSearch();
                    widget.onMoveToResults?.call();
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4),
                child: ElevatedButton(
                  onPressed: () {
                    widget.onSearch();
                    widget.onMoveToResults?.call();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: AppTheme.backgroundColor,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context).translate('search'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
