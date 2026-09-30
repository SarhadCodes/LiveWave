import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/wave_video.dart';
import '../providers/settings_provider.dart';
import '../providers/wave_library_provider.dart';
import '../widgets/category_chip.dart';
import '../widgets/wave_video_card.dart';
import 'wave_creator_screen.dart';
import 'wave_watch_screen.dart';

enum _LibraryTab { history, later, saved, following }

class WaveLibraryScreen extends StatefulWidget {
  const WaveLibraryScreen({super.key});

  @override
  State<WaveLibraryScreen> createState() => _WaveLibraryScreenState();
}

class _WaveLibraryScreenState extends State<WaveLibraryScreen> {
  _LibraryTab _tab = _LibraryTab.later;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isMobile =
        Provider.of<SettingsProvider>(context).layoutMode == 'mobile';
    final pad = isMobile ? AppTheme.spacingM : AppTheme.spacingXXL;
    final library = context.watch<WaveLibraryProvider>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        title: Text(l10n.translate('wave_library')),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: pad),
              children: [
                for (final tab in _LibraryTab.values) ...[
                  CategoryChip(
                    label: l10n.translate('wave_library_${tab.name}'),
                    isSelected: _tab == tab,
                    onTap: () => setState(() => _tab = tab),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(child: _body(library, l10n, isMobile, pad)),
        ],
      ),
    );
  }

  Widget _body(
    WaveLibraryProvider library,
    AppLocalizations l10n,
    bool isMobile,
    double pad,
  ) {
    if (_tab == _LibraryTab.following) {
      if (library.followedCreators.isEmpty) {
        return _empty(l10n.translate('wave_empty_following'));
      }
      return ListView.separated(
        padding: EdgeInsets.fromLTRB(pad, 8, pad, 32),
        itemCount: library.followedCreators.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final creator = library.followedCreators[index];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: AppTheme.cardColor,
              backgroundImage: creator.thumbnailUrl.isEmpty
                  ? null
                  : NetworkImage(creator.thumbnailUrl),
            ),
            title: Text(
              creator.channelTitle,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              l10n.translate('wave_follow_disclaimer'),
              style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WaveCreatorScreen(
                    channelId: creator.youtubeChannelId,
                  ),
                ),
              );
            },
          );
        },
      );
    }

    final videos = switch (_tab) {
      _LibraryTab.history =>
        library.history.map(library.videoFromHistory).toList(),
      _LibraryTab.later =>
        library.watchLater.map(library.videoFromSaved).toList(),
      _LibraryTab.saved =>
        library.savedVideos.map(library.videoFromSaved).toList(),
      _LibraryTab.following => const <WaveVideo>[],
    };

    if (videos.isEmpty) {
      return _empty(l10n.translate('wave_empty_library'));
    }

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(pad, 8, pad, 32),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 1 : 3,
        childAspectRatio: isMobile ? 1.18 : 1.0,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        return WaveVideoCard(
          video: video,
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

  Widget _empty(String message) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppTheme.textSecondary),
      ),
    );
  }
}
