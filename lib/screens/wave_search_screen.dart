import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/wave_creator.dart';
import '../providers/settings_provider.dart';
import '../providers/wave_provider.dart';
import '../services/wave_youtube_parser.dart';
import '../widgets/category_chip.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/wave_skeleton.dart';
import '../widgets/wave_video_card.dart';
import 'wave_creator_screen.dart';
import 'wave_watch_screen.dart';

class WaveSearchScreen extends StatefulWidget {
  const WaveSearchScreen({super.key});

  @override
  State<WaveSearchScreen> createState() => _WaveSearchScreenState();
}

class _WaveSearchScreenState extends State<WaveSearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  final Map<String, FocusNode> _nodes = {};

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQuery);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onQuery);
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    for (final node in _nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 400) {
      context.read<WaveProvider>().loadMoreSearch();
    }
  }

  FocusNode _node(String id) => _nodes.putIfAbsent(id, FocusNode.new);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isMobile =
        Provider.of<SettingsProvider>(context).layoutMode == 'mobile';
    final isRtl = Provider.of<SettingsProvider>(context).isRtl;
    final pad = isMobile ? AppTheme.spacingM : AppTheme.spacingXXL;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        title: Text(l10n.translate('wave_search')),
      ),
      body: Consumer<WaveProvider>(
        builder: (context, wave, _) {
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(pad, 8, pad, 12),
                child: SearchBarWidget(
                  controller: _controller,
                  hintText: l10n.translate('wave_search_hint'),
                  focusNode: _focusNode,
                  isRtl: isRtl,
                  onSearch: () => wave.submitSearch(_controller.text),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: pad),
                child: Row(
                  children: [
                    for (final tab in WaveSearchTab.values) ...[
                      CategoryChip(
                        label: l10n.translate('wave_search_${tab.name}'),
                        isSelected: wave.searchTab == tab,
                        onTap: () => wave.setSearchTab(tab),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(child: _body(wave, l10n, isMobile, pad)),
            ],
          );
        },
      ),
    );
  }

  Widget _body(
    WaveProvider wave,
    AppLocalizations l10n,
    bool isMobile,
    double pad,
  ) {
    if (_controller.text.trim().isEmpty && wave.searchQuery.trim().isEmpty) {
      return Center(
        child: Text(
          l10n.translate('wave_search_empty'),
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    if (wave.searchStatus == WaveLoadStatus.loading &&
        wave.searchVideos.isEmpty &&
        wave.searchCreators.isEmpty) {
      return WaveHomeSkeleton(isMobile: isMobile);
    }

    if (wave.searchStatus == WaveLoadStatus.error &&
        wave.searchVideos.isEmpty &&
        wave.searchCreators.isEmpty) {
      return WaveErrorBody(
        message: waveErrorText(l10n, wave.homeError),
        onRetry: () => wave.submitSearch(_controller.text),
      );
    }

    if (wave.searchTab == WaveSearchTab.creators) {
      if (wave.searchCreators.isEmpty) {
        return Center(
          child: Text(
            l10n.translate('wave_nothing_found'),
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        );
      }
      return ListView.separated(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(pad, 8, pad, 40),
        itemCount: wave.searchCreators.length + (wave.searchLoadingMore ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index >= wave.searchCreators.length) {
            return const WaveSkeletonBox(height: 64);
          }
          final creator = wave.searchCreators[index];
          return _CreatorTile(
            creator: creator,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WaveCreatorScreen(channelId: creator.youtubeChannelId, creator: creator),
                ),
              );
            },
          );
        },
      );
    }

    if (wave.searchVideos.isEmpty) {
      return Center(
        child: Text(
          l10n.translate('wave_nothing_found'),
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    final columns = isMobile ? 1 : 3;
    return GridView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(pad, 8, pad, 40),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: isMobile ? 1.18 : 1.0,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: wave.searchVideos.length,
      itemBuilder: (context, index) {
        final video = wave.searchVideos[index];
        return WaveVideoCard(
          video: video,
          focusNode: _node(video.videoId),
          gridIndex: index,
          gridItemCount: wave.searchVideos.length,
          gridColumnCount: columns,
          focusNodeAtIndex: (i) => _node(wave.searchVideos[i].videoId),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => WaveWatchScreen(video: video)),
            );
          },
        );
      },
    );
  }

  void _onQuery() {
    context.read<WaveProvider>().onSearchQueryChanged(_controller.text);
  }
}

class _CreatorTile extends StatelessWidget {
  final WaveCreator creator;
  final VoidCallback onTap;

  const _CreatorTile({required this.creator, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppTheme.cardColor,
        backgroundImage:
            creator.thumbnailUrl.isEmpty ? null : NetworkImage(creator.thumbnailUrl),
        child: creator.thumbnailUrl.isEmpty
            ? const Icon(Icons.person_rounded, color: AppTheme.textSecondary)
            : null,
      ),
      title: Text(
        creator.title,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        creator.subscriberCount == null
            ? ''
            : '${WaveYoutubeParser.formatViewCount(creator.subscriberCount)} ${AppLocalizations.of(context).translate('wave_followers_meta')}',
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
    );
  }
}
