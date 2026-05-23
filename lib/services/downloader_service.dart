import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class DownloaderService {
  // Android: delegates to Chaquopy Python (yt-dlp) via MethodChannel
  static const _ytdlpChannel = MethodChannel('com.oddtunes/ytdlp');

  // Windows: tracks the active Process for cancellation
  Process? _activeProcess;

  /// Downloads audio for [youtubeVideoId] into [outputDir]/[filename].m4a
  /// Returns the absolute path of the downloaded file, or null on failure.
  Future<String?> downloadAudio({
    required String youtubeVideoId,
    required String outputDir,
    required String filename,
    void Function(double progress)? onProgress,
  }) async {
    if (Platform.isAndroid) {
      return _downloadAndroid(
        youtubeVideoId: youtubeVideoId,
        outputDir: outputDir,
        filename: filename,
        onProgress: onProgress,
      );
    } else if (Platform.isWindows) {
      return _downloadWindows(
        youtubeVideoId: youtubeVideoId,
        outputDir: outputDir,
        filename: filename,
        onProgress: onProgress,
      );
    }
    throw Exception('Unsupported platform: ${Platform.operatingSystem}');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Android: Chaquopy Python + yt-dlp via MethodChannel
  // ─────────────────────────────────────────────────────────────────────────

  Future<String?> _downloadAndroid({
    required String youtubeVideoId,
    required String outputDir,
    required String filename,
    void Function(double progress)? onProgress,
  }) async {
    debugPrint('DownloaderService[Android]: invoking yt-dlp for $youtubeVideoId');

    try {
      final String? path = await _ytdlpChannel.invokeMethod('download', {
        'videoId': youtubeVideoId,
        'outputDir': outputDir,
        'filename': filename,
      });

      debugPrint('DownloaderService[Android]: result path = $path');
      return path;
    } on PlatformException catch (e) {
      debugPrint('DownloaderService[Android]: PlatformException ${e.code}: ${e.message}');
      throw Exception('yt-dlp failed: ${e.message}');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Windows: bundled yt-dlp.exe via Process
  // ─────────────────────────────────────────────────────────────────────────

  Future<String?> _downloadWindows({
    required String youtubeVideoId,
    required String outputDir,
    required String filename,
    void Function(double progress)? onProgress,
  }) async {
    final binaryPath = await _getWindowsBinaryPath();
    final outputTemplate = '$outputDir/$filename.%(ext)s';

    final args = [
      '--no-playlist',
      '-x',
      '--audio-format', 'm4a',
      '--audio-quality', '0',
      '-o', outputTemplate,
      '--no-mtime',
      '--no-warnings',
      '--retries', '3',
      '--fragment-retries', '3',
      '--retry-sleep', '2',
    ];

    if (Platform.isAndroid) {
      args.addAll([
        '--extractor-args', 
        'youtube:player_client=android,web',
      ]);
    }

    args.add('https://www.youtube.com/watch?v=$youtubeVideoId');

    debugPrint('DownloaderService[Windows]: starting yt-dlp for $youtubeVideoId');
    final process = await Process.start(binaryPath, args);
    _activeProcess = process;

    final progressRegex = RegExp(r'\[download\]\s+([\d\.]+)%');

    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      debugPrint('yt-dlp: $line');
      final match = progressRegex.firstMatch(line);
      if (match != null) {
        final percent = double.tryParse(match.group(1)!) ?? 0;
        onProgress?.call(percent / 100);
      }
    });

    final stderr = await process.stderr.transform(utf8.decoder).join();
    final exitCode = await process.exitCode;
    _activeProcess = null;

    if (exitCode != 0) {
      debugPrint('DownloaderService[Windows]: yt-dlp stderr: $stderr');
      throw Exception('yt-dlp failed (exit $exitCode): $stderr');
    }

    // Find output file
    final m4aFile = File('$outputDir/$filename.m4a');
    if (m4aFile.existsSync()) return m4aFile.path;

    // Fallback: scan directory for any file matching the filename prefix
    final dir = Directory(outputDir);
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains(filename))
        .toList();

    if (files.isNotEmpty) return files.first.path;

    debugPrint('DownloaderService[Windows]: no output file found for "$filename"');
    return null;
  }

  Future<String> _getWindowsBinaryPath() async {
    final supportDir = await getApplicationSupportDirectory();
    final binaryFile = File('${supportDir.path}/yt-dlp.exe');
    if (!binaryFile.existsSync()) {
      final data = await rootBundle.load('assets/binaries/yt-dlp.exe');
      await binaryFile.writeAsBytes(data.buffer.asUint8List());
    }
    return binaryFile.path;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Cancellation
  // ─────────────────────────────────────────────────────────────────────────

  void cancelDownload() {
    if (_activeProcess != null) {
      debugPrint('DownloaderService: killing active process');
      _activeProcess!.kill(ProcessSignal.sigterm);
      _activeProcess = null;
    }
  }
}
