/// Helper / utility functions for the Oddtunes application.
library;

import 'dart:convert';
import 'package:crypto/crypto.dart';

class AppUtils {
  AppUtils._(); // prevent instantiation

  // ── String helpers ────────────────────────────────────────────────────────

  /// Sanitizes a string so it can be safely used as a file-system name.
  static String sanitizeFilename(String input) {
    return input
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Converts milliseconds to a human-readable duration string (e.g. "3:45").
  static String formatDuration(int ms) {
    final duration = Duration(milliseconds: ms);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // ── Crypto helpers ────────────────────────────────────────────────────────

  /// Returns the MD5 hex digest of [input]. Useful for cache key generation.
  static String md5Hex(String input) {
    return md5.convert(utf8.encode(input)).toString();
  }

  // ── JSON helpers ──────────────────────────────────────────────────────────

  /// Safely parses a JSON string; returns null on any error.
  static Map<String, dynamic>? tryParseJson(String raw) {
    try {
      return json.decode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ── Numeric helpers ───────────────────────────────────────────────────────

  /// Clamps [value] between [min] and [max].
  static T clamp<T extends num>(T value, T min, T max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}
