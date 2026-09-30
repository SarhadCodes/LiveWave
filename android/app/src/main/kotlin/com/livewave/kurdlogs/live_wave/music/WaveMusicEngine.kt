package com.livewave.kurdlogs.live_wave.music

import android.content.Context
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.Player
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory

/**
 * Single audio ExoPlayer for WAVE MUSIC.
 * Separate from [com.livewave.kurdlogs.live_wave.playback.ExoPlayerManager] (IPTV).
 * HLS AAC (SoundCloud) is handled by media3-exoplayer-hls via DefaultMediaSourceFactory.
 */
internal object WaveMusicEngine {
    @Volatile
    private var player: ExoPlayer? = null
    private var httpFactory: DefaultHttpDataSource.Factory? = null

    fun setRequestHeaders(headers: Map<String, String>) {
        val factory = httpFactory ?: return
        val userAgent = headers["User-Agent"] ?: headers["user-agent"]
        if (!userAgent.isNullOrBlank()) {
            factory.setUserAgent(userAgent)
        }
        factory.setDefaultRequestProperties(headers)
    }

    @Synchronized
    fun player(context: Context): ExoPlayer {
        player?.let { return it }
        val httpFactory = DefaultHttpDataSource.Factory()
            .setUserAgent("WAVE-Music/1.0")
            .setAllowCrossProtocolRedirects(true)
            .setConnectTimeoutMs(12_000)
            .setReadTimeoutMs(20_000)
            .setKeepPostFor302Redirects(true)
        this.httpFactory = httpFactory
        // Start as soon as a short slice of audio is buffered. The default
        // start buffer is what makes a resolved track sit silent for a second.
        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(5_000, 30_000, 200, 500)
            .setPrioritizeTimeOverSizeThresholds(true)
            .build()
        val created = ExoPlayer.Builder(context.applicationContext)
            .setMediaSourceFactory(DefaultMediaSourceFactory(httpFactory))
            .setLoadControl(loadControl)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(C.USAGE_MEDIA)
                    .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
                    .build(),
                true,
            )
            .setHandleAudioBecomingNoisy(true)
            .build()
        created.repeatMode = Player.REPEAT_MODE_OFF
        player = created
        return created
    }

    fun playerOrNull(): ExoPlayer? = player

    /** Notification next/previous. Dart owns the queue; the player holds one item. */
    @Volatile
    var onSessionSkip: ((next: Boolean) -> Unit)? = null
}
