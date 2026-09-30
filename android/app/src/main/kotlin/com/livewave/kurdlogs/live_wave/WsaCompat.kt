package com.livewave.kurdlogs.live_wave

import android.os.Build

/**
 * Windows Subsystem for Android is a windowed x86_64 Android 13 environment
 * whose GPU is a GLES translator (not a real mobile GPU).
 *
 * Do not use this to change TV/phone layout — only for renderer compatibility.
 */
object WsaCompat {
    fun isWindowsSubsystemForAndroid(): Boolean {
        val tokens = listOf(
            Build.HARDWARE,
            Build.PRODUCT,
            Build.DEVICE,
            Build.MODEL,
            Build.FINGERPRINT,
            Build.BOARD,
        ).joinToString(" ").lowercase()
        return tokens.contains("windows_x86_64") ||
            tokens.contains("windows_ia32") ||
            tokens.contains("subsystem for android")
    }
}
