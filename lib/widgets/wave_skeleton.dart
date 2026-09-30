import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../services/wave_youtube_parser.dart';

String waveErrorText(AppLocalizations l10n, WaveApiException? error) {
  switch (error?.kind) {
    case WaveApiErrorKind.restricted:
      return l10n.translate('wave_api_restricted');
    case WaveApiErrorKind.notEnabled:
      return l10n.translate('wave_api_not_enabled');
    case WaveApiErrorKind.quotaExceeded:
      return l10n.translate('wave_quota');
    case WaveApiErrorKind.missingApiKey:
      return l10n.translate('wave_api_invalid');
    case WaveApiErrorKind.noInternet:
    case WaveApiErrorKind.timeout:
      return l10n.translate('wave_connect_error');
    default:
      return error?.message ?? l10n.translate('wave_connect_error');
  }
}

class WaveSkeletonBox extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  const WaveSkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<WaveSkeletonBox> createState() => _WaveSkeletonBoxState();
}

class _WaveSkeletonBoxState extends State<WaveSkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.28, end: 0.62).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: widget.borderRadius ?? BorderRadius.circular(AppTheme.radiusM),
        ),
      ),
    );
  }
}

class WaveHomeSkeleton extends StatelessWidget {
  final bool isMobile;

  const WaveHomeSkeleton({super.key, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final pad = isMobile ? AppTheme.spacingM : AppTheme.spacingXXL;
    return ListView(
      padding: EdgeInsets.fromLTRB(pad, 16, pad, 80),
      children: [
        WaveSkeletonBox(height: isMobile ? 220 : 240),
        const SizedBox(height: 24),
        const WaveSkeletonBox(width: 140, height: 16),
        const SizedBox(height: 16),
        SizedBox(
          height: isMobile ? 190 : 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) => WaveSkeletonBox(
              width: isMobile ? 220 : 260,
              height: isMobile ? 190 : 220,
            ),
          ),
        ),
        const SizedBox(height: 28),
        const WaveSkeletonBox(width: 120, height: 16),
        const SizedBox(height: 16),
        SizedBox(
          height: isMobile ? 190 : 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) => WaveSkeletonBox(
              width: isMobile ? 220 : 260,
              height: isMobile ? 190 : 220,
            ),
          ),
        ),
      ],
    );
  }
}

class WaveErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const WaveErrorBody({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, color: AppTheme.textTertiary, size: 36),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: onRetry,
              child: const Text(
                'Retry',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
