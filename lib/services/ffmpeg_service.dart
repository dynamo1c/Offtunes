import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:http/http.dart' as http;
import '../models/track.dart';

/// TODO: IMPORTANT SETUP REQUIRED FOR WINDOWS
/// Please manually download `ffmpeg.exe` (essentials build) and place it in `assets/binaries/`.
/// Download from: https://www.gyan.dev/ffmpeg/builds/
class FfmpegService {
  String? _windowsBinaryPath;

  /// Retrieves the path to the bundled ffmpeg.exe on Windows.
  /// On first run, it copies it from assets to the app's internal storage.
  Future<String?> getWindowsBinaryPath() async {
    if (!Platform.isWindows) return null;
    if (_windowsBinaryPath != null && await File(_windowsBinaryPath!).exists()) {
      return _windowsBinaryPath!;
    }

    final supportDir = await getApplicationSupportDirectory();
    final binaryFile = File('${supportDir.path}/ffmpeg.exe');

    if (!await binaryFile.exists()) {
      final data = await rootBundle.load('assets/binaries/ffmpeg.exe');
      final bytes = data.buffer.asUint8List();
      await binaryFile.writeAsBytes(bytes, flush: true);
    }

    _windowsBinaryPath = binaryFile.path;
    return _windowsBinaryPath!;
  }

  /// Helper to run an FFmpeg command natively on the correct platform.
  Future<void> _runCommand(List<String> args) async {
    if (Platform.isAndroid || Platform.isIOS) {
      // Use FFmpegKit on mobile
      final session = await FFmpegKit.executeWithArguments(args);
      final returnCode = await session.getReturnCode();
      if (!ReturnCode.isSuccess(returnCode)) {
        final logs = await session.getLogsAsString();
        throw Exception("FFmpegKit failed: $logs");
      }
    } else if (Platform.isWindows) {
      // Use bundled executable on Windows
      final binPath = await getWindowsBinaryPath();
      if (binPath == null) throw Exception("ffmpeg.exe not available");
      final result = await Process.run(binPath, args);
      if (result.exitCode != 0) {
        throw Exception("ffmpeg.exe failed: ${result.stderr}");
      }
    } else {
      throw Exception("Unsupported platform for FFmpeg");
    }
  }

  // ── Primary Pipeline (M4A — stream copy, near-instant) ──────────────────

  /// Complete pipeline for M4A: Embeds metadata and cover art via stream copy
  /// in a single FFmpeg pass. No re-encoding — preserves original quality.
  /// Cleans up the original raw file afterwards.
  Future<String> processAudio({
    required String rawM4aPath,
    required Track track,
    required String outputDir,
  }) async {
    final safeFilename = track.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final outputPath = '$outputDir${Platform.pathSeparator}$safeFilename.m4a';
    String? coverTempPath;

    try {
      // Download cover art to a temp file if available
      if (track.coverArtUrl.isNotEmpty) {
        try {
          final response = await http.get(Uri.parse(track.coverArtUrl));
          if (response.statusCode == 200) {
            coverTempPath =
                '$outputDir${Platform.pathSeparator}cover_temp_${safeFilename.hashCode}.jpg';
            await File(coverTempPath).writeAsBytes(response.bodyBytes);
          }
        } catch (e) {
          debugPrint('FfmpegService: cover art download failed — $e');
        }
      }

      final isM4a = rawM4aPath.toLowerCase().endsWith('.m4a') || rawM4aPath.toLowerCase().endsWith('.mp4');
      final audioCodec = isM4a ? 'copy' : 'aac';

      // Build a single FFmpeg command that stream-copies audio and
      // embeds metadata + cover art in one pass.
      final args = <String>[
        '-hide_banner',
        '-i', rawM4aPath,
      ];

      if (coverTempPath != null && await File(coverTempPath).exists()) {
        args.addAll(['-i', coverTempPath]);
        // Map audio from input 0, cover from input 1
        args.addAll([
          '-map', '0:a',
          '-map', '1:v',
          '-c:a', audioCodec,
          '-c:v', 'mjpeg',
          '-disposition:v:0', 'attached_pic',
        ]);
      } else {
        // No cover art — just copy the audio stream
        args.addAll([
          '-map', '0:a',
          '-c:a', audioCodec,
        ]);
      }

      // Metadata tags
      args.addAll([
        '-metadata', 'title=${track.title}',
        '-metadata', 'artist=${track.artistString}',
        '-metadata', 'album=${track.album}',
        '-metadata', 'track=${track.trackNumber}',
        '-metadata', 'disc=${track.discNumber}',
        '-y',
        outputPath,
      ]);

      await _runCommand(args);

      return outputPath;
    } finally {
      // Clean up temp files
      final rawFile = File(rawM4aPath);
      if (await rawFile.exists()) {
        await rawFile.delete();
      }
      if (coverTempPath != null) {
        final coverFile = File(coverTempPath);
        if (await coverFile.exists()) {
          await coverFile.delete();
        }
      }
    }
  }

  // ── MP3 Conversion (user-triggered from Settings) ───────────────────────

  /// Converts an M4A file to MP3 with loudness normalization.
  /// Used by the Convert feature in Settings, NOT during the download pipeline.
  Future<String> convertToMp3({
    required String inputPath,
    required String outputDir,
    required String filename,
    int bitrate = 192,
  }) async {
    final outputPath = '$outputDir${Platform.pathSeparator}$filename.mp3';

    final args = [
      '-i', inputPath,
      '-acodec', 'libmp3lame',
      '-b:a', '${bitrate}k',
      '-af', 'loudnorm=I=-14:LRA=11:TP=-1',
      '-y',
      outputPath,
    ];

    await _runCommand(args);
    return outputPath;
  }
}

