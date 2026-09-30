import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_theme.dart';

/// Bottom padding for WAVE MUSIC lists that draw behind the floating bar.
/// The bar is a 60px pill with 20px of bottom margin. [MediaQuery.viewPadding]
/// is the system gesture inset, which that margin does not include.
/// [MediaQuery.padding] is the scaffold extendBody inset, the larger of the
/// system inset and the bar. The list uses whichever clearance is greater.
double waveMusicListBottomPadding(BuildContext context) {
  const navExtent = 60.0 + 20.0;
  final system = MediaQuery.viewPaddingOf(context).bottom;
  final reported = MediaQuery.paddingOf(context).bottom;
  final combined = navExtent + system;
  final inset = reported > combined ? reported : combined;
  return inset + 12;
}

/// YouTube Music thumbs are often `=w60-h60-…`. Raise that size and keep the
/// rest of the suffix. A brand-new suffix, or `hq720`, is what made every
/// cover fail to load.
String sharpMusicArtworkUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return trimmed;
  final lower = trimmed.toLowerCase();
  if (!lower.contains('googleusercontent.com') && !lower.contains('ggpht.com')) {
    return trimmed;
  }
  return trimmed.replaceFirst(
    RegExp(r'=[swh]\d+(-[swh]\d+)?', caseSensitive: false),
    '=w720-h720',
  );
}

/// Decode size in physical pixels so a cover is not scaled up from a soft bitmap.
int musicArtworkCachePx(BuildContext context, double logicalPx) {
  final px = logicalPx * MediaQuery.devicePixelRatioOf(context);
  if (px < 1) return 1;
  if (px > 1080) return 1080;
  return px.round();
}

class MusicArtwork extends StatelessWidget {
  final String url;
  final double logicalSize;

  const MusicArtwork({super.key, required this.url, required this.logicalSize});

  @override
  Widget build(BuildContext context) {
    final original = url.trim();
    if (original.isEmpty) return const ColoredBox(color: AppTheme.surfaceColor);
    final sharp = sharpMusicArtworkUrl(original);
    final cache = musicArtworkCachePx(context, logicalSize);
    if (sharp == original) return _image(original, cache);
    return _image(
      sharp,
      cache,
      fallback: _image(original, cache),
    );
  }

  Widget _image(String imageUrl, int cache, {Widget? fallback}) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      memCacheWidth: cache,
      errorWidget: (context, _, __) => fallback ?? const ColoredBox(color: AppTheme.surfaceColor),
    );
  }
}

String formatMusicDuration(Duration value) {
  if (value.inMilliseconds <= 0) return '0:00';
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60).toString().padLeft(hours > 0 ? 2 : 1, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) return '$hours:$minutes:$seconds';
  return '$minutes:$seconds';
}

KeyEventResult handleMusicSelect(KeyEvent event, VoidCallback onSelect) {
  if (event is KeyDownEvent &&
      (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.select)) {
    onSelect();
    return KeyEventResult.handled;
  }
  return KeyEventResult.ignored;
}
