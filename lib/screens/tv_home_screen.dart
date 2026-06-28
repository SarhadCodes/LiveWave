import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/channel.dart';
import '../providers/channels_provider.dart';
import '../config/app_theme.dart';
import '../utils/platform_detector.dart';
import '../widgets/channel_card.dart';
import '../widgets/loading_indicator.dart';
import 'player_screen.dart';
import '../l10n/app_localizations.dart';

class TVHomeScreen extends StatefulWidget {
  const TVHomeScreen({super.key});

  @override
  State<TVHomeScreen> createState() => _TVHomeScreenState();
}

class _TVHomeScreenState extends State<TVHomeScreen> {
  final Map<String, FocusNode> _categoryFocusNodes = {};
  final Map<String, Map<String, FocusNode>> _channelFocusNodes = {};
  String? _selectedCategory;
  final ScrollController _sidebarScrollController = ScrollController();
  final Map<String, ScrollController> _rowScrollControllers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChannels();
    });
  }

  @override
  void dispose() {
    for (var node in _categoryFocusNodes.values) {
      node.dispose();
    }
    for (var map in _channelFocusNodes.values) {
      for (var node in map.values) {
        node.dispose();
      }
    }
    _sidebarScrollController.dispose();
    for (var controller in _rowScrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _loadChannels() {
    final provider = Provider.of<ChannelsProvider>(context, listen: false);
    provider.fetchChannels();
  }

  FocusNode _getCategoryFocusNode(String category) {
    if (!_categoryFocusNodes.containsKey(category)) {
      _categoryFocusNodes[category] = FocusNode();
    }
    return _categoryFocusNodes[category]!;
  }

  FocusNode _getChannelFocusNode(String category, String channelId) {
    if (!_channelFocusNodes.containsKey(category)) {
      _channelFocusNodes[category] = {};
    }
    if (!_channelFocusNodes[category]!.containsKey(channelId)) {
      _channelFocusNodes[category]![channelId] = FocusNode();
    }
    return _channelFocusNodes[category]![channelId]!;
  }

  ScrollController _getRowScrollController(String category) {
    if (!_rowScrollControllers.containsKey(category)) {
      _rowScrollControllers[category] = ScrollController();
    }
    return _rowScrollControllers[category]!;
  }

  void _openPlayer(Channel channel, List<Channel> channels, int channelIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          channel: channel,
          allChannels: channels,
          initialChannelIndex: channelIndex,
        ),
      ),
    );
  }

  void _focusFirstChannel(String category, Map<String, List<Channel>> channelsByCategory) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final channelsInCategory = channelsByCategory[category];
      if (channelsInCategory != null && channelsInCategory.isNotEmpty) {
        final firstChannel = channelsInCategory.first;
        _getChannelFocusNode(category, firstChannel.id).requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Consumer<ChannelsProvider>(
        builder: (context, provider, _) {
          if (provider.status == ChannelsStatus.loading) {
            return const LoadingIndicator(message: 'Loading channels...');
          }

          if (provider.status == ChannelsStatus.error) {
            return _buildErrorView(context, provider.errorMessage ?? 'Unknown error');
          }

          if (provider.channels.isEmpty) {
            return _buildEmptyView(context);
          }

          // Group channels by category
          final Map<String, List<Channel>> channelsByCategory = {};
          for (var channel in provider.channels) {
            if (!channelsByCategory.containsKey(channel.category)) {
              channelsByCategory[channel.category] = [];
            }
            channelsByCategory[channel.category]!.add(channel);
          }

          final categories = channelsByCategory.keys.toList()..sort();
          _selectedCategory ??= categories.isNotEmpty ? categories.first : null;

          return Row(
            children: [
              // Sidebar (Right if RTL, Left if LTR)
              _buildSidebar(categories, channelsByCategory),
              
              // Main Content Area
              Expanded(
                child: _buildMainContent(channelsByCategory),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSidebar(List<String> categories, Map<String, List<Channel>> channelsByCategory) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.surfaceColor,
            AppTheme.backgroundColor,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium Header
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingXL),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor.withOpacity(0.15),
                  Colors.transparent,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withOpacity(0.7),
                    ],
                  ).createShader(bounds),
                  child: const Text(
                    'LiveWave',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Premium TV Experience',
                  style: TextStyle(
                    color: AppTheme.textSecondary.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(
            color: AppTheme.textTertiary,
            thickness: 0.5,
            height: 1,
          ),
          
          Expanded(
            child: ListView.builder(
              controller: _sidebarScrollController,
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final channelCount = channelsByCategory[category]?.length ?? 0;
                final isSelected = _selectedCategory == category;
                
                return _buildCategoryItem(
                  category: category,
                  channelCount: channelCount,
                  isSelected: isSelected,
                  focusNode: _getCategoryFocusNode(category),
                  channelsByCategory: channelsByCategory,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem({
    required String category,
    required int channelCount,
    required bool isSelected,
    required FocusNode focusNode,
    required Map<String, List<Channel>> channelsByCategory,
  }) {
    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final isRtl = Directionality.of(context) == TextDirection.rtl;

          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter) {
            setState(() {
              _selectedCategory = category;
            });
            _focusFirstChannel(category, channelsByCategory);
            return KeyEventResult.handled;
          }

          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            if (!isRtl) {
              _focusFirstChannel(category, channelsByCategory);
              return KeyEventResult.handled;
            }
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            if (isRtl) {
              _focusFirstChannel(category, channelsByCategory);
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingM,
              vertical: 6,
            ),
            transform: isFocused ? (Matrix4.identity()..scale(1.05)) : Matrix4.identity(),
            transformAlignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: isFocused
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primaryColor,
                        AppTheme.primaryColor.withOpacity(0.6),
                      ],
                    )
                  : isSelected
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.primaryColor.withOpacity(0.2),
                            AppTheme.primaryColor.withOpacity(0.05),
                          ],
                        )
                      : null,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isFocused
                    ? Colors.white
                    : isSelected
                        ? AppTheme.primaryColor.withOpacity(0.4)
                        : Colors.transparent,
                width: isFocused ? 2.5 : 1,
              ),
              boxShadow: isFocused
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
            ),
            child: InkWell(
              canRequestFocus: false,
              onTap: () {
                setState(() {
                  _selectedCategory = category;
                });
                _focusFirstChannel(category, channelsByCategory);
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingM,
                  vertical: AppTheme.spacingM,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppTheme.getCategoryColor(category),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.getCategoryColor(category).withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category,
                            style: TextStyle(
                              color: isFocused
                                  ? Colors.black
                                  : isSelected
                                      ? AppTheme.textPrimary
                                      : AppTheme.textSecondary,
                              fontSize: 16,
                              fontWeight: isFocused || isSelected ? FontWeight.w800 : FontWeight.w500,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$channelCount ${channelCount == 1 ? 'Channel' : 'Channels'}',
                            style: TextStyle(
                              color: isFocused
                                  ? Colors.black87
                                  : AppTheme.textTertiary.withOpacity(0.8),
                              fontSize: 11,
                              fontWeight: isFocused ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: AppTheme.primaryColor,
                          size: 18,
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

  Widget _buildMainContent(Map<String, List<Channel>> channelsByCategory) {
    if (_selectedCategory == null) return const SizedBox();
    
    final channels = channelsByCategory[_selectedCategory] ?? [];
    
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingXL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _selectedCategory!,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.getCategoryColor(_selectedCategory!).withOpacity(0.25),
                      AppTheme.getCategoryColor(_selectedCategory!).withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.getCategoryColor(_selectedCategory!).withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  '${channels.length} ${channels.length == 1 ? 'Channel' : 'Channels'}',
                  style: TextStyle(
                    color: AppTheme.getCategoryColor(_selectedCategory!),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingXL),
          Expanded(
            child: channels.isEmpty
                ? Center(
                    child: Text(
                      'No channels in this category',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  )
                : GridView.builder(
                    controller: _getRowScrollController(_selectedCategory!),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 9,
                      childAspectRatio: 1.0,
                      crossAxisSpacing: AppTheme.spacingM,
                      mainAxisSpacing: AppTheme.spacingM,
                    ),
                    itemCount: channels.length,
                    itemBuilder: (context, index) {
                      final channel = channels[index];
                      return ChannelCard(
                        channel: channel,
                        onTap: () => _openPlayer(channel, channels, index),
                        isTVMode: true,
                        focusNode: _getChannelFocusNode(_selectedCategory!, channel.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, String message) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.05),
              blurRadius: 40,
              spreadRadius: 10,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/icon.png', width: 120, height: 120),
            const SizedBox(height: 32),
            Text(
              l10n.translate('error_channel'),
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: l10n.locale.languageCode == 'ku' ? 0 : -0.5,
                fontFamily: 'K24Kurdish',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.translate('error_try_again'),
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 16,
                fontFamily: 'K24Kurdish',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _loadChannels,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.translate('retry').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 8,
                shadowColor: AppTheme.primaryColor.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(
            opacity: 0.5,
            child: Image.asset('assets/icon.png', width: 100, height: 100),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.translate('no_results'),
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
