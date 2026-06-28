package com.livewave.kurdlogs.live_wave

import android.content.Context
import android.view.View
import android.util.Log
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.common.VideoSize
import androidx.media3.extractor.DefaultExtractorsFactory
import androidx.media3.extractor.ts.DefaultTsPayloadReaderFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.common.StandardMessageCodec

class MainActivity: FlutterActivity() {
    private val TAG = "MainActivity"

    private fun getMacAddress(): String {
        try {
            val preferred = listOf("eth0", "wlan0", "en0", "en1")
            val interfaces = java.net.NetworkInterface.getNetworkInterfaces()
            var fallback: String? = null

            while (interfaces.hasMoreElements()) {
                val nif = interfaces.nextElement()
                if (nif.isLoopback) continue
                val mac = nif.hardwareAddress ?: continue
                if (mac.isEmpty()) continue

                val formatted = mac.joinToString(":") { byte ->
                    String.format("%02X", byte)
                }

                // Android 10+ often returns a randomized/local MAC — skip it
                if (formatted == "02:00:00:00:00:00" ||
                    formatted.startsWith("02:00:00")) {
                    continue
                }

                if (preferred.contains(nif.name.lowercase())) {
                    Log.d(TAG, "MAC from ${nif.name}: $formatted")
                    return formatted
                }
                if (fallback == null) fallback = formatted
            }

            if (fallback != null && !fallback.startsWith("02:00:00")) {
                Log.d(TAG, "MAC fallback: $fallback")
                return fallback
            }

            val androidId = android.provider.Settings.Secure.getString(
                contentResolver,
                android.provider.Settings.Secure.ANDROID_ID
            )
            Log.d(TAG, "Using Android ID: $androidId")
            return androidId ?: "unknown"
        } catch (e: Exception) {
            Log.e(TAG, "getMacAddress failed: ${e.message}")
            return "unknown"
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.d(TAG, "Configuring Flutter Engine")

        val utilsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.livewave.player/utils")
        utilsChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getCookies" -> {
                    val url = call.argument<String>("url")
                    val cookieManager = android.webkit.CookieManager.getInstance()
                    val cookies = cookieManager.getCookie(url)
                    Log.d(TAG, "Native getCookies for $url: $cookies")
                    result.success(cookies)
                }
                "getMacAddress" -> {
                    result.success(getMacAddress())
                }
                else -> result.notImplemented()
            }
        }

        flutterEngine.platformViewsController.registry.registerViewFactory(
            "exoplayer-view", 
            ExoPlayerViewFactory(flutterEngine)
        )
    }
}

class ExoPlayerViewFactory(private val engine: FlutterEngine) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<String?, Any?>?
        return ExoPlayerView(context, engine, viewId, params)
    }
}

class ExoPlayerView(context: Context, engine: FlutterEngine, id: Int, params: Map<String?, Any?>?) : PlatformView {
    private val TAG = "ExoPlayerView_$id"
    private val containerView: android.widget.FrameLayout = android.widget.FrameLayout(context)
    private var player: ExoPlayer
    private val channel: MethodChannel = MethodChannel(engine.dartExecutor.binaryMessenger, "com.livewave.player/exoplayer_$id")
    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())
    
    private val statusUpdater = object : Runnable {
        override fun run() {
            if (player.isPlaying || player.playbackState == Player.STATE_BUFFERING) {
                sendUpdate()
            }
            mainHandler.postDelayed(this, 1000)
        }
    }

    init {
        Log.d(TAG, "Initializing Native ExoPlayer View with params: $params")
        
        val decoderMode = params?.get("decoderMode") as? String ?: "hardware"
        val surfaceType = params?.get("surfaceType") as? String ?: "surface"
        
        // FFmpeg ON: fixes IPTV audio-only (MPEG-2 / broken HW decoders on TV boxes)
        val renderersFactory = androidx.media3.exoplayer.DefaultRenderersFactory(context)
            .setExtensionRendererMode(
                if (decoderMode == "software") {
                    androidx.media3.exoplayer.DefaultRenderersFactory.EXTENSION_RENDERER_MODE_ON
                } else {
                    androidx.media3.exoplayer.DefaultRenderersFactory.EXTENSION_RENDERER_MODE_ON
                }
            )
            .setEnableDecoderFallback(true)
        Log.d(TAG, "Decoder mode: $decoderMode (FFmpeg enabled for IPTV video codecs)")
        
        player = androidx.media3.exoplayer.ExoPlayer.Builder(context, renderersFactory).build()
        
        // Container setup - no focus stealing
        containerView.isFocusable = false
        containerView.isFocusableInTouchMode = false
        containerView.setBackgroundColor(android.graphics.Color.BLACK)

        if (surfaceType == "texture") {
            Log.d(TAG, "Using TextureView for compatibility")
            val textureView = android.view.TextureView(context)
            textureView.isFocusable = false
            textureView.isFocusableInTouchMode = false
            textureView.layoutParams = android.widget.FrameLayout.LayoutParams(
                android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
                android.widget.FrameLayout.LayoutParams.MATCH_PARENT
            )
            containerView.addView(textureView)
            textureView.surfaceTextureListener = object : android.view.TextureView.SurfaceTextureListener {
                override fun onSurfaceTextureAvailable(surfaceTexture: android.graphics.SurfaceTexture, width: Int, height: Int) {
                    player.setVideoSurface(android.view.Surface(surfaceTexture))
                }
                override fun onSurfaceTextureSizeChanged(surfaceTexture: android.graphics.SurfaceTexture, width: Int, height: Int) {}
                override fun onSurfaceTextureDestroyed(surfaceTexture: android.graphics.SurfaceTexture): Boolean = true
                override fun onSurfaceTextureUpdated(surfaceTexture: android.graphics.SurfaceTexture) {}
            }
        } else {
            // SurfaceView: better performance, default for most devices
            Log.d(TAG, "Using SurfaceView for performance")
            val surfaceView = android.view.SurfaceView(context)
            surfaceView.isFocusable = false
            surfaceView.isFocusableInTouchMode = false
            surfaceView.layoutParams = android.widget.FrameLayout.LayoutParams(
                android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
                android.widget.FrameLayout.LayoutParams.MATCH_PARENT
            )
            containerView.addView(surfaceView)
            player.setVideoSurfaceView(surfaceView)
        }
        
        val url = params?.get("url") as? String
        val subtitleUrl = params?.get("subtitleUrl") as? String
        val headers = params?.get("headers") as? Map<String, String>
        if (url != null) {
            Log.d(TAG, "Initial URL found: $url with headers: $headers, subtitle: $subtitleUrl")
            play(url, headers, subtitleUrl)
        }

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "play" -> {
                    val newUrl = call.argument<String>("url")
                    val newSubtitleUrl = call.argument<String>("subtitleUrl")
                    val newHeaders = call.argument<Map<String, String>>("headers")
                    Log.d(TAG, "Method Call: play -> $newUrl, sub: $newSubtitleUrl")
                    if (newUrl != null) play(newUrl, newHeaders, newSubtitleUrl)
                    result.success(null)
                }
                "pause" -> {
                    Log.d(TAG, "Method Call: pause")
                    player.pause()
                    result.success(null)
                }
                "resume" -> {
                    Log.d(TAG, "Method Call: resume")
                    player.play()
                    result.success(null)
                }
                "seekTo" -> {
                    val position = call.argument<Int>("position")
                    Log.d(TAG, "Method Call: seekTo -> $position")
                    if (position != null) player.seekTo(position.toLong())
                    result.success(null)
                }
                "getCookies" -> {
                    val cookieUrl = call.argument<String>("url")
                    if (cookieUrl != null) {
                        val cookieManager = android.webkit.CookieManager.getInstance()
                        val cookies = cookieManager.getCookie(cookieUrl)
                        result.success(cookies)
                    } else {
                        result.error("INVALID_URL", "URL was null", null)
                    }
                }
                "dispose" -> {
                    Log.d(TAG, "Method Call: dispose")
                    dispose()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        
        player.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(state: Int) {
                sendUpdate()
            }

            override fun onVideoSizeChanged(videoSize: VideoSize) {
                if (videoSize.width > 0 && videoSize.height > 0) {
                    Log.d(TAG, "Video size: ${videoSize.width}x${videoSize.height}")
                }
            }

            override fun onPlayerError(error: PlaybackException) {
                Log.e(TAG, "ExoPlayer Error: ${error.message}", error)
                channel.invokeMethod("onPlayerError", mapOf("error" to error.message))
            }
        })

        mainHandler.post(statusUpdater)
    }

    private fun sendUpdate() {
        val status = when(player.playbackState) {
            Player.STATE_READY -> if (player.isPlaying) "playing" else "paused"
            Player.STATE_BUFFERING -> "buffering"
            Player.STATE_ENDED -> "ended"
            Player.STATE_IDLE -> "idle"
            else -> "unknown"
        }
        channel.invokeMethod("onPlayerStatus", mapOf(
            "status" to status,
            "duration" to player.duration,
            "position" to player.currentPosition
        ))
    }

    private fun play(url: String, headers: Map<String, String>? = null, subtitleUrl: String? = null) {
        try {
            val userAgent = headers?.get("User-Agent") ?: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
            val referer = headers?.get("Referer") ?: "https://www.vidking.net/"

            val httpDataSourceFactory = DefaultHttpDataSource.Factory()
                .setUserAgent(userAgent)
                .setAllowCrossProtocolRedirects(true)
            
            val requestProperties = mutableMapOf<String, String>()
            headers?.forEach { (key, value) -> requestProperties[key] = value }
            if (!requestProperties.containsKey("Referer")) {
                requestProperties["Referer"] = referer
            }
            httpDataSourceFactory.setDefaultRequestProperties(requestProperties)

            val dataSourceFactory = DefaultDataSource.Factory(
                containerView.context,
                httpDataSourceFactory
            )

            val extractorsFactory = DefaultExtractorsFactory()
                .setTsExtractorFlags(DefaultTsPayloadReaderFactory.FLAG_ALLOW_NON_IDR_KEYFRAMES)

            val mediaSourceFactory = androidx.media3.exoplayer.source.DefaultMediaSourceFactory(
                containerView.context,
                extractorsFactory
            ).setDataSourceFactory(dataSourceFactory)
            
            val mediaItemBuilder = MediaItem.Builder().setUri(url)
            
            if (subtitleUrl != null && subtitleUrl.isNotEmpty()) {
                val subtitle = MediaItem.SubtitleConfiguration.Builder(android.net.Uri.parse(subtitleUrl))
                    .setMimeType(MimeTypes.APPLICATION_SUBRIP)
                    .setLanguage("ku")
                    .setSelectionFlags(C.SELECTION_FLAG_DEFAULT)
                    .build()
                mediaItemBuilder.setSubtitleConfigurations(listOf(subtitle))
                Log.d(TAG, "Side-loading subtitle: $subtitleUrl")
            }

            val mediaItem = mediaItemBuilder.build()
            val mediaSource = mediaSourceFactory.createMediaSource(mediaItem)
            
            player.setMediaSource(mediaSource)
            player.prepare()
            player.playWhenReady = true
            Log.d(TAG, "Playback requested for: $url with headers: $requestProperties")
        } catch (e: Exception) {
            Log.e(TAG, "Error starting playback: ${e.message}")
        }
    }

    override fun getView(): View = containerView

    override fun dispose() {
        Log.d(TAG, "Disposing Player")
        mainHandler.removeCallbacks(statusUpdater)
        player.release()
    }
}
