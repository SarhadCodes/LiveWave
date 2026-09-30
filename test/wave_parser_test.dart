import 'package:flutter_test/flutter_test.dart';
import 'package:live_wave/models/wave_video.dart';
import 'package:live_wave/services/wave_youtube_parser.dart';

void main() {
  group('WaveYoutubeParser', () {
    test('parses ISO-8601 durations', () {
      expect(WaveYoutubeParser.parseIso8601Duration('PT12M42S'), const Duration(minutes: 12, seconds: 42));
      expect(WaveYoutubeParser.parseIso8601Duration('PT1H2M3S'), const Duration(hours: 1, minutes: 2, seconds: 3));
      expect(WaveYoutubeParser.parseIso8601Duration('PT45S'), const Duration(seconds: 45));
      expect(WaveYoutubeParser.formatDuration(const Duration(minutes: 12, seconds: 42)), '12:42');
      expect(WaveYoutubeParser.formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
    });

    test('formats view counts', () {
      expect(WaveYoutubeParser.formatViewCount(126), '126');
      expect(WaveYoutubeParser.formatViewCount(126000), '126K');
      expect(WaveYoutubeParser.formatViewCount(1200000), '1.2M');
    });

    test('relative dates', () {
      final now = DateTime.utc(2026, 9, 3, 12);
      expect(
        WaveYoutubeParser.relativePublishedLabel(
          DateTime.utc(2026, 9, 1, 12),
          now: now,
        ),
        '2 days ago',
      );
    });

    test('maps live / upcoming / ended from API fields', () {
      expect(
        WaveYoutubeParser.liveStateFrom(liveBroadcastContent: 'live'),
        WaveLiveState.live,
      );
      expect(
        WaveYoutubeParser.liveStateFrom(liveBroadcastContent: 'upcoming'),
        WaveLiveState.upcoming,
      );
      expect(
        WaveYoutubeParser.liveStateFrom(
          liveBroadcastContent: 'live',
          liveStreamingDetails: {'actualEndTime': '2026-01-01T00:00:00Z'},
        ),
        WaveLiveState.ended,
      );
      expect(
        WaveYoutubeParser.liveStateFrom(
          liveBroadcastContent: 'none',
          liveStreamingDetails: {'actualStartTime': '2026-01-01T00:00:00Z'},
        ),
        WaveLiveState.live,
      );
    });

    test('drops videos that cannot be embedded', () {
      final embeddable = WaveYoutubeParser.videoFromResource({
        'id': 'abc',
        'snippet': {
          'title': 'Building My Own Operating System',
          'channelId': 'ch1',
          'channelTitle': 'KurdLogs',
          'publishedAt': '2026-09-01T00:00:00Z',
          'thumbnails': {
            'high': {'url': 'https://i.ytimg.com/vi/abc/hqdefault.jpg'},
          },
          'liveBroadcastContent': 'none',
        },
        'status': {'embeddable': true},
        'contentDetails': {'duration': 'PT12M42S'},
        'statistics': {'viewCount': '126000'},
      });
      expect(embeddable?.embeddable, isTrue);
      expect(embeddable?.title, 'Building My Own Operating System');

      final blocked = WaveYoutubeParser.videoFromResource({
        'id': 'blocked',
        'snippet': {
          'title': 'Private',
          'channelId': 'ch1',
          'channelTitle': 'KurdLogs',
        },
        'status': {'embeddable': false},
      });
      expect(blocked?.embeddable, isFalse);
    });

    test('reads quota error reasons', () {
      expect(
        WaveYoutubeParser.errorReason({
          'error': {
            'errors': [
              {'reason': 'quotaExceeded'}
            ]
          }
        }),
        'quotaExceeded',
      );
    });

    test('detects Android-restricted key blocks', () {
      final error = WaveYoutubeParser.parseGoogleError({
        'error': {
          'code': 403,
          'message': 'Requests from this Android client application <empty> are blocked.',
          'errors': [
            {'reason': 'forbidden'}
          ],
          'status': 'PERMISSION_DENIED',
        }
      });
      expect(error?.isRestricted, isTrue);
    });

    test('detects API not enabled', () {
      final error = WaveYoutubeParser.parseGoogleError({
        'error': {
          'message': 'YouTube Data API v3 has not been used in project 123 before or it is disabled.',
          'status': 'PERMISSION_DENIED',
        }
      });
      expect(error?.isNotEnabled, isTrue);
    });
  });

  test('WaveVideo json roundtrip', () {
    const video = WaveVideo(
      videoId: 'abc',
      title: 'Title',
      channelId: 'ch',
      channelTitle: 'KurdLogs',
      thumbnailUrl: 'https://example.com/t.jpg',
      liveState: WaveLiveState.live,
    );
    final copy = WaveVideo.fromJson(video.toJson());
    expect(copy.videoId, 'abc');
    expect(copy.liveState, WaveLiveState.live);
  });
}
