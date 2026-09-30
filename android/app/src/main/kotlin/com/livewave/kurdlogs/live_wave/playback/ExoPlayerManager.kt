package com.livewave.kurdlogs.live_wave.playback

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Surface
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.VideoSize
import androidx.media3.datasource.okhttp.OkHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.hls.HlsMediaSource
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.exoplayer.source.MediaSource
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import androidx.media3.extractor.DefaultExtractorsFactory
import androidx.media3.extractor.ts.DefaultTsPayloadReaderFactory
import androidx.media3.extractor.ts.TsExtractor
import io.flutter.view.TextureRegistry.SurfaceTextureEntry
import okhttp3.OkHttpClient
import java.util.concurrent.TimeUnit

/**
 * Single ExoPlayer instance for IPTV live + VOD.
 * FastTvLitePlus-style: one player, one texture, OkHttp + HLS for live.
 */
internal class ExoPlayerManager(
    private val context: Context,
    private val textureEntry: SurfaceTextureEntry,
    private val eventSink: () -> EventSink?,
) {
    interface EventSink {
        fun success(payload: Map<String, Any?>)
    }

    private val tag = "IptvExo_${textureEntry.id()}"
    private val mainHandler = Handler(Looper.getMainLooper())

    private var surface: Surface? = null
    private var surfaceAttached = false
    private var firstFrameRendered = false
    private var lastUrl: String? = null
    private var lastHeaders: Map<String, String>? = null
    private var lastSubtitleUrl: String? = null
    private var lastMode: String = MODE_LIVE

    private var bufferingStartedAtMs: Long = 0L
    private var readyWithoutFrameRunnable: Runnable? = null

    private val watchdogRunnable = object : Runnable {
        override fun run() {
            checkWatchdog()
            mainHandler.postDelayed(this, WATCHDOG_INTERVAL_MS)
        }
    }

    val exoPlayer: ExoPlayer

    private val playerListener = object : Player.Listener {
        override fun onPlaybackStateChanged(state: Int) {
            val name = stateName(state)
            log("STATE_$name")
            emit("stateChanged", mapOf("state" to name))

            when (state) {
                Player.STATE_READY -> scheduleReadyWithoutFrameCheck()
                Player.STATE_BUFFERING -> {
                    if (bufferingStartedAtMs == 0L) {
                        bufferingStartedAtMs = System.currentTimeMillis()
                    }
                    emit("bufferingStart", emptyMap())
                }
                Player.STATE_ENDED -> {
                    cancelReadyWithoutFrameCheck()
                    bufferingStartedAtMs = 0L
                }
                Player.STATE_IDLE -> {
                    cancelReadyWithoutFrameCheck()
                    bufferingStartedAtMs = 0L
                }
            }
        }

        override fun onIsPlayingChanged(isPlaying: Boolean) {
            if (isPlaying) {
                bufferingStartedAtMs = 0L
                emit("playing", emptyMap())
            }
        }

        override fun onRenderedFirstFrame() {
            firstFrameRendered = true
            cancelReadyWithoutFrameCheck()
            log("First frame rendered")
            emit("firstFrameRendered", emptyMap())
        }

        override fun onVideoSizeChanged(videoSize: VideoSize) {
            if (videoSize.width > 0 && videoSize.height > 0) {
                updateSurfaceBufferSize(videoSize.width, videoSize.height)
                log("Video size changed ${videoSize.width}x${videoSize.height}")
                emit(
                    "videoSize",
                    mapOf(
                        "width" to videoSize.width,
                        "height" to videoSize.height,
                    ),
                )
            }
        }

        override fun onPlayerError(error: PlaybackException) {
            log("Player error: ${error.message}")
            emit("exception", mapOf("error" to (error.message ?: "playback_error")))
        }
    }

    init {
        log("Texture creation textureId=${textureEntry.id()}")
        emit("textureCreated", mapOf("textureId" to textureEntry.id()))

        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(50_000, 50_000, 1_500, 3_000)
            .setPrioritizeTimeOverSizeThresholds(false)
            .setBackBuffer(0, false)
            .build()

        // Prefer hardware; fall back to software/FFmpeg when HW video decode fails (audio-only streams).
        val renderersFactory = DefaultRenderersFactory(context)
            .setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_ON)
            .setEnableDecoderFallback(true)

        exoPlayer = ExoPlayer.Builder(context, renderersFactory)
            .setTrackSelector(DefaultTrackSelector(context))
            .setLoadControl(loadControl)
            .build()

        exoPlayer.addListener(playerListener)
        // Surface is attached only after Flutter Texture is mounted (attachSurface).
        mainHandler.postDelayed(watchdogRunnable, WATCHDOG_INTERVAL_MS)
    }

    /** Attach surface after Flutter Texture is in the widget tree. */
    fun attachSurface(): Boolean {
        attachSurfaceFromTexture()
        if (surfaceAttached && lastUrl != null) {
            log("attachSurface — replaying pending source")
            recoverMediaSource()
        }
        return surfaceAttached
    }

    private fun attachSurfaceFromTexture(force: Boolean = false) {
        try {
            if (force) {
                exoPlayer.clearVideoSurface()
                surface?.release()
                surface = null
                surfaceAttached = false
            }
            val surfaceTexture = textureEntry.surfaceTexture()
            if (surface == null) {
                val metrics = context.resources.displayMetrics
                surfaceTexture.setDefaultBufferSize(metrics.widthPixels, metrics.heightPixels)
                surface = Surface(surfaceTexture)
            }
            exoPlayer.setVideoSurface(surface)
            surfaceAttached = true
            log("Surface created and attached")
            emit("surfaceAttached", mapOf("textureId" to textureEntry.id()))
        } catch (e: Exception) {
            surfaceAttached = false
            log("Surface attach failed: ${e.message}")
            emit("exception", mapOf("error" to "surface_attach_failed"))
        }
    }

    fun setLiveSource(url: String, headers: Map<String, String>?) {
        lastMode = MODE_LIVE
        lastUrl = url
        lastHeaders = headers
        lastSubtitleUrl = null
        firstFrameRendered = false
        bufferingStartedAtMs = 0L

        if (!surfaceAttached) {
            log("setLiveSource deferred — surface not attached (will replay on attachSurface)")
            return
        }

        val hlsUrl = normalizeToHls(url)
        log("setLiveSource url=$url format=${liveFormatFor(url)}")
        val mediaSource = when (liveFormatFor(url)) {
            LiveFormat.TS -> buildProgressiveTsMediaSource(url, headers)
            LiveFormat.HLS -> buildHlsMediaSource(hlsUrl, headers)
        }
        startPlayback(mediaSource)
    }

    private enum class LiveFormat { HLS, TS }

    private fun liveFormatFor(url: String): LiveFormat {
        return when {
            url.endsWith(".ts", ignoreCase = true) -> LiveFormat.TS
            url.endsWith(".m3u8", ignoreCase = true) -> LiveFormat.HLS
            else -> LiveFormat.HLS
        }
    }

    fun setVodSource(url: String, headers: Map<String, String>?, subtitleUrl: String?) {
        lastMode = MODE_VOD
        lastUrl = url
        lastHeaders = headers
        lastSubtitleUrl = subtitleUrl
        firstFrameRendered = false
        bufferingStartedAtMs = 0L

        if (!surfaceAttached) {
            log("setVodSource deferred — surface not attached")
            return
        }

        log("setVodSource url=$url")
        val mediaSource = buildVodMediaSource(url, headers, subtitleUrl)
        startPlayback(mediaSource)
    }

    private fun startPlayback(mediaSource: MediaSource) {
        if (!surfaceAttached) {
            log("startPlayback blocked — no surface")
            return
        }
        cancelReadyWithoutFrameCheck()
        surface?.let { exoPlayer.setVideoSurface(it) }
        exoPlayer.setMediaSource(mediaSource, /* resetPosition= */ true)
        exoPlayer.prepare()
        exoPlayer.playWhenReady = true
        log("prepare() fast switch")
    }

    private fun buildHlsMediaSource(url: String, headers: Map<String, String>?): MediaSource {
        val okHttpFactory = createOkHttpFactory(url, headers)
        return HlsMediaSource.Factory(okHttpFactory)
            .setAllowChunklessPreparation(true)
            .createMediaSource(MediaItem.fromUri(Uri.parse(url)))
    }

    /** MPEG-TS progressive fallback for .ts live URLs (redirect/token providers). */
    private fun buildProgressiveTsMediaSource(
        url: String,
        headers: Map<String, String>?,
    ): MediaSource {
        val okHttpFactory = createOkHttpFactory(url, headers)
        val extractorsFactory = DefaultExtractorsFactory()
            .setTsExtractorFlags(DefaultTsPayloadReaderFactory.FLAG_ALLOW_NON_IDR_KEYFRAMES)
            .setTsExtractorMode(TsExtractor.MODE_MULTI_PMT)
        return DefaultMediaSourceFactory(context, extractorsFactory)
            .setDataSourceFactory(okHttpFactory)
            .createMediaSource(MediaItem.fromUri(Uri.parse(url)))
    }

    private fun createOkHttpFactory(
        url: String,
        headers: Map<String, String>?,
    ): OkHttpDataSource.Factory {
        val userAgent = headers?.get("User-Agent") ?: DEFAULT_USER_AGENT
        val props = buildRequestProperties(url, headers)
        return OkHttpDataSource.Factory(SHARED_OK_HTTP)
            .setUserAgent(userAgent)
            .setDefaultRequestProperties(props)
    }

    private fun buildVodMediaSource(
        url: String,
        headers: Map<String, String>?,
        subtitleUrl: String?,
    ): MediaSource {
        val okHttpFactory = createOkHttpFactory(url, headers)

        val builder = MediaItem.Builder().setUri(url)
        if (!subtitleUrl.isNullOrEmpty()) {
            builder.setSubtitleConfigurations(
                listOf(
                    MediaItem.SubtitleConfiguration.Builder(Uri.parse(subtitleUrl))
                        .setMimeType(MimeTypes.APPLICATION_SUBRIP)
                        .setLanguage("ku")
                        .setSelectionFlags(C.SELECTION_FLAG_DEFAULT)
                        .build(),
                ),
            )
        }

        return DefaultMediaSourceFactory(context)
            .setDataSourceFactory(okHttpFactory)
            .createMediaSource(builder.build())
    }

    fun pause() {
        exoPlayer.playWhenReady = false
    }

    fun resume() {
        exoPlayer.playWhenReady = true
    }

    fun seekTo(positionMs: Long) {
        exoPlayer.seekTo(positionMs)
    }

    /** Retry HTTP / MediaSource only — ExoPlayer instance preserved. */
    fun retrySource() {
        log("retrySource")
        recoverMediaSource()
    }

    /** Stall watchdog recovery — clear and re-prepare, keep ExoPlayer. */
    fun recoverMediaSource() {
        log("recoverMediaSource")
        val url = lastUrl ?: return
        when (lastMode) {
            MODE_LIVE -> setLiveSource(url, lastHeaders)
            MODE_VOD -> setVodSource(url, lastHeaders, lastSubtitleUrl)
        }
    }

    /** Reattach surface without recreating ExoPlayer. */
    fun recoverSurface() {
        log("recoverSurface")
        exoPlayer.clearVideoSurface()
        surfaceAttached = false
        surface?.release()
        surface = null
        attachSurfaceFromTexture(force = true)
        recoverMediaSource()
    }

    fun dispose() {
        mainHandler.removeCallbacks(watchdogRunnable)
        cancelReadyWithoutFrameCheck()
        try {
            exoPlayer.release()
        } catch (_: Exception) {
        }
        surface?.release()
        surface = null
        surfaceAttached = false
        try {
            textureEntry.release()
        } catch (_: Exception) {
        }
        log("Surface destroyed — player disposed")
        emit("surfaceDestroyed", emptyMap())
    }

    private fun scheduleReadyWithoutFrameCheck() {
        cancelReadyWithoutFrameCheck()
        readyWithoutFrameRunnable = Runnable {
            if (!firstFrameRendered && exoPlayer.playbackState == Player.STATE_READY) {
                log("STATE_READY without first frame within ${READY_FRAME_TIMEOUT_MS}ms — recover surface then source")
                emit("readyWithoutFrame", emptyMap())
                recoverSurface()
            }
        }
        mainHandler.postDelayed(readyWithoutFrameRunnable!!, READY_FRAME_TIMEOUT_MS)
    }

    private fun cancelReadyWithoutFrameCheck() {
        readyWithoutFrameRunnable?.let { mainHandler.removeCallbacks(it) }
        readyWithoutFrameRunnable = null
    }

    private fun checkWatchdog() {
        if (bufferingStartedAtMs > 0L) {
            val elapsed = System.currentTimeMillis() - bufferingStartedAtMs
            if (elapsed >= STALL_BUFFERING_MS) {
                log("Watchdog: buffering > ${STALL_BUFFERING_MS}ms — recover")
                bufferingStartedAtMs = 0L
                emit("stallDetected", mapOf("reason" to "buffering"))
                recoverMediaSource()
            }
        }
    }

    private fun updateSurfaceBufferSize(width: Int, height: Int) {
        if (width <= 0 || height <= 0) return
        try {
            textureEntry.surfaceTexture().setDefaultBufferSize(width, height)
        } catch (e: Exception) {
            log("setDefaultBufferSize failed: ${e.message}")
        }
    }

    private fun emit(event: String, data: Map<String, Any?>) {
        mainHandler.post {
            val payload = HashMap<String, Any?>()
            payload["event"] = event
            payload.putAll(data)
            eventSink()?.success(payload)
        }
    }

    private fun log(message: String) {
        Log.i(tag, message)
    }

    private fun stateName(state: Int): String = when (state) {
        Player.STATE_IDLE -> "IDLE"
        Player.STATE_BUFFERING -> "BUFFERING"
        Player.STATE_READY -> "READY"
        Player.STATE_ENDED -> "ENDED"
        else -> "UNKNOWN"
    }

    companion object {
        const val MODE_LIVE = "live"
        const val MODE_VOD = "vod"
        const val DEFAULT_USER_AGENT = "IPTV Smarters Pro"

        private const val READY_FRAME_TIMEOUT_MS = 5_000L
        private const val STALL_BUFFERING_MS = 20_000L
        private const val WATCHDOG_INTERVAL_MS = 5_000L

        val SHARED_OK_HTTP: OkHttpClient by lazy {
            OkHttpClient.Builder()
                .connectTimeout(15, TimeUnit.SECONDS)
                .readTimeout(45, TimeUnit.SECONDS)
                .writeTimeout(45, TimeUnit.SECONDS)
                .followRedirects(true)
                .followSslRedirects(true)
                .retryOnConnectionFailure(true)
                .build()
        }

        /** Live IPTV always uses HLS — normalize .ts URLs to .m3u8. */
        fun normalizeToHls(url: String): String {
            val trimmed = url.trim()
            if (trimmed.endsWith(".ts", ignoreCase = true)) {
                return trimmed.dropLast(3) + "m3u8"
            }
            return trimmed
        }

        fun buildRequestProperties(
            url: String,
            headers: Map<String, String>?,
        ): HashMap<String, String> {
            val props = HashMap<String, String>()
            headers?.forEach { (key, value) -> props[key] = value }

            if (!props.containsKey("Accept")) props["Accept"] = "*/*"
            if (!props.keys.any { it.equals("Accept-Encoding", ignoreCase = true) }) {
                props["Accept-Encoding"] = "identity"
            }

            if (!props.keys.any { it.equals("Referer", ignoreCase = true) }) {
                try {
                    val uri = Uri.parse(url)
                    val port = if (uri.port > 0) ":${uri.port}" else ""
                    props["Referer"] = "${uri.scheme}://${uri.host}$port/"
                } catch (_: Exception) {
                }
            }

            val cookieManager = android.webkit.CookieManager.getInstance()
            val cookies = cookieManager.getCookie(url)
            if (!cookies.isNullOrEmpty() && !props.containsKey("Cookie")) {
                props["Cookie"] = cookies
            }

            return props
        }
    }
}
