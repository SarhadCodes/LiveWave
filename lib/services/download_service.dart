import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:background_downloader/background_downloader.dart';
import '../services/firestore_service.dart';
import '../services/subtitle_service.dart';

enum DownloadStatus { downloading, completed, failed, paused }

class DownloadItem {
  final String id;
  final int tmdbId;
  final bool isMovie;
  final String title;
  final String posterPath;
  final String localVideoPath;
  final String? localSubtitlePath;
  final DownloadStatus status;
  final double progress;
  final int receivedBytes;
  final int totalBytes;
  final String? error;

  DownloadItem({
    required this.id,
    required this.tmdbId,
    required this.isMovie,
    required this.title,
    required this.posterPath,
    required this.localVideoPath,
    this.localSubtitlePath,
    required this.status,
    this.progress = 0.0,
    this.receivedBytes = 0,
    this.totalBytes = -1,
    this.error,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'tmdbId': tmdbId,
        'isMovie': isMovie,
        'title': title,
        'posterPath': posterPath,
        'localVideoPath': localVideoPath,
        'localSubtitlePath': localSubtitlePath,
        'status': status.index,
        'progress': progress,
        'receivedBytes': receivedBytes,
        'totalBytes': totalBytes,
        'error': error,
      };

  factory DownloadItem.fromJson(Map<String, dynamic> json) => DownloadItem(
        id: json['id'],
        tmdbId: json['tmdbId'],
        isMovie: json['isMovie'],
        title: json['title'],
        posterPath: json['posterPath'],
        localVideoPath: json['localVideoPath'],
        localSubtitlePath: json['localSubtitlePath'],
        status: DownloadStatus.values[json['status'] ?? 0],
        progress: (json['progress'] ?? 0.0).toDouble(),
        receivedBytes: json['receivedBytes'] ?? 0,
        totalBytes: json['totalBytes'] ?? -1,
        error: json['error'],
      );

  DownloadItem copyWith({
    String? localVideoPath,
    String? localSubtitlePath,
    DownloadStatus? status,
    double? progress,
    int? receivedBytes,
    int? totalBytes,
    String? error,
  }) {
    return DownloadItem(
      id: id,
      tmdbId: tmdbId,
      isMovie: isMovie,
      title: title,
      posterPath: posterPath,
      localVideoPath: localVideoPath ?? this.localVideoPath,
      localSubtitlePath: localSubtitlePath ?? this.localSubtitlePath,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      error: error ?? this.error,
    );
  }
}

class DownloadService extends ChangeNotifier {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal() {
    _initDownloader();
    _loadDownloads();
  }

  void _initDownloader() {
    FileDownloader().configureNotification(
      running: const TaskNotification('Downloading {displayName}', 'Progress: {progress}'),
      complete: const TaskNotification('Download Complete', '{displayName} is ready to watch offline.'),
      error: const TaskNotification('Download Failed', 'Failed to download {displayName}.'),
      progressBar: true,
    );

    FileDownloader().updates.listen((update) {
      if (update is TaskProgressUpdate) {
        final id = update.task.taskId;
        if (_downloads.containsKey(id)) {
          double p = update.progress;
          if (p < 0) p = 0.0;
          
          int total = update.expectedFileSize;
          int received = _downloads[id]!.receivedBytes;
          
          if (update.hasExpectedFileSize && total > 0) {
            received = (total * p).toInt();
          } else {
             // Fallback for servers without Content-Length
             total = 450 * 1024 * 1024;
             received = (total * p).toInt();
          }
          
          if (p >= 1.0) p = 0.99; // 1.0 set by status update
          
          _downloads[id] = _downloads[id]!.copyWith(
            progress: p,
            receivedBytes: received,
            totalBytes: total,
          );
          notifyListeners();
        }
      } else if (update is TaskStatusUpdate) {
        final id = update.task.taskId;
        if (_downloads.containsKey(id)) {
          if (update.status == TaskStatus.complete) {
            _downloads[id] = _downloads[id]!.copyWith(status: DownloadStatus.completed, progress: 1.0);
            _saveDownloads();
          } else if (update.status == TaskStatus.failed || update.status == TaskStatus.canceled || update.status == TaskStatus.notFound) {
            String errorMsg = 'Download failed';
            if (update.exception != null) {
              errorMsg = update.exception!.description;
              debugPrint('Download failed with exception: ${update.exception!.description}');
            }
            _downloads[id] = _downloads[id]!.copyWith(status: DownloadStatus.failed, error: errorMsg);
            _saveDownloads();
          }
          notifyListeners();
        }
      }
    });
  }

  Map<String, DownloadItem> _downloads = {};
  Map<String, CancelToken> _cancelTokens = {};
  final Dio _dio = Dio();
  final FirestoreService _firestoreService = FirestoreService();

  List<DownloadItem> get allDownloads => _downloads.values.toList();
  
  DownloadItem? getDownload(String id) => _downloads[id];

  Future<void> _loadDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('saved_downloads');
    if (jsonStr != null) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        _downloads = {
          for (var item in decoded)
            item['id']: DownloadItem.fromJson(item)
        };
        // We do not reset downloading state to failed, because background_downloader might still be running!
        // We will sync state by fetching active tasks.
        _syncActiveTasks();
        notifyListeners();
      } catch (e) {
        debugPrint('Error loading downloads: $e');
      }
    }
  }

  Future<void> _syncActiveTasks() async {
    final tasks = await FileDownloader().database.allRecords();
    for (var record in tasks) {
      if (record.status == TaskStatus.running && _downloads.containsKey(record.taskId)) {
        // Task is running
        _downloads[record.taskId] = _downloads[record.taskId]!.copyWith(status: DownloadStatus.downloading);
      } else if ((record.status == TaskStatus.failed || record.status == TaskStatus.canceled) && _downloads.containsKey(record.taskId)) {
        if (_downloads[record.taskId]!.status == DownloadStatus.downloading) {
          _downloads[record.taskId] = _downloads[record.taskId]!.copyWith(status: DownloadStatus.failed, error: 'Interrupted');
        }
      }
    }
    notifyListeners();
  }

  Future<void> _saveDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _downloads.values.map((e) => e.toJson()).toList();
    await prefs.setString('saved_downloads', jsonEncode(jsonList));
  }

  // Returns unique ID for the media (e.g. "movie_123" or "tv_123_s1_e2")
  String generateId(int tmdbId, bool isMovie, {int? season, int? episode}) {
    if (isMovie) return 'movie_$tmdbId';
    return 'tv_${tmdbId}_s${season}_e$episode';
  }

  Future<void> startDownload({
    required int tmdbId,
    required bool isMovie,
    required String title,
    String? seriesTitle,
    int? season,
    int? episode,
    int? releaseYear,
    required String posterPath,
  }) async {
    final id = generateId(tmdbId, isMovie, season: season, episode: episode);
    if (_downloads.containsKey(id) && _downloads[id]!.status == DownloadStatus.downloading) {
      return; // Already downloading
    }

    _downloads[id] = DownloadItem(
      id: id,
      tmdbId: tmdbId,
      isMovie: isMovie,
      title: title,
      posterPath: posterPath,
      localVideoPath: '', // Temporary
      status: DownloadStatus.downloading,
      progress: 0.0, // Indeterminate (Searching links)
    );
    notifyListeners();

    // Step 1: Probe for URLs
    String? videoUrl;
    String? subtitleUrl;

    try {
      // First check Firestore override
      final override = await _firestoreService.getMediaOverride(tmdbId, isMovie: isMovie);
      if (override != null) {
        if (isMovie) {
          videoUrl = override['url'];
          subtitleUrl = override['srtUrl'];
        } else {
          final seasonData = override['s$season'];
          if (seasonData != null && seasonData['e$episode'] != null) {
            videoUrl = seasonData['e$episode']['url'];
            subtitleUrl = seasonData['e$episode']['srtUrl'];
          }
        }
      }

      // If no override, try probing fast servers
      if (videoUrl == null) {
        final result = await _probeServers(
          isMovie: isMovie,
          title: title,
          seriesTitle: seriesTitle,
          season: season,
          episode: episode,
          releaseYear: releaseYear,
        );
        videoUrl = result['video'];
        subtitleUrl = result['subtitle'];
      }

      if (videoUrl == null) {
        throw Exception("No stream available for offline download. Ensure the media has a direct fast stream.");
      }

      SubtitleTrack? selectedSubTrack;

      // If no subtitle was found by _probeServers or overrides, fallback to SubtitleService
      if (subtitleUrl == null || subtitleUrl.isEmpty) {
        try {
          final results = isMovie
              ? await SubtitleService.getMovieSubtitles(tmdbId, title, releaseYear: releaseYear)
              : await SubtitleService.getTvShowSubtitles(tmdbId, seriesTitle ?? title, season: season, episode: episode);
          
          final foundKurdish = results.where((t) => t.language.toLowerCase().contains('kurd')).toList();
          if (foundKurdish.isNotEmpty) {
            selectedSubTrack = foundKurdish.first;
            subtitleUrl = selectedSubTrack.downloadUrl;
          }
        } catch (_) {}
      } else {
         // Create a dummy track for native fast servers
         selectedSubTrack = SubtitleTrack(
            language: 'Kurdish',
            languageId: 'ku',
            fileName: '$id.srt',
            downloadUrl: subtitleUrl,
            format: 'srt'
         );
      }

      // Set up local paths
      final appDir = await getApplicationDocumentsDirectory();
      final targetDir = Directory('${appDir.path}/downloads');
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final videoFile = File('${targetDir.path}/$id.mp4');
      final subtitleFile = subtitleUrl != null && subtitleUrl.isNotEmpty 
          ? File('${targetDir.path}/$id.srt') 
          : null;

      _downloads[id] = _downloads[id]!.copyWith(
        localVideoPath: videoFile.path,
        localSubtitlePath: subtitleFile?.path,
      );
      notifyListeners();

      _cancelTokens[id] = CancelToken();

      // Download Subtitle first (fast)
      if (subtitleFile != null && selectedSubTrack != null && subtitleUrl != null && subtitleUrl.isNotEmpty) {
        try {
          final extractedPath = await SubtitleService.downloadAndExtractSubtitle(selectedSubTrack);
          if (extractedPath != null) {
            final f = File(extractedPath);
            if (await f.exists()) {
              await f.copy(subtitleFile.path);
            }
          }
        } catch (_) {
          // If subtitle fails, continue with video anyway
        }
      }

      // Indicate that probing is done and file transfer is starting
      _downloads[id] = _downloads[id]!.copyWith(progress: 0.01);
      notifyListeners();

      // Download Video (Background)
      final task = DownloadTask(
        taskId: id,
        url: videoUrl,
        filename: '$id.mp4',
        displayName: title,
        baseDirectory: BaseDirectory.applicationDocuments,
        directory: 'downloads',
        updates: Updates.statusAndProgress,
        retries: 3,
      );

      await FileDownloader().enqueue(task);
      // Status will update via FileDownloader().updates.listen
      await _saveDownloads();
      
    } catch (e) {
      _downloads[id] = _downloads[id]!.copyWith(
        status: DownloadStatus.failed,
        error: e.toString(),
      );
      notifyListeners();
    }
  }

  Future<void> cancelDownload(String id) async {
    await FileDownloader().cancelTaskWithId(id);
    if (_downloads.containsKey(id)) {
      _downloads[id] = _downloads[id]!.copyWith(status: DownloadStatus.failed, error: 'Cancelled by user');
      notifyListeners();
      _saveDownloads();
    }
  }

  Future<void> deleteDownload(String id) async {
    final item = _downloads[id];
    if (item != null) {
      if (item.status == DownloadStatus.downloading) {
        cancelDownload(id);
      }
      try {
        final vFile = File(item.localVideoPath);
        if (await vFile.exists()) await vFile.delete();
        
        if (item.localSubtitlePath != null) {
          final sFile = File(item.localSubtitlePath!);
          if (await sFile.exists()) await sFile.delete();
        }
      } catch (e) {
        debugPrint('Error deleting file: $e');
      }
      _downloads.remove(id);
      notifyListeners();
      await _saveDownloads();
    }
  }

  Future<Map<String, String?>> _probeServers({
    required bool isMovie,
    required String title,
    String? seriesTitle,
    int? season,
    int? episode,
    int? releaseYear,
  }) async {
    final baseServers = [
      '154.48.204.98/Flussonic251',
      '130.193.165.194/Flussonic247',
      '130.193.166.197/nasstore',
      '130.193.166.118/sss'
    ];

    final rawTitle = (isMovie ? title : (seriesTitle ?? title));
    final variations = <String>{
      rawTitle.trim(),
      rawTitle.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim()
    };
    
    final cleanAlpha = variations.last;
    if (cleanAlpha.isNotEmpty) {
      variations.add(cleanAlpha.replaceAll(' ', ''));
      variations.add(cleanAlpha.replaceAll(' ', '.'));
      variations.add(cleanAlpha.replaceAll(' ', '-'));
      variations.add(cleanAlpha.replaceAll(' ', '_'));
      variations.add(cleanAlpha.split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1).toLowerCase() : '').join(''));
      
      if (releaseYear != null) {
        variations.add('$cleanAlpha $releaseYear');
        variations.add('$cleanAlpha.$releaseYear');
        variations.add('${cleanAlpha.replaceAll(' ', '.')}.$releaseYear');
      }
    }
    
    final uniqueVariations = variations.expand((v) => [v, v.toLowerCase(), v.toUpperCase()]).toSet().toList();

    List<String> videoUrlsToTry = [];
    for (var host in baseServers) {
      for (var titleVar in uniqueVariations) {
        if (isMovie) {
          final year = releaseYear ?? 2025;
          for (var y in [year, year - 1, year + 1]) {
            videoUrlsToTry.add('http://$host/EnglishMovies1/$y/$titleVar-NoSub.mp4');
            videoUrlsToTry.add('http://$host/EnglishMovies/$y/$titleVar-NoSub.mp4');
          }
          videoUrlsToTry.add('http://$host/EnglishMovies1/OTHER/$titleVar-NoSub.mp4');
          videoUrlsToTry.add('http://$host/EnglishMovies/OTHER/$titleVar-NoSub.mp4');
        } else {
          final s = season.toString().padLeft(2, '0');
          final e = episode.toString().padLeft(2, '0');
          videoUrlsToTry.add('http://$host/EnglishTvSeries1/$titleVar-S${s}E$e.mp4');
          videoUrlsToTry.add('http://$host/EnglishTvSeries/$titleVar-S${s}E$e.mp4');
          videoUrlsToTry.add('http://$host/EnglishTvSeries1/$titleVar.S${s}E$e.mp4');
          videoUrlsToTry.add('http://$host/EnglishTvSeries/$titleVar.S${s}E$e.mp4');
        }
      }
    }

    String? foundVideoUrl;
    const batchSize = 25;
    
    for (int i = 0; i < videoUrlsToTry.length; i += batchSize) {
      if (foundVideoUrl != null) break;
      final chunk = videoUrlsToTry.sublist(i, (i + batchSize > videoUrlsToTry.length) ? videoUrlsToTry.length : i + batchSize);
      
      final chunkResults = await Future.wait(chunk.map((url) async {
        try {
          final res = await http.head(Uri.parse(url)).timeout(const Duration(seconds: 2));
          if (res.statusCode == 200) return url;
        } catch (_) {}
        return null;
      }));
      foundVideoUrl = chunkResults.firstWhere((r) => r != null, orElse: () => null);
    }

    if (foundVideoUrl != null) {
      String? foundSubtitleUrl;
      final uri = Uri.parse(foundVideoUrl);
      final String fullBaseUrl = "${uri.scheme}://${uri.host}${uri.path.split('/English')[0]}";
      final vName = uri.pathSegments.last.replaceAll('.mp4', '');
      final String currentFolderUrl = foundVideoUrl.substring(0, foundVideoUrl.lastIndexOf('/') + 1);
      
      List<String> subUrlsToTry = [
        '${currentFolderUrl}${vName}.srt',
        '${currentFolderUrl}${vName}.mp4.srt'
      ];
      
      if (isMovie) {
        final titleVar = vName.replaceAll('-NoSub', '');
        final year = releaseYear ?? 2025;
        subUrlsToTry.addAll([
          '$fullBaseUrl/EnglishMovies-Subtitle/Ku/$year/$titleVar-Ku.srt',
          '$fullBaseUrl/EnglishMovies-Subtitle/Ku/$year/$titleVar.srt',
          '$fullBaseUrl/EnglishMovies-Subtitle/Ku/OTHER/$titleVar-Ku.srt',
          '$fullBaseUrl/EnglishMovies1/$year/$titleVar.srt',
          '$fullBaseUrl/EnglishMovies1/OTHER/$titleVar.srt',
        ]);
      } else {
        final s = season.toString().padLeft(2, '0');
        final e = episode.toString().padLeft(2, '0');
        for (var tVar in uniqueVariations) {
          subUrlsToTry.addAll([
            '$fullBaseUrl/EnglishTvSeries-Subtitle/Ku/$tVar-Ku-S${s}E$e.srt',
            '$fullBaseUrl/EnglishTvSeries-Subtitle/Ku/$tVar-S${s}E$e.srt',
            '$fullBaseUrl/EnglishTvSeries1/$tVar-S${s}E$e.srt',
            '$fullBaseUrl/EnglishTvSeries1/$tVar.S${s}E$e.srt',
            '$fullBaseUrl/EnglishTvSeries/$tVar.S${s}E$e.srt',
            '$fullBaseUrl/EnglishTvSeries/$tVar-S${s}E$e.srt',
          ]);
        }
      }

      // Run subtitle searches in parallel batches
      for (int i = 0; i < subUrlsToTry.length; i += batchSize) {
        if (foundSubtitleUrl != null) break;
        final chunk = subUrlsToTry.sublist(i, (i + batchSize > subUrlsToTry.length) ? subUrlsToTry.length : i + batchSize);
        
        final chunkResults = await Future.wait(chunk.map((url) async {
          try {
            final res = await http.get(
              Uri.parse('$url?t=${DateTime.now().millisecondsSinceEpoch}'), 
              headers: {'Range': 'bytes=0-1024'}
            ).timeout(const Duration(seconds: 2));
            if (res.statusCode == 200 || res.statusCode == 206) return url;
          } catch (_) {}
          return null;
        }));
        foundSubtitleUrl = chunkResults.firstWhere((r) => r != null, orElse: () => null);
      }
      return {'video': foundVideoUrl, 'subtitle': foundSubtitleUrl};
    }
    return {'video': null, 'subtitle': null};
  }
}
