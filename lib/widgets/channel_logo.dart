import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Returns true if [logo] is a base64 data-URI (e.g. "data:image/jpeg;base64,...")
bool isBase64Logo(String logo) {
  return logo.startsWith('data:image');
}

/// Decodes the raw bytes from a data-URI string.
Uint8List decodeBase64Logo(String dataUri) {
  final commaIndex = dataUri.indexOf(',');
  if (commaIndex == -1) return Uint8List(0);
  return base64Decode(dataUri.substring(commaIndex + 1));
}

/// A widget that displays a channel logo, supporting both:
///  • Network URLs (via [CachedNetworkImage])
///  • Base64 data URIs (via [Image.memory])
///
/// Falls back to [fallback] when the logo is empty or fails to load.
class ChannelLogo extends StatelessWidget {
  final String logo;
  final double width;
  final double height;
  final BoxFit fit;
  final Widget? fallback;
  final int? memCacheWidth;

  const ChannelLogo({
    super.key,
    required this.logo,
    this.width = 48,
    this.height = 48,
    this.fit = BoxFit.cover,
    this.fallback,
    this.memCacheWidth,
  });

  Widget get _fallbackWidget =>
      fallback ??
      Container(
        width: width,
        height: height,
        color: Colors.white10,
        child: Icon(Icons.tv_rounded, color: Colors.white24, size: width * 0.5),
      );

  @override
  Widget build(BuildContext context) {
    if (logo.isEmpty) return _fallbackWidget;

    // ── Base64 data URI ──────────────────────────────────────────────────
    if (isBase64Logo(logo)) {
      try {
        final bytes = decodeBase64Logo(logo);
        if (bytes.isEmpty) return _fallbackWidget;
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => _fallbackWidget,
        );
      } catch (_) {
        return _fallbackWidget;
      }
    }

    // ── Network URL ──────────────────────────────────────────────────────
    return CachedNetworkImage(
      imageUrl: logo,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memCacheWidth,
      placeholder: (_, __) => SizedBox(
        width: width,
        height: height,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => _fallbackWidget,
    );
  }
}
