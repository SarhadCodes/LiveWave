import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/wave_music_provider.dart';
import '../widgets/wave_music_track_tile.dart';

class WaveMusicQueueScreen extends StatelessWidget {
  const WaveMusicQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final music = context.watch<WaveMusicProvider>();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Queue'),
        actions: [
          TextButton(
            onPressed: music.queue.isEmpty ? null : music.clearQueue,
            child: const Text('Clear', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
      body: music.queue.isEmpty
          ? const Center(child: Text('Queue is empty', style: TextStyle(color: Colors.white54)))
          : ReorderableListView.builder(
              itemCount: music.queue.length,
              onReorder: (from, to) {
                final dest = to > from ? to - 1 : to;
                music.moveQueueItem(from, dest);
              },
              itemBuilder: (context, index) {
                final track = music.queue[index];
                return Dismissible(
                  key: ValueKey('q_${track.id}_$index'),
                  background: Container(color: AppTheme.accentRed),
                  onDismissed: (_) => music.removeFromQueue(index),
                  child: WaveMusicTrackTile(
                    track: track,
                    index: index + 1,
                    playing: index == music.queueIndex,
                    onTap: () => music.playFromQueue(index),
                    onMore: () => music.removeFromQueue(index),
                  ),
                );
              },
            ),
    );
  }
}
