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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isTVMode = false;
  final Map<String, FocusNode> _focusNodes = {};
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _detectPlatform();
      _loadChannels();
    });
  }

  @override
  void dispose() {
    _focusNodes.values.forEach((node) => node.dispose());
    _scrollController.dispose();
    super.dispose();
  }

  void _detectPlatform() {
    setState(() {
      _isTVMode = PlatformDetector.isTV;
    });
  }

  void _loadChannels() {
    final provider = Provider.of<ChannelsProvider>(context, listen: false);
    provider.fetchChannels();
  }

  FocusNode _getFocusNode(String channelId) {
    if (!_focusNodes.containsKey(channelId)) {
      _focusNodes[channelId] = FocusNode();
    }
    return _focusNodes[channelId]!;
  }

  void _openPlayer(Channel channel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerScreen(channel: channel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.textTertiary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.live_tv_rounded,
                color: AppTheme.primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: AppTheme.spacingM),
            const Text(
              'Live Wave',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          Consumer<ChannelsProvider>(
            builder: (context, provider, _) {
              if (provider.categories.length <= 1) return const SizedBox();
              
              return Container(
                margin: const EdgeInsets.only(right: AppTheme.spacingM),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.textTertiary.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: DropdownButton<String>(
                  value: provider.selectedCategory ?? 'All',
                  dropdownColor: AppTheme.cardColor,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.textSecondary, size: 20),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  items: provider.categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    provider.setCategory(value);
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<ChannelsProvider>(
        builder: (context, provider, _) {
          if (provider.status == ChannelsStatus.loading) {
            return const LoadingIndicator(message: 'Loading channels...');
          }

          if (provider.status == ChannelsStatus.error) {
            return _buildErrorView(context, provider.errorMessage ?? 'Unknown error');
          }

          if (provider.filteredChannels.isEmpty) {
            return _buildEmptyView(context);
          }

          return RefreshIndicator(
            onRefresh: () => provider.fetchChannels(),
            color: AppTheme.primaryColor,
            child: _buildChannelGrid(provider.filteredChannels),
          );
        },
      ),
    );
  }

  Widget _buildChannelGrid(List<Channel> channels) {
    final crossAxisCount = _isTVMode ? 6 : 2;
    final childAspectRatio = _isTVMode ? 1.4 : 0.85;
    final spacing = _isTVMode ? AppTheme.spacingL : AppTheme.mobileGridSpacing;

    return GridView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(_isTVMode ? AppTheme.spacingXL : AppTheme.spacingM),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        return ChannelCard(
          channel: channel,
          onTap: () => _openPlayer(channel),
          isTVMode: _isTVMode,
          focusNode: _isTVMode ? _getFocusNode(channel.id) : null,
        );
      },
    );
  }

  Widget _buildErrorView(BuildContext context, String message) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/icon.png', width: 100, height: 100),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              l10n.translate('error_channel'),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontFamily: 'K24Kurdish',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              l10n.translate('error_try_again'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
                fontFamily: 'K24Kurdish',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingL),
            ElevatedButton.icon(
              onPressed: _loadChannels,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.translate('retry').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: AppTheme.backgroundColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingXL,
                  vertical: AppTheme.spacingM,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: 0.5,
              child: Image.asset('assets/icon.png', width: 80, height: 80),
            ),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              l10n.translate('no_results'),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
