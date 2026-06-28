import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/download_service.dart';
import '../services/tmdb_service.dart';
import '../config/app_theme.dart';
import '../l10n/app_localizations.dart';
import 'media_custom_player_screen.dart';
import '../providers/settings_provider.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  void _playDownload(BuildContext context, DownloadItem item) {
    if (item.status != DownloadStatus.completed) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MediaCustomPlayerScreen(
          tmdbId: item.tmdbId,
          isMovie: item.isMovie,
          title: item.title,
          customUrl: 'file://${item.localVideoPath}',
          customSubtitleUrl: item.localSubtitlePath != null ? 'file://${item.localSubtitlePath}' : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isMobile = Provider.of<SettingsProvider>(context).layoutMode == 'mobile';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        title: Text(
          l10n.translate('downloads') ?? 'Downloads',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Consumer<DownloadService>(
        builder: (context, downloadService, child) {
          final downloads = downloadService.allDownloads;

          if (downloads.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download_for_offline_rounded, size: 80, color: Colors.white24),
                  SizedBox(height: 16),
                  Text('No Downloads', style: TextStyle(color: Colors.white54, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isMobile ? 2 : 6,
              childAspectRatio: 0.7,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: downloads.length,
            itemBuilder: (context, index) {
              final item = downloads[index];
              return _buildDownloadCard(context, downloadService, item);
            },
          );
        },
      ),
    );
  }

  Widget _buildDownloadCard(BuildContext context, DownloadService service, DownloadItem item) {
    return Card(
      color: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.white24),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _playDownload(context, item),
        child: Stack(
          children: [
            // Poster
            Positioned.fill(
              child: TmdbService.getPosterUrl(item.posterPath).isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: TmdbService.getPosterUrl(item.posterPath),
                      fit: BoxFit.cover,
                      color: Colors.black.withOpacity(0.4),
                      colorBlendMode: BlendMode.darken,
                    )
                  : Container(color: Colors.black45),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (item.status == DownloadStatus.downloading) ...[
                    LinearProgressIndicator(
                      value: item.progress > 0 ? item.progress : null,
                      color: AppTheme.primaryColor,
                      backgroundColor: Colors.white24,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.totalBytes > 0 
                          ? 'Downloading ${(item.receivedBytes / (1024 * 1024)).toStringAsFixed(1)} MB / ${(item.totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB (${(item.progress * 100).toStringAsFixed(1)}%)'
                          : 'Downloading ${(item.progress * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ] else if (item.status == DownloadStatus.failed) ...[
                    Text('Failed: ${item.error ?? "Unknown error"}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ] else ...[
                    const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 40),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Delete Button
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.delete_rounded, color: Colors.white70),
                onPressed: () => _showDeleteConfirm(context, service, item),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, DownloadService service, DownloadItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete Download?', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to delete "${item.title}"? This cannot be undone.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              service.deleteDownload(item.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
