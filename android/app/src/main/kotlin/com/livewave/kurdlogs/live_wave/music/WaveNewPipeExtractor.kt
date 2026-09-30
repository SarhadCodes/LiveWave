/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Isolated YouTube / YouTube Music access through NewPipe Extractor.
 * Does not include NewPipe application code.
 */
package com.livewave.kurdlogs.live_wave.music

import android.util.Log
import org.schabi.newpipe.extractor.Image
import org.schabi.newpipe.extractor.NewPipe
import org.schabi.newpipe.extractor.ServiceList
import org.schabi.newpipe.extractor.channel.ChannelInfoItem
import org.schabi.newpipe.extractor.playlist.PlaylistInfoItem
import org.schabi.newpipe.extractor.services.youtube.linkHandler.YoutubeSearchQueryHandlerFactory
import org.schabi.newpipe.extractor.stream.AudioStream
import org.schabi.newpipe.extractor.stream.DeliveryMethod
import org.schabi.newpipe.extractor.stream.StreamInfo
import org.schabi.newpipe.extractor.stream.StreamInfoItem
import kotlin.math.abs

internal object WaveNewPipeExtractor {
    private const val TAG = "WaveNewPipe"
    private val blockedTitle = listOf(
        "interview",
        "podcast",
        "reaction",
        "news",
        "trailer",
        "teaser",
        "shorts",
    )

    fun search(query: String, limit: Int): Map<String, Any?> {
        ensureInit()
        val cap = limit.coerceIn(1, 25)
        val tracks = searchItems(query, YoutubeSearchQueryHandlerFactory.MUSIC_SONGS, cap)
            .filterIsInstance<StreamInfoItem>()
            .filter { musicScore(it.name, it.duration) > -4 }
            .take(cap)
            .map { streamItem(it) }
        val artists = searchItems(query, YoutubeSearchQueryHandlerFactory.CHANNELS, 8)
            .filterIsInstance<ChannelInfoItem>()
            .take(8)
            .map { channelItem(it) }
        val albums = searchItems(query, YoutubeSearchQueryHandlerFactory.MUSIC_ALBUMS, 8)
            .filterIsInstance<PlaylistInfoItem>()
            .take(8)
            .map { playlistItem(it, album = true) }
        val playlists = searchItems(query, YoutubeSearchQueryHandlerFactory.MUSIC_PLAYLISTS, 8)
            .filterIsInstance<PlaylistInfoItem>()
            .take(8)
            .map { playlistItem(it, album = false) }
        Log.i(TAG, "search provider=youtube-music tracks=${tracks.size} artists=${artists.size} albums=${albums.size} playlists=${playlists.size}")
        for (track in tracks) {
            Log.i(
                TAG,
                "[WAVE_SEARCH] title=${track["title"]} artist=${track["artist"]} type=${track["type"]} id=${track["id"]}",
            )
        }
        return mapOf(
            "tracks" to tracks,
            "artists" to artists,
            "albums" to albums,
            "playlists" to playlists,
        )
    }

    fun songs(query: String, limit: Int): List<Map<String, Any?>> {
        ensureInit()
        val items = searchItems(query, YoutubeSearchQueryHandlerFactory.MUSIC_SONGS, limit.coerceIn(1, 30))
            .filterIsInstance<StreamInfoItem>()
            .filter { musicScore(it.name, it.duration) > -4 }
            .take(limit)
            .map { streamItem(it) }
        Log.i(TAG, "songs provider=youtube-music count=${items.size}")
        return items
    }

    fun loadCollection(url: String, kind: String, name: String): Map<String, Any?> {
        ensureInit()
        val service = NewPipe.getService(ServiceList.YouTube.serviceId)
        if (kind == "artist") {
            val query = name.ifBlank { url }
            val tracks = searchItems(query, YoutubeSearchQueryHandlerFactory.MUSIC_SONGS, 20)
                .filterIsInstance<StreamInfoItem>()
                .filter { musicScore(it.name, it.duration) > -4 }
                .take(20)
                .map { streamItem(it) }
            Log.i(TAG, "artist provider=youtube-music tracks=${tracks.size}")
            return mapOf(
                "kind" to "artist",
                "title" to name,
                "url" to url,
                "tracks" to tracks,
            )
        }
        val extractor = service.getPlaylistExtractor(url)
        extractor.fetchPage()
        val tracks = extractor.initialPage.items
            .filterIsInstance<StreamInfoItem>()
            .take(40)
            .map { streamItem(it, albumTitle = if (kind == "album") extractor.name else "") }
        Log.i(TAG, "collection kind=$kind type=playlist tracks=${tracks.size}")
        return mapOf(
            "kind" to kind,
            "title" to (extractor.name ?: ""),
            "uploader" to (extractor.uploaderName ?: ""),
            "artworkUrl" to bestImage(extractor.thumbnails),
            "url" to url,
            "trackCount" to tracks.size,
            "tracks" to tracks,
        )
    }

    fun resolveAudio(url: String): Map<String, Any?> {
        ensureInit()
        val id = videoId(url)
        Log.i(TAG, "[NEWPIPE] extract started service=YouTube id=$id")
        try {
            return resolveAudioInfo(url, id)
        } catch (e: Exception) {
            val reason = e.message?.substringBefore("http")?.take(160).orEmpty()
            Log.w(TAG, "[NEWPIPE] extract failed type=${e.javaClass.simpleName} id=$id reason=$reason")
            throw e
        }
    }

    private fun resolveAudioInfo(url: String, id: String): Map<String, Any?> {
        val info = StreamInfo.getInfo(url)
        val audio = info.audioStreams ?: emptyList()
        val videoCount = info.videoStreams?.size ?: 0
        Log.i(
            TAG,
            "[NEWPIPE] audio streams found = ${audio.size} videoStreams=$videoCount streamType=${info.streamType} ageLimit=${info.ageLimit} durationSec=${info.duration}",
        )
        for (stream in audio) {
            Log.i(
                TAG,
                "[NEWPIPE] stream mime=${stream.format?.mimeType ?: ""} codec=${stream.itagItem?.codec ?: ""} " +
                    "bitrate=${bitrateOf(stream)} durationSec=${info.duration} kind=audio-only delivery=${stream.deliveryMethod}",
            )
        }
        val progressive = audio.count { it.deliveryMethod == DeliveryMethod.PROGRESSIVE_HTTP && it.content.startsWith("http") }
        val chosen = chooseAudio(audio)
        if (chosen == null) {
            Log.i(TAG, "[NEWPIPE] selected none id=$id progressive=$progressive")
            throw IllegalStateException("No audio-only stream")
        }
        val bitrate = bitrateOf(chosen)
        val mime = chosen.format?.mimeType ?: ""
        val codec = chosen.itagItem?.codec ?: ""
        val durationMs = if (info.duration > 0) info.duration * 1000 else 0L
        Log.i(
            TAG,
            "resolve type=audio-only mime=$mime codec=$codec bitrate=$bitrate durationMs=$durationMs ok=true",
        )
        return mapOf(
            "id" to videoId(info.url),
            "title" to (info.name ?: ""),
            "artist" to (info.uploaderName ?: ""),
            "durationMs" to durationMs,
            "artworkUrl" to bestImage(info.thumbnails),
            "streamUrl" to chosen.content,
            "mimeType" to mime,
            "codec" to codec,
            "bitrate" to bitrate,
            "isAudioOnly" to true,
            "headers" to playbackHeaders(),
        )
    }

    private fun searchItems(query: String, filter: String, limit: Int): List<org.schabi.newpipe.extractor.InfoItem> {
        if (query.isBlank()) return emptyList()
        return try {
            val service = NewPipe.getService(ServiceList.YouTube.serviceId)
            val handler = service.searchQHFactory.fromQuery(query, listOf(filter), "")
            val extractor = service.getSearchExtractor(handler)
            extractor.fetchPage()
            extractor.initialPage.items.take(limit.coerceAtLeast(1))
        } catch (e: Exception) {
            Log.w(TAG, "search filter=$filter failed: ${e.javaClass.simpleName}")
            emptyList()
        }
    }

    private fun chooseAudio(streams: List<AudioStream>): AudioStream? {
        val progressive = streams.filter {
            it.deliveryMethod == DeliveryMethod.PROGRESSIVE_HTTP && it.content.startsWith("http")
        }
        if (progressive.isEmpty()) return null
        val m4a = progressive.filter { (it.format?.mimeType ?: "").contains("mp4") }
        val pool = if (m4a.isNotEmpty()) m4a else progressive
        return pool.minByOrNull { abs(bitrateOf(it) - 128_000) }
    }

    private fun bitrateOf(stream: AudioStream): Int {
        if (stream.averageBitrate > 0) return stream.averageBitrate
        val raw = stream.bitrate
        return if (raw in 1..2000) raw * 1000 else raw.coerceAtLeast(0)
    }

    private fun streamItem(item: StreamInfoItem, albumTitle: String = ""): Map<String, Any?> {
        val seconds = item.duration
        return mapOf(
            "type" to "track",
            "id" to videoId(item.url),
            "title" to item.name.orEmpty(),
            "artist" to item.uploaderName.orEmpty(),
            "artistUrl" to item.uploaderUrl.orEmpty(),
            "album" to albumTitle,
            "durationMs" to if (seconds > 0) seconds * 1000 else 0L,
            "artworkUrl" to bestImage(item.thumbnails),
            "url" to item.url.orEmpty(),
        )
    }

    private fun channelItem(item: ChannelInfoItem): Map<String, Any?> {
        return mapOf(
            "type" to "artist",
            "id" to item.url.orEmpty(),
            "title" to item.name.orEmpty(),
            "artworkUrl" to bestImage(item.thumbnails),
            "url" to item.url.orEmpty(),
            "description" to item.description.orEmpty(),
            "subscriberCount" to item.subscriberCount,
        )
    }

    private fun playlistItem(item: PlaylistInfoItem, album: Boolean): Map<String, Any?> {
        return mapOf(
            "type" to if (album) "album" else "playlist",
            "id" to item.url.orEmpty(),
            "title" to item.name.orEmpty(),
            "artist" to item.uploaderName.orEmpty(),
            "artworkUrl" to bestImage(item.thumbnails),
            "url" to item.url.orEmpty(),
            "trackCount" to item.streamCount.toInt(),
        )
    }

    private fun musicScore(title: String?, durationSeconds: Long): Int {
        val text = title?.lowercase().orEmpty()
        if (text.isBlank()) return -10
        var score = 0
        if (blockedTitle.any { text.contains(it) }) score -= 8
        if (durationSeconds in 75..600) score += 2
        if (durationSeconds in 1..44) score -= 3
        return score
    }

    private fun bestImage(images: List<Image>?): String {
        if (images.isNullOrEmpty()) return ""
        return images.maxByOrNull { it.height }?.url ?: images.last().url
    }

    private fun videoId(url: String?): String {
        if (url.isNullOrBlank()) return ""
        val watch = Regex("[?&]v=([\\w-]{6,})").find(url)?.groupValues?.getOrNull(1)
        if (!watch.isNullOrBlank()) return watch
        return url.substringAfterLast('/').substringBefore('?')
    }

    private fun playbackHeaders(): Map<String, String> {
        return mapOf(
            "User-Agent" to "Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36",
            "Referer" to "https://music.youtube.com/",
            "Origin" to "https://music.youtube.com",
        )
    }

    private fun ensureInit() {
        try {
            NewPipe.init(WaveNewPipeDownloader.instance)
        } catch (_: IllegalStateException) {
            // Already initialized.
        }
    }
}
