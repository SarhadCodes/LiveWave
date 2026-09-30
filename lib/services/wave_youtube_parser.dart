import '../models/wave_creator.dart';
import '../models/wave_video.dart';

/// Pure YouTube Data API v3 parsers. No network.
class WaveYoutubeParser {
  static Duration? parseIso8601Duration(String? iso) {
    if (iso == null || iso.isEmpty || !iso.startsWith('PT')) return null;
    final hours = _unit(iso, 'H');
    final minutes = _unit(iso, 'M');
    final seconds = _unit(iso, 'S');
    if (hours == 0 && minutes == 0 && seconds == 0 && iso == 'PT') return null;
    return Duration(hours: hours, minutes: minutes, seconds: seconds);
  }

  static int _unit(String iso, String unit) {
    final match = RegExp('(\\d+)$unit').firstMatch(iso);
    if (match == null) return 0;
    return int.tryParse(match.group(1) ?? '') ?? 0;
  }

  static String formatDuration(Duration? duration) {
    if (duration == null || duration.inSeconds <= 0) return '';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  static String formatViewCount(int? views) {
    if (views == null) return '';
    if (views < 1000) return '$views';
    if (views < 1000000) {
      final value = views / 1000;
      final text = value >= 10 ? value.round().toString() : value.toStringAsFixed(1);
      return '${text.replaceAll('.0', '')}K';
    }
    if (views < 1000000000) {
      final value = views / 1000000;
      final text = value >= 10 ? value.round().toString() : value.toStringAsFixed(1);
      return '${text.replaceAll('.0', '')}M';
    }
    final value = views / 1000000000;
    return '${value.toStringAsFixed(1).replaceAll('.0', '')}B';
  }

  static String relativePublishedLabel(DateTime? publishedAt, {DateTime? now}) {
    if (publishedAt == null) return '';
    final current = now ?? DateTime.now().toUtc();
    final published = publishedAt.toUtc();
    var delta = current.difference(published);
    if (delta.isNegative) delta = Duration.zero;
    if (delta.inMinutes < 1) return 'just now';
    if (delta.inMinutes < 60) {
      final n = delta.inMinutes;
      return n == 1 ? '1 minute ago' : '$n minutes ago';
    }
    if (delta.inHours < 24) {
      final n = delta.inHours;
      return n == 1 ? '1 hour ago' : '$n hours ago';
    }
    if (delta.inDays < 7) {
      final n = delta.inDays;
      return n == 1 ? '1 day ago' : '$n days ago';
    }
    if (delta.inDays < 30) {
      final n = (delta.inDays / 7).floor();
      return n == 1 ? '1 week ago' : '$n weeks ago';
    }
    if (delta.inDays < 365) {
      final n = (delta.inDays / 30).floor();
      return n == 1 ? '1 month ago' : '$n months ago';
    }
    final n = (delta.inDays / 365).floor();
    return n == 1 ? '1 year ago' : '$n years ago';
  }

  static WaveLiveState liveStateFrom({
    String? liveBroadcastContent,
    Map<String, dynamic>? liveStreamingDetails,
  }) {
    final details = liveStreamingDetails ?? const {};
    final actualEnd = details['actualEndTime'] as String?;
    if (actualEnd != null && actualEnd.isNotEmpty) {
      return WaveLiveState.ended;
    }
    final actualStart = details['actualStartTime'] as String?;
    if (actualStart != null && actualStart.isNotEmpty) {
      return WaveLiveState.live;
    }
    switch (liveBroadcastContent) {
      case 'live':
        return WaveLiveState.live;
      case 'upcoming':
        return WaveLiveState.upcoming;
      case 'completed':
        return WaveLiveState.ended;
      default:
        return WaveLiveState.none;
    }
  }

  static String pickThumbnail(Map<String, dynamic>? thumbnails) {
    if (thumbnails == null || thumbnails.isEmpty) return '';
    for (final key in ['high', 'medium', 'standard', 'maxres', 'default']) {
      final item = thumbnails[key];
      if (item is Map && item['url'] is String) {
        final url = (item['url'] as String).trim();
        if (url.isNotEmpty) return url;
      }
    }
    return '';
  }

  static WaveVideo? videoFromResource(Map<String, dynamic> item) {
    final idValue = item['id'];
    String videoId = '';
    if (idValue is String) {
      videoId = idValue;
    } else if (idValue is Map) {
      videoId = idValue['videoId'] as String? ?? '';
    }
    if (videoId.isEmpty) return null;

    final snippet = item['snippet'] as Map<String, dynamic>? ?? const {};
    final status = item['status'] as Map<String, dynamic>?;
    final embeddable = status == null || status['embeddable'] != false;
    final statistics = item['statistics'] as Map<String, dynamic>?;
    final content = item['contentDetails'] as Map<String, dynamic>?;
    final liveDetails = item['liveStreamingDetails'] as Map<String, dynamic>?;
    final views = int.tryParse('${statistics?['viewCount'] ?? ''}');
    final concurrent = int.tryParse('${liveDetails?['concurrentViewers'] ?? ''}');

    return WaveVideo(
      videoId: videoId,
      title: snippet['title'] as String? ?? '',
      channelId: snippet['channelId'] as String? ?? '',
      channelTitle: snippet['channelTitle'] as String? ?? '',
      thumbnailUrl: pickThumbnail(snippet['thumbnails'] as Map<String, dynamic>?),
      publishedAt: DateTime.tryParse(snippet['publishedAt'] as String? ?? ''),
      duration: parseIso8601Duration(content?['duration'] as String?),
      viewCount: views,
      concurrentViewers: concurrent,
      liveState: liveStateFrom(
        liveBroadcastContent: snippet['liveBroadcastContent'] as String?,
        liveStreamingDetails: liveDetails,
      ),
      embeddable: embeddable,
      description: snippet['description'] as String?,
    );
  }

  static WaveCreator? creatorFromResource(Map<String, dynamic> item) {
    final id = item['id'];
    String channelId = '';
    if (id is String) {
      channelId = id;
    } else if (id is Map) {
      channelId = id['channelId'] as String? ?? '';
    }
    if (channelId.isEmpty) return null;

    final snippet = item['snippet'] as Map<String, dynamic>? ?? const {};
    final statistics = item['statistics'] as Map<String, dynamic>?;
    final content = item['contentDetails'] as Map<String, dynamic>?;
    final related = content?['relatedPlaylists'] as Map<String, dynamic>?;

    return WaveCreator(
      youtubeChannelId: channelId,
      title: snippet['title'] as String? ?? '',
      thumbnailUrl: pickThumbnail(snippet['thumbnails'] as Map<String, dynamic>?),
      description: snippet['description'] as String?,
      subscriberCount: int.tryParse('${statistics?['subscriberCount'] ?? ''}'),
      videoCount: int.tryParse('${statistics?['videoCount'] ?? ''}'),
      uploadsPlaylistId: related?['uploads'] as String?,
    );
  }

  static String? errorReason(Map<String, dynamic>? body) {
    return parseGoogleError(body)?.reason;
  }

  static WaveGoogleError? parseGoogleError(Map<String, dynamic>? body) {
    if (body == null) return null;
    final error = body['error'];
    if (error is! Map) return null;
    final map = Map<String, dynamic>.from(error);
    String? reason;
    final errors = map['errors'];
    if (errors is List && errors.isNotEmpty && errors.first is Map) {
      reason = (errors.first as Map)['reason'] as String?;
    }
    final details = map['details'];
    if ((reason == null || reason.isEmpty) && details is List) {
      for (final detail in details) {
        if (detail is Map && detail['reason'] is String) {
          reason = detail['reason'] as String;
          break;
        }
      }
    }
    reason ??= map['status'] as String?;
    return WaveGoogleError(
      code: map['code'] is num ? (map['code'] as num).toInt() : null,
      reason: reason,
      status: map['status'] as String?,
      message: map['message'] as String?,
    );
  }
}

class WaveGoogleError {
  final int? code;
  final String? reason;
  final String? status;
  final String? message;

  const WaveGoogleError({this.code, this.reason, this.status, this.message});

  String get fingerprint =>
      '${reason ?? ''} ${status ?? ''} ${message ?? ''}'.toLowerCase();

  bool get isQuota =>
      fingerprint.contains('quota') ||
      fingerprint.contains('dailylimit') ||
      status == 'RESOURCE_EXHAUSTED';

  bool get isInvalidKey =>
      reason == 'keyInvalid' ||
      fingerprint.contains('api_key_invalid') ||
      fingerprint.contains('invalid api key');

  bool get isNotEnabled =>
      reason == 'accessNotConfigured' ||
      fingerprint.contains('accessnotconfigured') ||
      fingerprint.contains('has not been used') ||
      fingerprint.contains('is disabled') ||
      fingerprint.contains('service_disabled') ||
      fingerprint.contains('api_key_service_blocked');

  bool get isRestricted =>
      fingerprint.contains('blocked') ||
      fingerprint.contains('iprefererblocked') ||
      fingerprint.contains('api_key_android_app_blocked') ||
      fingerprint.contains('api_key_http_referrer_blocked') ||
      fingerprint.contains('requests from this') ||
      reason == 'forbidden' ||
      status == 'PERMISSION_DENIED';
}

enum WaveApiErrorKind {
  missingApiKey,
  noInternet,
  timeout,
  quotaExceeded,
  restricted,
  notEnabled,
  unavailable,
  embeddingDisabled,
  malformed,
  unknown,
}

class WaveApiException implements Exception {
  final WaveApiErrorKind kind;
  final String message;

  const WaveApiException(this.kind, this.message);

  @override
  String toString() => message;
}
