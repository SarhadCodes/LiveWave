/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * WAVE's own HTTP downloader for the NewPipe Extractor library API.
 * This is not copied from the NewPipe application.
 */
package com.livewave.kurdlogs.live_wave.music

import okhttp3.OkHttpClient
import okhttp3.RequestBody.Companion.toRequestBody
import org.schabi.newpipe.extractor.downloader.Downloader
import org.schabi.newpipe.extractor.downloader.Request
import org.schabi.newpipe.extractor.downloader.Response
import java.util.concurrent.TimeUnit

internal class WaveNewPipeDownloader private constructor() : Downloader() {
    private val client = OkHttpClient.Builder()
        .connectTimeout(20, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .followRedirects(true)
        .followSslRedirects(true)
        .build()

    override fun execute(request: Request): Response {
        val builder = okhttp3.Request.Builder().url(request.url())
        request.headers()?.forEach { (name, values) ->
            builder.removeHeader(name)
            for (value in values) {
                builder.addHeader(name, value)
            }
        }
        val method = request.httpMethod()
        val payload = request.dataToSend()
        val body = when {
            method == "GET" || method == "HEAD" -> null
            payload != null -> payload.toRequestBody(null)
            method == "POST" -> ByteArray(0).toRequestBody(null)
            else -> null
        }
        builder.method(method, body)
        client.newCall(builder.build()).execute().use { response ->
            val headers = mutableMapOf<String, List<String>>()
            for (name in response.headers.names()) {
                headers[name] = response.headers.values(name)
            }
            return Response(
                response.code,
                response.message,
                headers,
                response.body?.string(),
                response.request.url.toString(),
            )
        }
    }

    companion object {
        val instance = WaveNewPipeDownloader()
    }
}
