/// Quick CLI tester for SpotifyService.
///
/// Usage:
///   dart run tool/test_spotify.dart SPOTIFY_URL
///
/// Examples:
///   dart run tool/test_spotify.dart https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC
///   dart run tool/test_spotify.dart https://open.spotify.com/album/4aawyAB9vmqN3uQ7FjRGTy
///   dart run tool/test_spotify.dart https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M
library;

import 'dart:io';
// Add the lib directory to the import path via a relative import.
// ignore: avoid_relative_lib_imports
import '../lib/services/spotify_service.dart';
// ignore: avoid_relative_lib_imports
import '../lib/models/track.dart';

void main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/test_spotify.dart <spotify_url>\n'
      '\nExamples:\n'
      '  dart run tool/test_spotify.dart https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC\n'
      '  dart run tool/test_spotify.dart https://open.spotify.com/album/4aawyAB9vmqN3uQ7FjRGTy\n'
      '  dart run tool/test_spotify.dart https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M',
    );
    exit(1);
  }

  final url = args[0];
  final service = SpotifyService();

  // ── 1. Detect URL type ───────────────────────────────────────────────────
  late final String urlType;
  try {
    urlType = service.detectUrlType(url);
    _header('URL type detected');
    _kv('Type', urlType);
    _kv('URL', url);
  } catch (e) {
    stderr.writeln('❌  detectUrlType failed: $e');
    exit(1);
  }

  // ── 2. Fetch ─────────────────────────────────────────────────────────────
  _header('Fetching from Spotify (no API key)…');
  late final List<Track> tracks;
  final stopwatch = Stopwatch()..start();

  try {
    tracks = await service.fetchFromUrl(url);
    stopwatch.stop();
  } catch (e) {
    stopwatch.stop();
    stderr.writeln('❌  Fetch failed after ${stopwatch.elapsedMilliseconds}ms');
    stderr.writeln('    $e');
    exit(1);
  }

  _header(
    'Results — ${tracks.length} track(s) '
    '[${stopwatch.elapsedMilliseconds}ms]',
  );

  if (tracks.isEmpty) {
    stderr.writeln('⚠️   No tracks returned — the page structure may have changed.');
    exit(1);
  }

  for (var i = 0; i < tracks.length; i++) {
    final t = tracks[i];
    _divider();
    _kv('#', '${i + 1}');
    _kv('ID', t.id);
    _kv('Title', t.title);
    _kv('Artists', t.artistString);
    _kv('Album', t.album);
    _kv('Duration', _fmtMs(t.durationMs));
    _kv('Track #', '${t.trackNumber}  disc ${t.discNumber}');
    _kv('Cover art', t.coverArtUrl.isNotEmpty ? t.coverArtUrl : '(none)');
  }
  _divider();

  stdout.writeln('\n✅  Done — ${tracks.length} track(s) fetched successfully.');
}

// ── Formatting helpers ────────────────────────────────────────────────────────

void _header(String text) {
  stdout.writeln('\n╔══ $text');
}

void _divider() {
  stdout.writeln('──────────────────────────────────────────────');
}

void _kv(String key, String value) {
  stdout.writeln('  ${key.padRight(10)} $value');
}

String _fmtMs(int ms) {
  if (ms <= 0) return '0:00';
  final d = Duration(milliseconds: ms);
  final m = d.inMinutes;
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}
