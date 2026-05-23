package com.oddtunes.oddtunes_app

import android.os.Handler
import android.os.Looper
import android.util.Log
import com.chaquo.python.Python
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

private const val TAG = "YtDlpBridge"

/**
 * Bridges Flutter MethodChannel calls to yt-dlp running via Chaquopy (Python 3.13).
 *
 * Thread safety: all result callbacks are posted to the main looper
 * so Flutter's platform channel contract is satisfied.
 */
class YtDlpBridge : MethodChannel.MethodCallHandler {

    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "download" -> {
                val videoId   = call.argument<String>("videoId")
                val outputDir = call.argument<String>("outputDir")
                val filename  = call.argument<String>("filename")

                if (videoId == null || outputDir == null || filename == null) {
                    result.error("INVALID_ARGS", "videoId, outputDir and filename required", null)
                    return
                }

                // Run on background thread — Python + network I/O
                Thread {
                    try {
                        val py = Python.getInstance()
                        val module = py.getModule("ytdlp_bridge")

                        Log.i(TAG, "Starting download: $videoId → $outputDir/$filename")

                        val jsonResult = module.callAttr(
                            "download_audio",
                            videoId,
                            outputDir,
                            filename
                        ).toString()

                        Log.i(TAG, "Python returned: $jsonResult")

                        val json = JSONObject(jsonResult)
                        val status = json.getString("status")

                        if (status == "ok") {
                            val path = json.getString("path")
                            Log.i(TAG, "Success: $path")
                            mainHandler.post { result.success(path) }
                        } else {
                            val message = json.optString("message", "Unknown error")
                            Log.e(TAG, "yt-dlp error: $message")
                            mainHandler.post {
                                result.error("YTDLP_ERROR", message, null)
                            }
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Bridge error: ${e.message}", e)
                        mainHandler.post {
                            result.error("BRIDGE_ERROR", e.message ?: "Unknown error", null)
                        }
                    }
                }.start()
            }

            "version" -> {
                Thread {
                    try {
                        val py = Python.getInstance()
                        val module = py.getModule("ytdlp_bridge")
                        val jsonResult = module.callAttr("get_version").toString()
                        mainHandler.post { result.success(jsonResult) }
                    } catch (e: Exception) {
                        mainHandler.post {
                            result.error("VERSION_ERROR", e.message, null)
                        }
                    }
                }.start()
            }

            else -> result.notImplemented()
        }
    }
}
