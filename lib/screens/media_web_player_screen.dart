import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import '../config/app_theme.dart';
import '../providers/settings_provider.dart';

class MediaWebPlayerScreen extends StatefulWidget {
  final int tmdbId;
  final bool isMovie;
  final int? season;
  final int? episode;
  final String title;

  const MediaWebPlayerScreen({
    super.key,
    required this.tmdbId,
    required this.isMovie,
    required this.title,
    this.season,
    this.episode,
  });

  @override
  State<MediaWebPlayerScreen> createState() => _MediaWebPlayerScreenState();
}

class _MediaWebPlayerScreenState extends State<MediaWebPlayerScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String _initialLayoutMode = 'tv';

  @override
  void initState() {
    super.initState();
    
    // Get initial layout mode to restore it later
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _initialLayoutMode = settings.layoutMode;
    
    // Hide system UI (status bars and navigation bars) to make it fully immersive
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    
    // Construct the Vidking embed URL
    final url = widget.isMovie
        ? 'https://www.vidking.net/embed/movie/${widget.tmdbId}?autoPlay=true'
        : 'https://www.vidking.net/embed/tv/${widget.tmdbId}/${widget.season ?? 1}/${widget.episode ?? 1}?autoPlay=true';

    // Force Autoplay Capabilities at a Platform Level
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller = WebViewController.fromPlatformCreationParams(params);

    if (controller.platform is AndroidWebViewController) {
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          // Prevent popups and ad redirects
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('https://www.vidking.net')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(url));

    _controller = controller;

    // Force landscape mode for video playing
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    // Restore orientation based on layout mode
    if (_initialLayoutMode == 'tv') {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
    
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            ),
          
          // Floating subtle back button
          Positioned(
            top: 16,
            left: 16,
            child: SafeArea(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
