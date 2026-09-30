import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/wave_creator.dart';
import '../models/wave_video.dart';
import '../providers/settings_provider.dart';
import '../providers/wave_library_provider.dart';
import '../providers/wave_provider.dart';
import '../services/wave_youtube_parser.dart';
import '../widgets/category_chip.dart';
import '../widgets/wave_skeleton.dart';
import '../widgets/wave_video_card.dart';
import 'wave_watch_screen.dart';

enum _CreatorTab { videos, live, popular }

class WaveCreatorScreen extends StatefulWidget {
  final String channelId;
  final WaveCreator? creator;

  const WaveCreatorScreen({
    super.key,
    required this.channelId,
    this.creator,
  });

  @override
  State<WaveCreatorScreen> createState() => _WaveCreatorScreenState();
}

class _WaveCreatorScreenState extends State<WaveCreatorScreen> {
  WaveCreator? _creator;
  _CreatorTab _tab = _CreatorTab.videos;
  List<WaveVideo> _videos = [];
  String? _nextPageToken;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  final _scrollController = ScrollController();
  final Map<String, FocusNode> _nodes = {};

  @override
  void initState() {
    super.initState();
    _creator = widget.creator;
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final node in _nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loadingMore || _nextPageToken == null) {
      return;
    }
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _load({bool reset = true}) async {
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _videos = [];
        _nextPageToken = null;
      }
    });
    try {
      final wave = context.read<WaveProvider>();
      final creator = _creator ?? await wave.loadCreator(widget.channelId);
      if (creator == null) {
        setState(() {
          _error = AppLocalizations.of(context).translate('wave_video_unavailable');
          _loading = false;
        });
        return;
      }
      _creator = creator;
      final page = await _pageForTab(wave, creator);
      if (!mounted) return;
      setState(() {
        _videos = page.items;
        _nextPageToken = page.nextPageToken;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = AppLocalizations.of(context).translate('wave_connect_error');
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final creator = _creator;
    if (creator == null || _loadingMore || _nextPageToken == null) return;
    _loadingMore = true;
    try {
      final page = await _pageForTab(
        context.read<WaveProvider>(),
        creator,
        pageToken: _nextPageToken,
      );
      if (!mounted) return;
      setState(() {
        _videos = [..._videos, ...page.items];
        _nextPageToken = page.nextPageToken;
      });
    } catch (_) {
      // Keep existing videos.
    } finally {
      _loadingMore = false;
    }
  }

  Future<WavePage<WaveVideo>> _pageForTab(
    WaveProvider wave,
    WaveCreator creator, {
    String? pageToken,
  }) {
    switch (_tab) {
      case _CreatorTab.videos:
        return wave.creatorVideos(creator: creator, pageToken: pageToken);
      case _CreatorTab.live:
        return wave.creatorLive(creator, pageToken: pageToken);
      case _CreatorTab.popular:
        return wave.creatorVideos(
          creator: creator,
          pageToken: pageToken,
          order: 'viewCount',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isMobile =
        Provider.of<SettingsProvider>(context).layoutMode == 'mobile';
    final library = context.watch<WaveLibraryProvider>();
    final creator = _creator;
    final pad = isMobile ? AppTheme.spacingM : AppTheme.spacingXXL;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        title: Text(creator?.title ?? l10n.translate('wave')),
      ),
      body: _error != null
          ? WaveErrorBody(message: _error!, onRetry: _load)
          : CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(pad, 16, pad, 8),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 42,
                          backgroundColor: AppTheme.cardColor,
                          backgroundImage: creator?.thumbnailUrl.isNotEmpty == true
                              ? CachedNetworkImageProvider(creator!.thumbnailUrl)
                              : null,
                          child: creator?.thumbnailUrl.isNotEmpty == true
                              ? null
                              : const Icon(Icons.person_rounded, size: 36),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          creator?.title ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (creator?.subscriberCount != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            '${WaveYoutubeParser.formatViewCount(creator!.subscriberCount)} ${l10n.translate('wave_followers_meta')}',
                            style: const TextStyle(color: AppTheme.textSecondary),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          l10n.translate('wave_follow_disclaimer'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (creator != null)
                          ElevatedButton(
                            onPressed: () => library.toggleFollow(creator),
                            child: Text(
                              library.isFollowed(creator.youtubeChannelId)
                                  ? l10n.translate('wave_following')
                                  : l10n.translate('wave_follow'),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            for (final tab in _CreatorTab.values) ...[
                              CategoryChip(
                                label: l10n.translate('wave_creator_${tab.name}'),
                                isSelected: _tab == tab,
                                onTap: () {
                                  if (_tab == tab) return;
                                  setState(() => _tab = tab);
                                  _load();
                                },
                              ),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (_loading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: WaveHomeSkeleton(isMobile: true),
                    ),
                  )
                else if (_videos.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        l10n.translate('wave_empty_home'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(pad, 8, pad, 32),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isMobile ? 1 : 3,
                        childAspectRatio: isMobile ? 1.18 : 1.0,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final video = _videos[index];
                          return WaveVideoCard(
                            video: video,
                            focusNode: _nodes.putIfAbsent(video.videoId, FocusNode.new),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => WaveWatchScreen(video: video),
                                ),
                              );
                            },
                          );
                        },
                        childCount: _videos.length,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
