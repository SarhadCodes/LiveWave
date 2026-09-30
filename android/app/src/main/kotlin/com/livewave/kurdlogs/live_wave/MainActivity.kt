package com.livewave.kurdlogs.live_wave

import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.util.Rational
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import androidx.activity.OnBackPressedCallback
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterShellArgs
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val tag = "MainActivity"
    private var playerBackChannel: MethodChannel? = null
    private var wavePipChannel: MethodChannel? = null
    private var wavePipEnabled = false
    private var iptvExoPlugin: com.livewave.kurdlogs.live_wave.playback.IptvExoPlayerPlugin? = null

    private val playerBackCallback = object : OnBackPressedCallback(false) {
        override fun handleOnBackPressed() {
            playerBackChannel?.invokeMethod("onBackPressed", null)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // WSA's GPU is "Subsystem OpenGL ES Translator". Flutter 3.47 Impeller
        // starts both Vulkan and OpenGLES there, which leaves previous routes
        // (Home under Settings), ghost cards, and dead hit targets.
        // Real phones/TVs keep Impeller. This does not change layout or navigation.
        if (WsaCompat.isWindowsSubsystemForAndroid()) {
            intent.putExtra(FlutterShellArgs.ARG_KEY_TOGGLE_IMPELLER, false)
            Log.i(tag, "WSA detected — disabling Impeller (Skia GLES), hardware acceleration stays on")
        }
        super.onCreate(savedInstanceState)
    }

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

                if (formatted == "02:00:00:00:00:00" || formatted.startsWith("02:00:00")) {
                    continue
                }

                if (preferred.contains(nif.name.lowercase())) {
                    Log.d(tag, "MAC from ${nif.name}: $formatted")
                    return formatted
                }
                if (fallback == null) fallback = formatted
            }

            if (fallback != null && !fallback.startsWith("02:00:00")) {
                return fallback
            }

            val androidId = android.provider.Settings.Secure.getString(
                contentResolver,
                android.provider.Settings.Secure.ANDROID_ID,
            )
            return androidId ?: "unknown"
        } catch (e: Exception) {
            Log.e(tag, "getMacAddress failed: ${e.message}")
            return "unknown"
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val utilsChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.livewave.player/utils",
        )
        utilsChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getCookies" -> {
                    val url = call.argument<String>("url")
                    val cookieManager = android.webkit.CookieManager.getInstance()
                    result.success(cookieManager.getCookie(url))
                }
                "getMacAddress" -> result.success(getMacAddress())
                else -> result.notImplemented()
            }
        }

        playerBackChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.livewave.player/back",
        )
        playerBackChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "setBackInterceptorEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    playerBackCallback.isEnabled = enabled
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        onBackPressedDispatcher.addCallback(this, playerBackCallback)

        wavePipChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.livewave.wave/pip",
        )
        wavePipChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "setEnabled" -> {
                    wavePipEnabled = call.arguments as? Boolean ?: false
                    updateWavePipParams()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        iptvExoPlugin = com.livewave.kurdlogs.live_wave.playback.IptvExoPlayerPlugin(
            applicationContext,
            flutterEngine,
        ).also { it.register() }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        iptvExoPlugin?.unregister()
        iptvExoPlugin = null
        wavePipEnabled = false
        wavePipChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        enterWavePip()
    }

    override fun onPause() {
        super.onPause()
        if (isInPictureInPictureMode) {
            window.decorView.post { resumeWaveWebViews(window.decorView) }
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        if (isInPictureInPictureMode) {
            window.decorView.post { resumeWaveWebViews(window.decorView) }
        }
        wavePipChannel?.invokeMethod("onPipChanged", isInPictureInPictureMode)
    }

    private fun updateWavePipParams() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        if (!packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)) return
        try {
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(Rational(16, 9))
                .setAutoEnterEnabled(wavePipEnabled)
                .setSeamlessResizeEnabled(true)
                .build()
            setPictureInPictureParams(params)
        } catch (e: Exception) {
            Log.w(tag, "setPictureInPictureParams failed: ${e.message}")
        }
    }

    private fun enterWavePip() {
        if (!wavePipEnabled) return
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (isInPictureInPictureMode) return
        if (!packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)) return
        try {
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(Rational(16, 9))
                .build()
            enterPictureInPictureMode(params)
        } catch (e: Exception) {
            Log.w(tag, "enterPictureInPictureMode failed: ${e.message}")
        }
    }

    private fun resumeWaveWebViews(view: View) {
        if (view is WebView) {
            view.onResume()
            view.resumeTimers()
            return
        }
        if (view is ViewGroup) {
            for (i in 0 until view.childCount) {
                resumeWaveWebViews(view.getChildAt(i))
            }
        }
    }
}
