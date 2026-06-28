import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:live_wave/config/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static const String _updateUrl = 'https://raw.githubusercontent.com/SarhadCodes/live_wave_updates/refs/heads/main/version.json';

  static Future<void> checkForUpdate(BuildContext context, {bool showNoUpdate = false}) async {
    try {
      debugPrint('[UpdateService] Manual Check Started');
      final response = await http.get(Uri.parse(_updateUrl)).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String latestVersion = data['version'] ?? '1.0.0';
        final int latestBuild = data['buildNumber'] ?? 0;
        final String apkUrl = data['url'] ?? '';
        final String notes = data['releaseNotes'] ?? 'New version available';

        final PackageInfo packageInfo = await PackageInfo.fromPlatform();
        final int currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

        if (latestBuild > currentBuild) {
          if (context.mounted) {
            showDialog(
              context: context,
              useRootNavigator: true,
              barrierDismissible: false,
              builder: (context) => _UpdateDialog(version: latestVersion, notes: notes, url: apkUrl),
            );
          }
        } else if (showNoUpdate && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('App is up to date'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      debugPrint('[UpdateService] Check error: $e');
    }
  }
}

class _UpdateDialog extends StatefulWidget {
  final String version;
  final String notes;
  final String url;

  const _UpdateDialog({required this.version, required this.notes, required this.url});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double progress = 0;
  bool isDownloading = false;
  bool isFinished = false;
  String status = 'Connecting...';
  String downloadDetails = '';
  String? error;
  String? savedFilePath;

  Future<void> _startDownload() async {
    try {
      setState(() {
        isDownloading = true;
        error = null;
        status = 'Initializing...';
      });

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(widget.url));
      request.headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';
      request.headers['Accept'] = 'application/octet-stream';
      
      final response = await client.send(request).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200 && response.statusCode != 302) {
        setState(() {
          isDownloading = false;
          error = 'Server error: ${response.statusCode}';
        });
        return;
      }

      final contentLength = response.contentLength;
      int downloaded = 0;
      int lastUiUpdate = 0;
      
      final directory = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/update.apk';
      final file = File(filePath);
      
      if (await file.exists()) await file.delete();
      final sink = file.openWrite();

      debugPrint('[UpdateService] Turbo Download Started to: $filePath');
      
      bool downloadCompleted = false;
      final builder = BytesBuilder(copy: false);

      void completeDownload() async {
        if (downloadCompleted) return;
        downloadCompleted = true;
        
        debugPrint('[UpdateService] Stream Forced Done.');
        if (builder.length > 0) {
           sink.add(builder.takeBytes());
        }
        await sink.flush();
        await sink.close();
        client.close();
        
        if (mounted) {
          setState(() {
            progress = 1.0;
            isDownloading = false;
            isFinished = true;
            status = 'Update Ready';
            downloadDetails = '100%';
            savedFilePath = filePath;
          });
          debugPrint('[UpdateService] Triggering Install...');
          await OpenFilex.open(filePath);
        }
      }

      response.stream.listen(
        (List<int> chunk) {
          if (downloadCompleted) return;
          
          downloaded += chunk.length;
          builder.add(chunk);
          
          // Write to disk in 128KB chunks to dramatically reduce I/O overhead
          if (builder.length >= 131072 || (contentLength != null && downloaded >= contentLength)) {
             sink.add(builder.takeBytes());
          }
          
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastUiUpdate > 250 || (contentLength != null && downloaded >= contentLength)) {
            lastUiUpdate = now;
            if (mounted && contentLength != null && contentLength > 0) {
              setState(() {
                progress = downloaded / contentLength;
                downloadDetails = '${(downloaded / (1024 * 1024)).toStringAsFixed(1)} MB / ${(contentLength / (1024 * 1024)).toStringAsFixed(1)} MB';
                status = 'Downloading...';
              });
            }
          }
          
          // FORCE FINISH: GitHub sometimes forgets to close the stream!
          if (contentLength != null && contentLength > 0 && downloaded >= contentLength) {
             completeDownload();
          }
        },
        onDone: () {
          completeDownload();
        },
        onError: (e) {
          if (!downloadCompleted) {
            sink.close();
            client.close();
            if (mounted) {
              setState(() {
                isDownloading = false;
                error = 'Connection lost. Retry?';
              });
            }
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          isDownloading = false;
          error = 'Failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white10)),
      title: Row(
        children: [
          Icon(isFinished ? Icons.check_circle_rounded : Icons.system_update_rounded, 
            color: isFinished ? Colors.green : AppTheme.primaryColor),
          const SizedBox(width: 12),
          Text(isFinished ? 'Update Ready' : 'New Update', 
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isFinished ? 'Installation is ready. Please click install.' : widget.notes, 
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 20),
          if (isDownloading || isFinished) ...[
            LinearProgressIndicator(
              value: progress > 0 ? progress : null,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(isFinished ? Colors.green : AppTheme.primaryColor),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(error ?? status, style: TextStyle(color: error != null ? Colors.redAccent : Colors.white38, fontSize: 11), overflow: TextOverflow.ellipsis)),
                Text(downloadDetails, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ],
        ],
      ),
      actions: [
        if (!isDownloading && !isFinished) ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('LATER', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.black),
            onPressed: _startDownload,
            child: const Text('UPDATE NOW', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ] else if (isFinished) ...[
           ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              debugPrint('[UpdateService] MANUAL INSTALL CLICKED');
              if (savedFilePath != null) {
                 final result = await OpenFilex.open(savedFilePath!);
                 debugPrint('[UpdateService] Install Result: ${result.message}');
                 if (result.type != ResultType.done && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Install error: ${result.message}')),
                    );
                 }
              }
            },
            child: const Text('INSTALL NOW', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
           TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE', style: TextStyle(color: Colors.white38)),
          ),
        ] else if (error != null) ...[
           TextButton(
            onPressed: () async {
              // Failsafe: Download in browser if in-app is failing
              final uri = Uri.parse(widget.url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('OPEN IN BROWSER', style: TextStyle(color: AppTheme.primaryColor)),
          ),
           TextButton(
            onPressed: _startDownload,
            child: const Text('RETRY', style: TextStyle(color: AppTheme.primaryColor)),
          ),
        ],
      ],
    );
  }
}
