# Ignore missing Play Core classes referenced by Flutter's deferred components
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
-dontwarn com.google.android.play.core.**

# Keep Flutter wrapper classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep our MainActivity and MethodChannel
-keep class com.oddtunes.** { *; }

# Keep ffmpeg_kit classes
-keep class com.arthenica.ffmpegkit.** { *; }

# Keep just_audio classes
-keep class com.ryanheise.** { *; }

# Prevent stripping of native method names
-keepclasseswithmembernames class * {
  native <methods>;
}
