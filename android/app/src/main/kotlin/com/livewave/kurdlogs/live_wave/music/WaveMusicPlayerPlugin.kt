package com.livewave.kurdlogs.live_wave.music

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.media3.common.MediaItem
import java.util.concurrent.Executors
import androidx.media3.common.MediaMetadata
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class WaveMusicPlayerPlugin(
    private val context: Context,
    flutterEngine: FlutterEngine,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler, Player.Listener {

    private val replyEngineId = System.identityHashCode(flutterEngine)
    private val replyMessengerId =
        System.identityHashCode(flutterEngine.dartExecutor.binaryMessenger)
    private val channel = MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        CHANNEL,
    )
    private val events = EventChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        EVENTS,
    )
    private val mainHandler = Handler(Looper.getMainLooper())
    private val extractorExecutor = Executors.newSingleThreadExecutor()
    private val prefetchExecutor = Executors.newSingleThreadExecutor()
    private var eventSink: EventChannel.EventSink? = null
    private var attached = false
    private var serviceStarted = false

    private val positionTicker = object : Runnable {
        override fun run() {
            val player = WaveMusicEngine.playerOrNull() ?: return
            emit(
                "position",
                mapOf(
                    "positionMs" to player.currentPosition,
                    "durationMs" to durationMs(player.duration),
                ),
            )
            if (player.isPlaying) {
                mainHandler.postDelayed(this, 400L)
            }
        }
    }

    fun register() {
        Log.i(
            PLAY,
            "[WAVE_REPLY] register channel=$CHANNEL engine=$replyEngineId messenger=$replyMessengerId",
        )
        channel.setMethodCallHandler(this)
        events.setStreamHandler(this)
        WaveMusicEngine.onSessionSkip = { next -> onSessionSkip(next) }
    }

    fun unregister() {
        mainHandler.removeCallbacks(positionTicker)
        WaveMusicEngine.playerOrNull()?.removeListener(this)
        WaveMusicEngine.onSessionSkip = null
        channel.setMethodCallHandler(null)
        events.setStreamHandler(null)
        eventSink = null
        attached = false
    }

    private fun onSessionSkip(next: Boolean) {
        Log.i(PLAY, "[WAVE_PLAY] session callback next=$next")
        if (next) emit("skipNext", emptyMap()) else emit("skipPrevious", emptyMap())
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "warmUp" -> {
                    ensurePlayer()
                    result.success(null)
                }
                "setQueue" -> {
                    val rawItems = call.argument<List<*>>("items").orEmpty()
                    val items = rawItems.mapNotNull { item ->
                        (item as? Map<*, *>)?.entries?.associate { it.key.toString() to it.value }
                    }
                    val startIndex = intArg(call, "startIndex")
                    val play = boolArg(call, "play", true)
                    val shuffle = boolArg(call, "shuffle", false)
                    val repeat = call.argument<String>("repeat") ?: "off"
                    setQueue(items, startIndex, play, shuffle, repeat)
                    result.success(null)
                }
                "play" -> {
                    ensurePlayer().play()
                    startService()
                    result.success(null)
                }
                "pause" -> {
                    WaveMusicEngine.playerOrNull()?.pause()
                    result.success(null)
                }
                "next" -> {
                    val player = ensurePlayer()
                    if (player.hasNextMediaItem()) player.seekToNextMediaItem() else emit("skipNext", emptyMap())
                    result.success(null)
                }
                "previous" -> {
                    val player = ensurePlayer()
                    if (player.currentPosition > 2500L) {
                        player.seekTo(0)
                    } else if (player.hasPreviousMediaItem()) {
                        player.seekToPreviousMediaItem()
                    } else {
                        emit("skipPrevious", emptyMap())
                    }
                    result.success(null)
                }
                "seek" -> {
                    val ms = numberArg(call, "positionMs")
                    WaveMusicEngine.playerOrNull()?.seekTo(ms)
                    result.success(null)
                }
                "setShuffle" -> {
                    ensurePlayer().shuffleModeEnabled = boolArg(call, "enabled", false)
                    result.success(null)
                }
                "setRepeat" -> {
                    ensurePlayer().repeatMode = repeatMode(call.argument<String>("mode"))
                    result.success(null)
                }
                "setVolume" -> {
                    val raw = call.argument<Any>("volume")
                    val volume = when (raw) {
                        is Float -> raw
                        is Double -> raw.toFloat()
                        is Number -> raw.toFloat()
                        else -> 1f
                    }.coerceIn(0f, 1f)
                    WaveMusicEngine.playerOrNull()?.volume = volume
                    result.success(null)
                }
                "stop" -> {
                    WaveMusicEngine.playerOrNull()?.stop()
                    WaveMusicEngine.playerOrNull()?.clearMediaItems()
                    result.success(null)
                }
                "searchMusic" -> {
                    val query = call.argument<String>("query") ?: ""
                    val limit = intArg(call, "limit", 20)
                    runExtract(result) { WaveNewPipeExtractor.search(query, limit) }
                }
                "musicSongs" -> {
                    val query = call.argument<String>("query") ?: ""
                    val limit = intArg(call, "limit", 20)
                    runExtract(result) { WaveNewPipeExtractor.songs(query, limit) }
                }
                "loadCollection" -> {
                    val url = call.argument<String>("url") ?: ""
                    val kind = call.argument<String>("kind") ?: "playlist"
                    val name = call.argument<String>("name") ?: ""
                    runExtract(result) { WaveNewPipeExtractor.loadCollection(url, kind, name) }
                }
                "resolveAudioStream" -> {
                    val url = call.argument<String>("url") ?: ""
                    val play = call.argument<Boolean>("play") ?: true
                    // Prefetch stays off the playback executor so a warm-up extract
                    // cannot sit in front of the track the user just tapped.
                    val executor = if (play) extractorExecutor else prefetchExecutor
                    executor.execute {
                        try {
                            val value = WaveNewPipeExtractor.resolveAudio(url).toMutableMap()
                            mainHandler.post {
                                // Reply first. handoffResolved() starts the service and
                                // player on this same thread; doing that before
                                // result.success() nests Flutter JNI and the Dart
                                // invokeMethod future never completes.
                                val playable = play && value["streamUrl"]?.toString()?.startsWith("http") == true
                                if (playable) value["handedOff"] = true
                                Log.i(
                                    PLAY,
                                    "[WAVE_REPLY] before success engine=$replyEngineId messenger=$replyMessengerId " +
                                        "result=${System.identityHashCode(result)} " +
                                        "main=${Looper.myLooper() == Looper.getMainLooper()}",
                                )
                                try {
                                    result.success(value)
                                    Log.i(
                                        PLAY,
                                        "[WAVE_REPLY] after success result=${System.identityHashCode(result)}",
                                    )
                                } catch (t: Throwable) {
                                    Log.e(
                                        PLAY,
                                        "[WAVE_REPLY] success threw ${t.javaClass.name} ${t.message}",
                                    )
                                    throw t
                                }
                                if (playable) handoffResolved(value)
                            }
                        } catch (e: Exception) {
                            Log.w(TAG, "extract failed: ${e.javaClass.simpleName}")
                            val message = e.message?.substringBefore("http")?.take(180) ?: "Stream extraction failed"
                            mainHandler.post { result.error("extract_error", message, null) }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            Log.e(TAG, "method ${call.method} failed", e)
            result.error("music_error", e.message, null)
        }
    }

    private fun setQueue(
        items: List<Map<String, Any?>>,
        startIndex: Int,
        play: Boolean,
        shuffle: Boolean,
        repeat: String,
    ) {
        val player = ensurePlayer()
        val headerSource = items.firstOrNull { it["headers"] is Map<*, *> }
        val rawHeaders = headerSource?.get("headers") as? Map<*, *>
        if (rawHeaders != null) {
            WaveMusicEngine.setRequestHeaders(
                rawHeaders.entries.associate { it.key.toString() to it.value.toString() },
            )
        }
        val mediaItems = items.mapNotNull { toMediaItem(it) }
        val playerId = System.identityHashCode(player)
        if (mediaItems.isEmpty()) {
            Log.i(PLAY, "[WAVE_ENGINE] setMediaItem skipped playerId=$playerId urlEmpty=true count=0")
            return
        }
        val index = startIndex.coerceIn(0, mediaItems.lastIndex)
        val item = mediaItems[index]
        val host = item.localConfiguration?.uri?.host ?: ""
        val mime = item.localConfiguration?.mimeType ?: ""
        Log.i(
            PLAY,
            "[WAVE_ENGINE] setMediaItem called playerId=$playerId count=${mediaItems.size} index=$index " +
                "mime=$mime hls=${mime.contains("mpegurl", ignoreCase = true)} streamHost=$host urlEmpty=${host.isEmpty() && item.localConfiguration?.uri == null}",
        )
        player.shuffleModeEnabled = shuffle
        player.repeatMode = repeatMode(repeat)
        if (play) startService()
        val servicePlayerId = System.identityHashCode(WaveMusicEngine.playerOrNull())
        Log.i(PLAY, "[WAVE_ENGINE] sameInstance=${playerId == servicePlayerId} servicePlayerId=$servicePlayerId")
        player.setMediaItems(mediaItems, index, 0L)
        Log.i(PLAY, "[WAVE_ENGINE] prepare called playerId=$playerId")
        player.prepare()
        if (play) {
            player.play()
            Log.i(
                PLAY,
                "[WAVE_ENGINE] play called playerId=$playerId playWhenReady=${player.playWhenReady} " +
                    "handleAudioFocus=true released=${WaveMusicEngine.playerOrNull() == null}",
            )
        }
        emit("index", mapOf("index" to index, "id" to mediaItems[index].mediaId))
    }

    private fun toMediaItem(raw: Map<String, Any?>): MediaItem? {
        val id = raw["id"]?.toString().orEmpty()
        val url = raw["audioUrl"]?.toString().orEmpty()
        if (id.isEmpty() || url.isEmpty()) {
            Log.i(PLAY, "[WAVE_ENGINE] mediaItem dropped idEmpty=${id.isEmpty()} urlEmpty=${url.isEmpty()}")
            return null
        }
        val artwork = raw["artworkUrl"]?.toString().orEmpty()
        val mime = raw["mimeType"]?.toString().orEmpty()
        val metadata = MediaMetadata.Builder()
            .setTitle(raw["title"]?.toString() ?: "")
            .setArtist(raw["artist"]?.toString() ?: "")
            .setAlbumTitle(raw["album"]?.toString() ?: "")
        if (artwork.isNotEmpty()) {
            metadata.setArtworkUri(Uri.parse(artwork))
        }
        val item = MediaItem.Builder()
            .setMediaId(id)
            .setUri(url)
            .setMediaMetadata(metadata.build())
        val hls = mime.contains("mpegURL", ignoreCase = true) || url.contains(".m3u8")
        if (hls) {
            item.setMimeType(MimeTypes.APPLICATION_M3U8)
        } else if (mime.isNotBlank()) {
            item.setMimeType(mime)
        }
        Log.i(
            PLAY,
            "[WAVE_ENGINE] mediaItem id=$id mime=$mime hls=$hls streamHost=${streamHost(url)} urlEmpty=false",
        )
        return item.build()
    }

    private fun ensurePlayer(): androidx.media3.exoplayer.ExoPlayer {
        val player = WaveMusicEngine.player(context)
        if (!attached) {
            player.addListener(this)
            attached = true
        }
        return player
    }

    private fun startService() {
        if (serviceStarted) return
        val intent = Intent(context, WaveMusicPlaybackService::class.java)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            serviceStarted = true
        } catch (e: Exception) {
            serviceStarted = false
            Log.w(TAG, "start music service failed: ${e.message}")
        }
    }

    private fun repeatMode(name: String?): Int {
        return when (name) {
            "one" -> Player.REPEAT_MODE_ONE
            // The native player holds one item. Repeat-all wraps the Dart queue
            // when that item ends, so ExoPlayer must not loop it itself.
            "all" -> Player.REPEAT_MODE_OFF
            else -> Player.REPEAT_MODE_OFF
        }
    }

    override fun onIsPlayingChanged(isPlaying: Boolean) {
        val playerId = System.identityHashCode(WaveMusicEngine.playerOrNull())
        Log.i(PLAY, "[MEDIA3] ${if (isPlaying) "PLAYING" else "NOT_PLAYING"} playerId=$playerId")
        if (isPlaying) {
            startService()
            emit("playing", mapOf("playing" to true))
            mainHandler.removeCallbacks(positionTicker)
            mainHandler.post(positionTicker)
        } else {
            emit("paused", mapOf("playing" to false))
            mainHandler.removeCallbacks(positionTicker)
        }
    }

    override fun onPlaybackStateChanged(playbackState: Int) {
        val playerId = System.identityHashCode(WaveMusicEngine.playerOrNull())
        when (playbackState) {
            Player.STATE_BUFFERING -> {
                Log.i(PLAY, "[MEDIA3] STATE_BUFFERING playerId=$playerId")
                emit("buffering", emptyMap())
            }
            Player.STATE_ENDED -> {
                Log.i(PLAY, "[MEDIA3] STATE_ENDED playerId=$playerId")
                emit("ended", emptyMap())
            }
            Player.STATE_READY -> {
                Log.i(PLAY, "[MEDIA3] STATE_READY playerId=$playerId playWhenReady=${WaveMusicEngine.playerOrNull()?.playWhenReady}")
                val player = WaveMusicEngine.playerOrNull()
                if (player?.playWhenReady == true) {
                    startService()
                }
                emit(
                    "position",
                    mapOf(
                        "positionMs" to (player?.currentPosition ?: 0L),
                        "durationMs" to durationMs(player?.duration),
                    ),
                )
            }
        }
    }

    override fun onMediaItemTransition(mediaItem: MediaItem?, reason: Int) {
        val player = WaveMusicEngine.playerOrNull() ?: return
        emit(
            "index",
            mapOf(
                "index" to player.currentMediaItemIndex,
                "id" to (mediaItem?.mediaId ?: ""),
            ),
        )
    }

    override fun onPlayerError(error: PlaybackException) {
        val safe = redact(error.message ?: "")
        Log.e(
            PLAY,
            "[MEDIA3] PLAYER_ERROR code=${error.errorCodeName} cause=${error.cause?.javaClass?.name} message=$safe",
        )
        emit("error", mapOf("message" to (safe.ifBlank { "Playback failed" })))
    }

    /** Prepare the resolved item before the extractor reply returns to Dart. */
    private fun handoffResolved(value: Map<String, Any?>): Boolean {
        val url = value["streamUrl"]?.toString().orEmpty()
        if (!url.startsWith("http")) return false
        val rawId = value["id"]?.toString().orEmpty()
        val id = if (rawId.startsWith("yt_")) rawId else "yt_$rawId"
        val repeat = when (WaveMusicEngine.playerOrNull()?.repeatMode) {
            Player.REPEAT_MODE_ONE -> "one"
            else -> "off"
        }
        setQueue(
            listOf(
                mapOf(
                    "id" to id,
                    "title" to (value["title"] ?: ""),
                    "artist" to (value["artist"] ?: ""),
                    "album" to "",
                    "artworkUrl" to (value["artworkUrl"] ?: ""),
                    "audioUrl" to url,
                    "mimeType" to (value["mimeType"] ?: ""),
                    "headers" to (value["headers"] ?: emptyMap<String, String>()),
                ),
            ),
            0,
            true,
            false,
            repeat,
        )
        Log.i(PLAY, "[WAVE_PLAY] native handoff id=$id")
        return true
    }

    private fun runExtract(result: MethodChannel.Result, block: () -> Any?) {
        extractorExecutor.execute {
            try {
                val value = block()
                mainHandler.post { result.success(value) }
            } catch (e: Exception) {
                Log.w(TAG, "extract failed: ${e.javaClass.simpleName}")
                val message = e.message?.substringBefore("http")?.take(180) ?: "Stream extraction failed"
                mainHandler.post { result.error("extract_error", message, null) }
            }
        }
    }

    private fun intArg(call: MethodCall, key: String, fallback: Int = 0): Int {
        val raw = call.argument<Any>(key) ?: return fallback
        return when (raw) {
            is Int -> raw
            is Long -> raw.toInt()
            is Number -> raw.toInt()
            else -> fallback
        }
    }

    private fun boolArg(call: MethodCall, key: String, fallback: Boolean): Boolean {
        val raw = call.argument<Any>(key) ?: return fallback
        return when (raw) {
            is Boolean -> raw
            is Number -> raw.toInt() != 0
            else -> fallback
        }
    }

    private fun numberArg(call: MethodCall, key: String): Long {
        val raw = call.argument<Any>(key) ?: return 0L
        return when (raw) {
            is Long -> raw
            is Int -> raw.toLong()
            is Number -> raw.toLong()
            else -> 0L
        }
    }

    private fun streamHost(url: String): String {
        return runCatching { Uri.parse(url).host }.getOrNull().orEmpty()
    }

    private fun redact(text: String): String {
        return text.replace(Regex("https?://\\S+"), "<url>")
    }

    private fun durationMs(value: Long?): Long {
        val duration = value ?: 0L
        return if (duration < 0L || duration == androidx.media3.common.C.TIME_UNSET) 0L else duration
    }

    private fun emit(type: String, payload: Map<String, Any?>) {
        val data = HashMap<String, Any?>(payload)
        data["type"] = type
        mainHandler.post {
            val sink = eventSink
            if (sink == null) {
                Log.i(PLAY, "[WAVE_PLAY] emit dropped type=$type")
            } else {
                Log.i(PLAY, "[WAVE_PLAY] emit type=$type")
                sink.success(data)
            }
        }
    }

    companion object {
        private const val TAG = "WaveMusicPlayer"
        private const val PLAY = "WAVE_PLAY"
        const val CHANNEL = "wave_music_player"
        const val EVENTS = "wave_music_player/events"
    }
}
