// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/track.dart';

class GaanaService {
  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
  };

  static const Duration _requestDelay = Duration(milliseconds: 300);

  Future<List<Track>> fetchFromUrl(String url) async {
    print('Gaana: fetching URL $url');
    await Future.delayed(_requestDelay);

    final uri = Uri.parse(url.trim());
    final response = await http.get(uri, headers: _headers);
    print('Gaana: HTTP status ${response.statusCode}');

    if (response.statusCode != 200) {
      throw Exception('Gaana fetch failed: ${response.statusCode}');
    }

    final html = response.body;
    print('Gaana: HTML length ${html.length}');

    List<Track>? tracks = _tryParsePreloadedState(html);

    if (tracks == null || tracks.isEmpty) {
      print('Gaana: PRELOADED_STATE parsing failed or returned empty. Trying fallback Schema.org parser...');
      tracks = _tryParseSchemaOrg(html);
    }

    if (tracks == null || tracks.isEmpty) {
      throw Exception('Failed to find Gaana data in HTML (both PRELOADED_STATE and Schema.org failed)');
    }

    print('Gaana: Tracks found: ${tracks.length}');
    if (tracks.isNotEmpty) {
      print('First track raw: ${tracks.first}');
    }

    return tracks;
  }

  List<Track>? _tryParsePreloadedState(String html) {
    Map<String, dynamic>? preloadedJson;

    // Attempt regex extraction
    final regex = RegExp(r'window\.__PRELOADED_STATE__\s*=\s*(\{[\s\S]*?)(?=\s*window\.|<\/script>)', caseSensitive: false);
    final match = regex.firstMatch(html);

    if (match != null) {
      try {
        preloadedJson = jsonDecode(match.group(1)!);
      } catch (e) {
        print('Gaana: Regex JSON parse failed: $e');
      }
    }

    // Fallback brace scanning if regex failed
    if (preloadedJson == null) {
      final searchStr = 'window.__PRELOADED_STATE__ =';
      int idx = html.indexOf(searchStr);
      if (idx == -1) {
        idx = html.indexOf('window.__PRELOADED_STATE__=');
      }

      if (idx != -1) {
        int startIdx = html.indexOf('{', idx);
        if (startIdx != -1) {
          int openBraces = 0;
          int endIdx = -1;
          for (int i = startIdx; i < html.length; i++) {
            if (html[i] == '{') {
              openBraces++;
            } else if (html[i] == '}') {
              openBraces--;
              if (openBraces == 0) {
                endIdx = i;
                break;
              }
            }
          }
          if (endIdx != -1) {
            try {
              preloadedJson = jsonDecode(html.substring(startIdx, endIdx + 1));
            } catch (e) {
              print('Gaana: Brace scanner JSON parse failed: $e');
            }
          }
        }
      }
    }

    if (preloadedJson == null) return null;

    print("PRELOADED_STATE keys: ${preloadedJson.keys.toList()}");

    List<dynamic>? rawTracks;
    String pathUsed = '';

    if (preloadedJson['playlist']?['playlistData']?['tracks'] != null) {
      rawTracks = preloadedJson['playlist']['playlistData']['tracks'] as List<dynamic>?;
      pathUsed = 'playlist.playlistData.tracks';
    } else if (preloadedJson['playlist']?['tracks'] != null) {
      rawTracks = preloadedJson['playlist']['tracks'] as List<dynamic>?;
      pathUsed = 'playlist.tracks';
    } else if (preloadedJson['playlistDetails']?['tracks'] != null) {
      rawTracks = preloadedJson['playlistDetails']['tracks'] as List<dynamic>?;
      pathUsed = 'playlistDetails.tracks';
    } else if (preloadedJson['entityData']?['tracks'] != null) {
      rawTracks = preloadedJson['entityData']['tracks'] as List<dynamic>?;
      pathUsed = 'entityData.tracks';
    } else if (preloadedJson['entityInfo'] != null) {
      final ei = preloadedJson['entityInfo'];
      if (ei['track_id'] != null || ei['id'] != null) {
        rawTracks = [ei];
        pathUsed = 'entityInfo (single track)';
      }
    }

    if (rawTracks == null || rawTracks.isEmpty) return null;

    print("Tracks path found: $pathUsed");
    print("First track raw (preloaded json object): ${rawTracks.first}");

    return rawTracks.asMap().entries.map((entry) {
      final index = entry.key;
      final t = entry.value as Map<String, dynamic>;

      final title = t['title']?.toString() ?? 'Unknown';
      final artistRaw = t['artist']?.toString() ?? t['singers']?.toString() ?? '';
      final artists = artistRaw.split(',').map((a) => a.trim()).toList();
      final album = t['albumTitle']?.toString() ?? t['album']?.toString() ?? '';
      final coverArtUrl = t['atw']?.toString() ?? '';
      final trackId = t['track_id']?.toString() ?? t['id']?.toString() ?? t['seokey']?.toString() ?? '';

      final durationRaw = t['duration']?.toString() ?? '0';
      int durationSecs = 0;
      if (durationRaw.contains(':')) {
        final parts = durationRaw.split(':');
        if (parts.length == 2) {
          durationSecs = (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
        }
      } else {
        durationSecs = int.tryParse(durationRaw) ?? 0;
      }

      return Track(
        id: trackId,
        title: title,
        artists: artists,
        album: album,
        coverArtUrl: coverArtUrl,
        durationMs: durationSecs * 1000,
        trackNumber: index + 1,
        discNumber: 1,
      );
    }).where((t) => t.id.isNotEmpty).toList();
  }

  List<Track>? _tryParseSchemaOrg(String html) {
    final scriptTags = RegExp(r'<script[^>]*>(.*?)<\/script>', caseSensitive: false, dotAll: true).allMatches(html);
    Map<String, dynamic>? schemaJson;

    for (final match in scriptTags) {
      final content = match.group(1) ?? '';
      if (content.contains('"@type":"MusicPlaylist"') || content.contains('"@type": "MusicPlaylist"')) {
        try {
          schemaJson = jsonDecode(content);
          break;
        } catch (e) {
          print('Gaana: Schema.org JSON parse failed: $e');
        }
      }
    }

    if (schemaJson == null) return null;

    final rawTracks = schemaJson['track'] as List<dynamic>?;
    if (rawTracks == null || rawTracks.isEmpty) return null;

    print("Tracks path found: Schema.org 'track' list");
    print("First track raw (schema json object): ${rawTracks.first}");

    return rawTracks.asMap().entries.map((entry) {
      final index = entry.key;
      final t = entry.value as Map<String, dynamic>;

      final title = t['name']?.toString() ?? 'Unknown';

      String artist = '';
      if (t['byArtist'] != null) {
        if (t['byArtist'] is Map) {
          artist = t['byArtist']['name']?.toString() ?? '';
        } else if (t['byArtist'] is List && (t['byArtist'] as List).isNotEmpty) {
          artist = (t['byArtist'] as List).first['name']?.toString() ?? '';
        }
      }

      final url = t['url']?.toString() ?? '';
      String trackId = '';
      if (url.isNotEmpty) {
        final uri = Uri.tryParse(url);
        if (uri != null && uri.pathSegments.isNotEmpty) {
          trackId = uri.pathSegments.last;
        }
      }

      final coverArtUrl = t['image']?.toString() ?? '';

      return Track(
        id: trackId,
        title: title,
        artists: [artist].where((a) => a.isNotEmpty).toList(),
        album: '',
        coverArtUrl: coverArtUrl,
        durationMs: 0,
        trackNumber: index + 1,
        discNumber: 1,
      );
    }).where((t) => t.id.isNotEmpty).toList();
  }
}
