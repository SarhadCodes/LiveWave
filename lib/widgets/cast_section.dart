import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/cast_member.dart';
import '../services/tmdb_service.dart';

class CastSection extends StatelessWidget {
  final List<CastMember> cast;
  final bool isLoading;
  final bool isTV;
  final ValueChanged<CastMember> onPersonTap;

  const CastSection({
    super.key,
    required this.cast,
    required this.isLoading,
    required this.isTV,
    required this.onPersonTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
        ),
      );
    }
    if (cast.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final tileWidth = isTV ? 120.0 : 96.0;
    final photoSize = isTV ? 108.0 : 88.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.translate('cast').toUpperCase(),
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: isTV ? 186 : 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cast.length,
            separatorBuilder: (_, __) => SizedBox(width: isTV ? 16 : 12),
            itemBuilder: (context, index) {
              return _CastTile(
                member: cast[index],
                width: tileWidth,
                photoSize: photoSize,
                onTap: () => onPersonTap(cast[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CastTile extends StatelessWidget {
  final CastMember member;
  final double width;
  final double photoSize;
  final VoidCallback onTap;

  const _CastTile({
    required this.member,
    required this.width,
    required this.photoSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final photoUrl = TmdbService.getImageUrl(member.profilePath, size: 'w185');

    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.select)) {
          onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(builder: (context) {
        final isFocused = Focus.of(context).hasFocus;
        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: width,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isFocused ? Colors.white : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                ClipOval(
                  child: SizedBox(
                    width: photoSize,
                    height: photoSize,
                    child: photoUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: photoUrl,
                            fit: BoxFit.cover,
                            width: photoSize,
                            height: photoSize,
                            memCacheWidth: 185,
                            errorWidget: (context, url, error) => _placeholder(),
                          )
                        : _placeholder(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  member.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                if (member.character.isNotEmpty)
                  Text(
                    member.character,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppTheme.surfaceColor,
      child: const Icon(Icons.person_rounded, color: Colors.white38),
    );
  }
}
