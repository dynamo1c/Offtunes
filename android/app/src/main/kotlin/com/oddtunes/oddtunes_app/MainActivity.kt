package com.oddtunes.oddtunes_app

import android.util.Log
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val TAG = "MainActivity"

class MainActivity : AudioServiceActivity() {

    private val NATIVE_LIB_CHANNEL = "com.oddtunes/native_lib"
    private val YTDLP_CHANNEL = "com.oddtunes/ytdlp"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize Chaquopy Python runtime (idempotent — safe to call multiple times)
        if (!Python.isStarted()) {
            Python.start(AndroidPlatform(this))
            Log.i(TAG, "Python started via Chaquopy")

            // Log yt-dlp version for diagnostics
            try {
                val py = Python.getInstance()
                val module = py.getModule("ytdlp_bridge")
                val versionInfo = module.callAttr("get_version").toString()
                Log.i(TAG, "yt-dlp info: $versionInfo")
            } catch (e: Exception) {
                Log.w(TAG, "Could not query yt-dlp version: ${e.message}")
            }
        }

        // Channel: yt-dlp downloads via Chaquopy Python
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            YTDLP_CHANNEL
        ).setMethodCallHandler(YtDlpBridge())

        // Channel: native library dir (kept for legacy compatibility)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NATIVE_LIB_CHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method == "getNativeLibraryDir") {
                result.success(applicationInfo.nativeLibraryDir)
            } else {
                result.notImplemented()
            }
        }
    }
}
