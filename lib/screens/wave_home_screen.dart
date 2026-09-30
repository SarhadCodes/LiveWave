import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/wave_video.dart';
import '../providers/settings_provider.dart';
import '../providers/wave_library_provider.dart';
import '../providers/wave_provider.dart';
import '../services/youtube_api_service.dart';
import '../widgets/category_chip.dart';
import '../widgets/media_row.dart';
import '../widgets/wave_hero.dart';
import '../widgets/wave_skeleton.dart';
import '../widgets/wave_video_card.dart';
import 'wave_grid_screen.dart';
import 'wave_library_screen.dart';
import 'wave_search_screen.dart';
import 'wave_watch_screen.dart';

class WaveHomeScreen extends StatefulWidget {
  const WaveHomeScreen({super.key});

  @override
  State<WaveHomeScreen> createState() => WaveHomeScreenState();
}

class WaveHomeScreenState extends State<WaveHomeScreen> {
  final _chipNodes = <WaveFeedKind, FocusNode>{};
  final _heroNode = FocusNode(debugLabel: 'wave_hero');
  final _searchNode = FocusNode(debugLabel: 'wave_search');
  final _scrollController = ScrollController();
  final _apiKeyController = TextEditingController();
  final Map<String, FocusNode> _cardNodes = {};

  static const _chips = <WaveFeedKind>[
    WaveFeedKind.forYou,
    WaveFeedKind.trending,
    WaveFeedKind.live,
    WaveFeedKind.music,
    WaveFeedKind.gaming,
    WaveFeedKind.technology,
    WaveFeedKind.podcasts,
    WaveFeedKind.documentaries,
    WaveFeedKind.news,
  ];

  @override
  void initState() {
    super.initState();
    for (final chip in _chips) {
      _chipNodes[chip] = FocusNode(debugLabel: chip.name);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WaveProvider>().loadHomeIfNeeded();
    });
  }

  @override
  void dispose() {
    _heroNode.dispose();
    _searchNode.dispose();
    _scrollController.dispose();
    _apiKeyController.dispose();
    for (final node in _chipNodes.values) {
      node.dispose();
    }
    for (final node in _cardNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void focusPrimary() {
    if (!mounted) return;
    if (_searchNode.canRequestFocus) {
      _searchNode.requestFocus();
      return;
    }
    _chipNodes[WaveFeedKind.forYou]?.requestFocus();
  }

  FocusNode _cardNode(String id) {
    return _cardNodes.putIfAbsent(id, () => FocusNode(debugLabel: id));
  }

  void _openVideo(WaveVideo video) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WaveWatchScreen(video: video)),
    );
  }

  Future<void> _refresh() {
    return context.read<WaveProvider>().refreshHome(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isMobile =
        Provider.of<SettingsProvider>(context).layoutMode == 'mobile';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Consumer2<WaveProvider, WaveLibraryProvider>(
        builder: (context, wave, library, _) {
          if (!wave.hasApiKey && wave.homeStatus != WaveLoadStatus.loading) {
            return _ApiKeySetup(
              controller: _apiKeyController,
              isMobile: isMobile,
              onSave: () => wave.saveApiKeyAndReload(_apiKeyController.text),
            );
          }

          if (wave.homeStatus == WaveLoadStatus.loading &&
              wave.trending.isEmpty &&
              wave.chipVideos.isEmpty) {
            return WaveHomeSkeleton(isMobile: isMobile);
          }

          if (wave.homeStatus == WaveLoadStatus.error &&
              wave.trending.isEmpty &&
              wave.chipVideos.isEmpty) {
            return WaveErrorBody(
              message: waveErrorText(l10n, wave.homeError),
              onRetry: _refresh,
            );
          }

          final content = CustomScrollView(
            controller: _scrollController,
            physics: isMobile
                ? const BouncingScrollPhysics()
                : const ClampingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _header(l10n, isMobile, wave)),
              if (wave.selectedChip == WaveFeedKind.forYou &&
                  wave.heroVideo != null)
                SliverToBoxAdapter(
                  child: WaveHero(
                    video: wave.heroVideo!,
                    isMobile: isMobile,
                    focusNode: _heroNode,
                    onWatch: () => _openVideo(wave.heroVideo!),
                  ),
                ),
              SliverPadding(
                padding: EdgeInsets.only(
                  top: 16,
                  bottom: isMobile ? 100 : 40,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    wave.selectedChip == WaveFeedKind.forYou
                        ? _forYouRows(wave, library, l10n, isMobile)
                        : _chipRows(wave, l10n, isMobile),
                  ),
                ),
              ),
            ],
          );

          if (!isMobile) return content;
          return LiquidPullToRefresh(
            onRefresh: _refresh,
            color: AppTheme.accentRed,
            backgroundColor: AppTheme.backgroundColor,
            showChildOpacityTransition: false,
            child: content,
          );
        },
      ),
    );
  }

  Widget _header(AppLocalizations l10n, bool isMobile, WaveProvider wave) {
    final pad = isMobile ? AppTheme.spacingM : AppTheme.spacingXXL;
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, isMobile ? 12 : 16, pad, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.translate('wave'),
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: isMobile ? 28 : 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.translate('wave_subtitle'),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _HeaderIcon(
                focusNode: _searchNode,
                icon: Icons.search_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WaveSearchScreen()),
                  );
                },
              ),
              const SizedBox(width: 8),
              _HeaderIcon(
                icon: Icons.bookmark_outline_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WaveLibraryScreen()),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _chips.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final chip = _chips[index];
                return CategoryChip(
                  label: l10n.translate('wave_chip_${chip.name}'),
                  isSelected: wave.selectedChip == chip,
                  focusNode: _chipNodes[chip],
                  onTap: () => wave.selectChip(chip),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _forYouRows(
    WaveProvider wave,
    WaveLibraryProvider library,
    AppLocalizations l10n,
    bool isMobile,
  ) {
    final rows = <Widget>[];
    if (wave.trending.isNotEmpty) {
      rows.add(_videoRow(
        title: l10n.translate('wave_trending_now'),
        videos: wave.trending,
        rowId: 'trending',
        isMobile: isMobile,
        onSeeMore: () => _openGrid(
          l10n.translate('wave_trending_now'),
          WaveFeedKind.trending,
        ),
      ));
    }
    if (wave.liveNow.isNotEmpty) {
      rows.add(_videoRow(
        title: l10n.translate('wave_live_now'),
        videos: wave.liveNow,
        rowId: 'live',
        isMobile: isMobile,
        onSeeMore: () => _openGrid(
          l10n.translate('wave_live_now'),
          WaveFeedKind.live,
        ),
      ));
    }
    if (wave.followedVideos.isNotEmpty) {
      rows.add(_videoRow(
        title: l10n.translate('wave_from_followed'),
        videos: wave.followedVideos,
        rowId: 'followed',
        isMobile: isMobile,
      ));
    }
    if (library.continueWatching.isNotEmpty) {
      rows.add(_videoRow(
        title: l10n.translate('continue_watching'),
        videos: library.continueWatching
            .map(library.videoFromHistory)
            .toList(),
        rowId: 'continue',
        isMobile: isMobile,
      ));
    } else if (library.history.isNotEmpty) {
      rows.add(_videoRow(
        title: l10n.translate('wave_recently_watched'),
        videos: library.history.take(12).map(library.videoFromHistory).toList(),
        rowId: 'history',
        isMobile: isMobile,
      ));
    }
    if (library.watchLater.isNotEmpty) {
      rows.add(_videoRow(
        title: l10n.translate('wave_watch_later'),
        videos: library.watchLater.map(library.videoFromSaved).toList(),
        rowId: 'later',
        isMobile: isMobile,
      ));
    }
    if (rows.isEmpty) {
      rows.add(Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          l10n.translate('wave_empty_home'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
      ));
    }
    return rows;
  }

  List<Widget> _chipRows(WaveProvider wave, AppLocalizations l10n, bool isMobile) {
    if (wave.chipVideos.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l10n.translate('wave_empty_home'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      ];
    }
    return [
      _videoRow(
        title: l10n.translate('wave_chip_${wave.selectedChip.name}'),
        videos: wave.chipVideos,
        rowId: 'chip_${wave.selectedChip.name}',
        isMobile: isMobile,
      ),
    ];
  }

  Widget _videoRow({
    required String title,
    required List<WaveVideo> videos,
    required String rowId,
    required bool isMobile,
    VoidCallback? onSeeMore,
  }) {
    if (videos.isEmpty) return const SizedBox.shrink();
    return MediaRow(
      title: title.toUpperCase(),
      itemCount: videos.length,
      customWidth: isMobile ? 220 : 260,
      customHeight: isMobile ? 228 : 258,
      onSeeMore: onSeeMore,
      itemBuilder: (context, index) {
        final video = videos[index];
        return WaveVideoCard(
          video: video,
          focusNode: _cardNode('$rowId-${video.videoId}'),
          focusPrevious: index > 0
              ? _cardNode('$rowId-${videos[index - 1].videoId}')
              : null,
          focusNext: index < videos.length - 1
              ? _cardNode('$rowId-${videos[index + 1].videoId}')
              : null,
          onTap: () => _openVideo(video),
        );
      },
    );
  }

  void _openGrid(String title, WaveFeedKind kind) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WaveGridScreen(title: title, kind: kind),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final FocusNode? focusNode;

  const _HeaderIcon({
    required this.icon,
    required this.onTap,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
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
          final focused = Focus.of(context).hasFocus;
          return GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: focused ? Colors.white.withOpacity(0.12) : AppTheme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: focused ? AppTheme.primaryColor : Colors.white.withOpacity(0.06),
                ),
              ),
              child: Icon(icon, color: AppTheme.textPrimary, size: 20),
            ),
          );
        },
      ),
    );
  }
}

class _ApiKeySetup extends StatelessWidget {
  final TextEditingController controller;
  final bool isMobile;
  final Future<void> Function() onSave;

  const _ApiKeySetup({
    required this.controller,
    required this.isMobile,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pad = isMobile ? AppTheme.spacingM : AppTheme.spacingXXL;
    return ListView(
      padding: EdgeInsets.fromLTRB(pad, 24, pad, 80),
      children: [
        Text(
          l10n.translate('wave'),
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.translate('wave_subtitle'),
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 28),
        Text(
          l10n.translate('wave_api_needed'),
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          l10n.translate('wave_api_needed_body'),
          style: const TextStyle(color: AppTheme.textSecondary, height: 1.45),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: controller,
          obscureText: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: l10n.translate('wave_api_hint'),
            hintStyle: const TextStyle(color: AppTheme.textTertiary),
            filled: true,
            fillColor: AppTheme.cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => onSave(),
          child: Text(l10n.translate('wave_api_save')),
        ),
      ],
    );
  }
}
