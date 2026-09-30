import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/wave_music_track.dart';

/// Attribution required by the official SoundCloud API Terms of Use
/// and Buttons & Logos guide for custom players:
/// 1. Credit the uploader as the creator
/// 2. Credit SoundCloud as the source with a logo
/// 3. Link to the SoundCloud permalink_url
class SoundCloudAttribution extends StatelessWidget {
  final WaveMusicTrack track;
  final bool compact;

  const SoundCloudAttribution({
    super.key,
    required this.track,
    this.compact = false,
  });

  static const _logoUrl =
      'https://developers.soundcloud.com/assets/logo_white.png';

  @override
  Widget build(BuildContext context) {
    if (track.provider != 'soundcloud') return const SizedBox.shrink();
    final href = track.permalinkUrl.trim().isNotEmpty
        ? track.permalinkUrl.trim()
        : 'https://soundcloud.com';
    return InkWell(
      onTap: () => _open(href),
      child: Padding(
        padding: EdgeInsets.only(top: compact ? 2 : 6),
        child: Row(
          mainAxisAlignment: compact ? MainAxisAlignment.start : MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            CachedNetworkImage(
              imageUrl: _logoUrl,
              height: compact ? 12 : 14,
              width: compact ? 72 : 84,
              fit: BoxFit.contain,
              errorWidget: (context, url, error) => Text(
                'SoundCloud',
                style: TextStyle(
                  color: const Color(0xFFFAFAFA),
                  fontSize: compact ? 10 : 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Created by ${track.artist}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: compact ? 10 : 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(String href) async {
    final uri = Uri.tryParse(href);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

