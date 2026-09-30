package com.livewave.kurdlogs.live_wave.playback

import android.content.Context
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Single native bridge: one [ExoPlayerManager] per texture session.
 * Channel: iptv_exo_player
 */
class IptvExoPlayerPlugin(
    private val context: Context,
    private val flutterEngine: FlutterEngine,
) : MethodChannel.MethodCallHandler {

    private var manager: ExoPlayerManager? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private var currentTextureId: Long = -1L

    private val channel = MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        CHANNEL,
    )

    fun register() {
        channel.setMethodCallHandler(this)
    }

    fun unregister() {
        channel.setMethodCallHandler(null)
        disposeManager()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "create" -> {
                // Reuse existing ExoPlayer + texture (hot restart / re-init).
                manager?.let {
                    Log.i(TAG, "create reuse textureId=$currentTextureId")
                    result.success(
                        mapOf(
                            "textureId" to currentTextureId,
                            "surfaceAttached" to false,
                            "reused" to true,
                        ),
                    )
                    return
                }

                val textureEntry = flutterEngine.renderer.createSurfaceTexture()
                val textureId = textureEntry.id()
                currentTextureId = textureId
                Log.i(TAG, "create textureId=$textureId")

                eventChannel = EventChannel(
                    flutterEngine.dartExecutor.binaryMessenger,
                    "$EVENTS_PREFIX$textureId",
                ).also { ch ->
                    ch.setStreamHandler(object : EventChannel.StreamHandler {
                        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                            eventSink = events
                        }

                        override fun onCancel(arguments: Any?) {
                            eventSink = null
                        }
                    })
                }

                manager = ExoPlayerManager(context, textureEntry) {
                    object : ExoPlayerManager.EventSink {
                        override fun success(payload: Map<String, Any?>) {
                            eventSink?.success(payload)
                        }
                    }
                }

                result.success(
                    mapOf(
                        "textureId" to textureId,
                        "surfaceAttached" to false,
                        "reused" to false,
                    ),
                )
            }

            "attachSurface" -> {
                val attached = manager?.attachSurface() == true
                Log.i(TAG, "attachSurface attached=$attached textureId=$currentTextureId")
                result.success(mapOf("surfaceAttached" to attached))
            }

            "setLiveSource" -> {
                val url = call.argument<String>("url")
                if (url.isNullOrEmpty()) {
                    result.error("invalid_url", "URL required", null)
                    return
                }
                @Suppress("UNCHECKED_CAST")
                val headers = call.argument<Map<String, String>>("headers")
                manager?.setLiveSource(url, headers)
                result.success(null)
            }

            "setVodSource" -> {
                val url = call.argument<String>("url")
                if (url.isNullOrEmpty()) {
                    result.error("invalid_url", "URL required", null)
                    return
                }
                @Suppress("UNCHECKED_CAST")
                val headers = call.argument<Map<String, String>>("headers")
                val subtitleUrl = call.argument<String>("subtitleUrl")
                manager?.setVodSource(url, headers, subtitleUrl)
                result.success(null)
            }

            "pause" -> {
                manager?.pause()
                result.success(null)
            }

            "resume" -> {
                manager?.resume()
                result.success(null)
            }

            "seekTo" -> {
                val position = call.argument<Number>("position")?.toLong() ?: 0L
                manager?.seekTo(position)
                result.success(null)
            }

            "retry" -> {
                manager?.retrySource()
                result.success(null)
            }

            "recover" -> {
                manager?.recoverMediaSource()
                result.success(null)
            }

            "recoverSurface" -> {
                manager?.recoverSurface()
                result.success(null)
            }

            "getPosition" -> {
                val player = manager?.exoPlayer
                result.success(
                    mapOf(
                        "position" to (player?.currentPosition ?: 0L),
                        "duration" to (player?.duration ?: 0L),
                        "isPlaying" to (player?.isPlaying == true),
                        "state" to (player?.playbackState ?: 0),
                    ),
                )
            }

            "dispose" -> {
                disposeManager()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun disposeManager() {
        manager?.dispose()
        manager = null
        currentTextureId = -1L
        eventChannel?.setStreamHandler(null)
        eventChannel = null
        eventSink = null
    }

    companion object {
        private const val TAG = "IptvExoPlugin"
        const val CHANNEL = "iptv_exo_player"
        private const val EVENTS_PREFIX = "iptv_exo_player/events"
    }
}
