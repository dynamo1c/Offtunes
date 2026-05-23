/// Debug script — dumps the raw HTML from a Spotify page so we can inspect
/// the actual script tag that holds the embedded JSON data.
///
/// Usage:
///   dart run tool/debug_spotify_html.dart SPOTIFY_URL
library;

import 'dart:io';
import 'package:http/http.dart' as http;

const _headers = {
  'User-Agent':
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
  'Accept':
      'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  'Accept-Language': 'en-US,en;q=0.5',
};

void main(List<String> args) async {
  final url = args.isNotEmpty
      ? args[0]
      : 'https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC';

  stdout.writeln('Fetching: $url');
  final response = await http.get(Uri.parse(url), headers: _headers);
  stdout.writeln('HTTP status: ${response.statusCode}');

  final html = response.body;
  stdout.writeln('Body length: ${html.length} chars\n');

  // ── Find all <script ...> tags and print their first 120 chars ───────────
  stdout.writeln('=== All <script> tags found ===');
  final scriptRe = RegExp(r'<script[^>]*>', caseSensitive: false);
  final matches = scriptRe.allMatches(html).toList();
  stdout.writeln('Total <script> tags: ${matches.length}');
  for (final m in matches) {
    final tag = m.group(0)!;
    stdout.writeln('  $tag');
  }

  // ── Dump any script tag whose opening tag contains "State" or "state" ────
  stdout.writeln('\n=== Script tags containing "state" (case-insensitive) ===');
  final stateRe = RegExp(
    r'<script[^>]*state[^>]*>(.*?)</script>',
    caseSensitive: false,
    dotAll: true,
  );
  final stateMatches = stateRe.allMatches(html).toList();
  stdout.writeln('Found: ${stateMatches.length}');
  for (final m in stateMatches) {
    stdout.writeln('  Opening tag : ${m.group(0)!.substring(0, m.group(0)!.indexOf('>') + 1)}');
    final content = m.group(1) ?? '';
    stdout.writeln('  Content (first 200 chars): ${content.substring(0, content.length.clamp(0, 200))}');
    stdout.writeln();
  }

  // ── Also look for __NEXT_DATA__ which Next.js apps use ──────────────────
  stdout.writeln('=== __NEXT_DATA__ script tag ===');
  final nextRe = RegExp(
    '<script[^>]*id=["\']__NEXT_DATA__["\'][^>]*>(.*?)</script>',
    caseSensitive: false,
    dotAll: true,
  );
  final nextMatch = nextRe.firstMatch(html);
  if (nextMatch != null) {
    final content = nextMatch.group(1) ?? '';
    stdout.writeln('Found! Content (first 500 chars):');
    stdout.writeln(content.substring(0, content.length.clamp(0, 500)));
  } else {
    stdout.writeln('Not found.');
  }

  // ── Save full HTML to disk for manual inspection ─────────────────────────
  final outFile = File('tool/spotify_debug.html');
  outFile.writeAsStringSync(html);
  stdout.writeln('\n✅  Full HTML saved to: ${outFile.absolute.path}');
  stdout.writeln('    Open it in a browser or text editor to inspect.');
}
