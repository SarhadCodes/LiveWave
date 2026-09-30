# Live playback uses Media3 ExoPlayer with DefaultRenderersFactory (hardware MediaCodec).
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**
-keep class com.livewave.kurdlogs.live_wave.music.** { *; }

# NewPipe Extractor v0.26.5 uses Mozilla Rhino to run YouTube player scripts.
-keep class org.mozilla.javascript.** { *; }
-keep class org.mozilla.classfile.ClassFileWriter
-dontwarn org.mozilla.javascript.**
-dontwarn jdk.dynalink.**
-keep class org.schabi.newpipe.extractor.** { *; }
-dontwarn org.schabi.newpipe.extractor.**
