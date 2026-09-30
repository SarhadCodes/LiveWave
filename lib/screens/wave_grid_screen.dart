import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/wave_video.dart';
import '../providers/settings_provider.dart';
import '../providers/wave_provider.dart';
import '../services/youtube_api_service.dart';
import '../widgets/wave_skeleton.dart';
import '../widgets/wave_video_card.dart';
import 'wave_watch_screen.dart';

class WaveGridScreen extends StatefulWidget {
  final String title;
  final WaveFeedKind kind;

  const WaveGridScreen({
    super.key,
    required this.title,
    required this.kind,
  });

  @override
  State<WaveGridScreen> createState() => _WaveGridScreenState();
}

class _WaveGridScreenState extends State<WaveGridScreen> {
  final _scrollController = ScrollController();
  final Map<String, FocusNode> _nodes = {};
  List<WaveVideo> _videos = [];
  String? _nextPageToken;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
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
        _scrollController.position.maxScrollExtent - 500) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await context.read<WaveProvider>().api.categoryFeed(widget.kind);
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
    if (_loadingMore || _nextPageToken == null) return;
    _loadingMore = true;
    try {
      final page = await context.read<WaveProvider>().api.categoryFeed(
            widget.kind,
            pageToken: _nextPageToken,
          );
      if (!mounted) return;
      setState(() {
        _videos = [..._videos, ...page.items];
        _nextPageToken = page.nextPageToken;
      });
    } catch (_) {
      // Keep current page.
    } finally {
      _loadingMore = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile =
        Provider.of<SettingsProvider>(context).layoutMode == 'mobile';
    final pad = isMobile ? AppTheme.spacingM : AppTheme.spacingXXL;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        title: Text(widget.title),
      ),
      body: _loading
          ? WaveHomeSkeleton(isMobile: isMobile)
          : _error != null
              ? WaveErrorBody(message: _error!, onRetry: _load)
              : GridView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(pad, 12, pad, 32),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isMobile ? 1 : 3,
                    childAspectRatio: isMobile ? 1.18 : 1.0,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _videos.length,
                  itemBuilder: (context, index) {
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
                ),
    );
  }
}
