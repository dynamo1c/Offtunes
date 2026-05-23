/// Spotify scraping service.
///
/// Fetches track/album/playlist data from open.spotify.com by:
///   1. Sending a GET request with a mobile Chrome User-Agent.
///   2. Extracting the `<script id="initialState">` tag from the HTML.
///   3. Base64-decoding the tag's text content.
///   4. Parsing the resulting JSON to build [Track] objects.
///
/// No Spotify API credentials are required.
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/track.dart';

class SpotifyService {
  // ── HTTP headers ──────────────────────────────────────────────────────────

  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
  };

  static const Duration _requestDelay = Duration(milliseconds: 500);

  // ── Public API ────────────────────────────────────────────────────────────

  /// Detects whether [url] points to a track, album, or playlist.
  ///
  /// Returns `"track"`, `"album"`, or `"playlist"`.
  /// Throws [Exception] if the URL does not match a known Spotify type.
  String detectUrlType(String url) {
    final uri = Uri.parse(url.trim());
    final segments = uri.pathSegments;
    if (segments.isEmpty) {
      throw Exception('Invalid Spotify URL: $url');
    }
    final type = segments.first.toLowerCase();
    if (type == 'track' || type == 'album' || type == 'playlist') {
      return type;
    }
    throw Exception(
      'Unsupported Spotify URL type "$type". '
      'Expected track, album, or playlist.',
    );
  }

  /// Master entry point: detects the URL type and delegates to the correct
  /// fetch method.
  ///
  /// Always returns a [List<Track>] — a single track is wrapped in a list.
  Future<List<Track>> fetchFromUrl(String url) async {
    final type = detectUrlType(url);
    switch (type) {
      case 'track':
        final track = await fetchTrack(url);
        return [track];
      case 'album':
        return fetchAlbum(url);
      case 'playlist':
        return fetchPlaylist(url);
      default:
        throw Exception('Unsupported URL type: $type');
    }
  }

  /// Fetches a single [Track] from a Spotify track URL.
  ///
  /// Example: `https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC`
  Future<Track> fetchTrack(String spotifyTrackUrl) async {
    final html = await _fetchHtml(spotifyTrackUrl);
    final data = _extractInitialState(html);

    // Track pages store entries under data["entities"]["tracks"]
    final tracks = _parseTracksFromEntities(data);
    if (tracks.isEmpty) {
      throw Exception('Could not find track data in Spotify page');
    }
    return tracks.first;
  }

  /// Fetches all tracks from a Spotify album URL.
  ///
  /// Example: `https://open.spotify.com/album/4aawyAB9vmqN3uQ7FjRGTy`
  Future<List<Track>> fetchAlbum(String spotifyAlbumUrl) async {
    final html = await _fetchHtml(spotifyAlbumUrl);
    final data = _extractInitialState(html);
    final tracks = _parseTracksFromEntities(data);
    if (tracks.isEmpty) {
      throw Exception('Could not find track data in Spotify page');
    }
    return tracks;
  }

  /// Fetches up to 30 tracks from a Spotify playlist URL.
  ///
  /// Example: `https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M`
  Future<List<Track>> fetchPlaylist(String spotifyPlaylistUrl) async {
    final html = await _fetchHtml(spotifyPlaylistUrl);
    final data = _extractInitialState(html);
    final tracks = _parseTracksFromEntities(data);
    if (tracks.isEmpty) {
      throw Exception('Could not find track data in Spotify page');
    }
    // The initialState for playlists contains at most ~30 tracks.
    return tracks.take(30).toList();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// GETs [url] with the mobile Chrome User-Agent and returns the HTML body.
  ///
  /// Automatically strips query parameters (e.g. `?si=…` mobile share tokens)
  /// before fetching — they trigger a Branch.io redirect instead of the page.
  ///
  /// Applies a [_requestDelay] before the request to be polite to the server.
  Future<String> _fetchHtml(String url) async {
    await Future.delayed(_requestDelay);

    // Strip query params — ?si= etc. cause Branch.io redirects.
    final uri = Uri.parse(url.trim()).replace(query: '');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode != 200) {
      throw Exception(
        'Spotify fetch failed: ${response.statusCode} for $url',
      );
    }
    return response.body;
  }

  /// Finds `<script id="initialState" …>…</script>` in [html], Base64-decodes
  /// the content, and JSON-decodes the result.
  ///
  /// The actual tag Spotify emits is:
  ///   `<script id="initialState" type="text/plain">…</script>`
  /// so we match on `id="initialState"` anywhere inside the opening tag.
  ///
  /// Throws [Exception] if the tag is missing or decoding/parsing fails.
  Map<String, dynamic> _extractInitialState(String html) {
    // Match the opening tag with id="initialState" (attributes may vary).
    final openTagRe = RegExp(
      '<script[^>]*id="initialState"[^>]*>',
      caseSensitive: false,
    );

    const closeTag = '</script>';

    final openMatch = openTagRe.firstMatch(html);
    if (openMatch == null) {
      throw Exception('Could not find track data in Spotify page');
    }

    final contentStart = openMatch.end;
    final endIndex = html.indexOf(closeTag, contentStart);
    if (endIndex == -1) {
      throw Exception('Could not find track data in Spotify page');
    }

    final base64Content = html.substring(contentStart, endIndex).trim();

    // Base64-decode → UTF-8 JSON string.
    late final String jsonString;
    try {
      final decoded = base64Decode(base64Content);
      jsonString = utf8.decode(decoded);
    } catch (e) {
      throw Exception('Failed to parse Spotify data: base64/utf8 error — $e');
    }

    // JSON-decode → Map.
    try {
      final dynamic parsed = jsonDecode(jsonString);
      if (parsed is! Map<String, dynamic>) {
        throw Exception('Failed to parse Spotify data: unexpected root type');
      }
      return parsed;
    } catch (e) {
      throw Exception('Failed to parse Spotify data: $e');
    }
  }

  /// Walks the decoded initialState [data] map and collects all track entries.
  ///
  /// Handles all three Spotify page types, verified against live responses:
  ///
  /// TRACK page — `entities.items["spotify:track:ID"].__typename == "Track"`
  ///   Artists at `firstArtist.items[].profile.name` + `otherArtists`.
  ///
  /// ALBUM page — `entities.items["spotify:album:ID"].__typename == "Album"`
  ///   Tracks at `tracksV2.items[].track`, artists at `artists.items[].profile.name`.
  ///
  /// PLAYLIST page — `entities.items["spotify:playlist:ID"].__typename == "Playlist"`
  ///   Tracks at `content.items[].itemV2.data`, artists at `artists.items[].profile.name`.
  List<Track> _parseTracksFromEntities(Map<String, dynamic> data) {
    final tracks = <Track>[];
    final seen = <String>{}; // dedup by track id

    void add(Track? t) {
      if (t != null && seen.add(t.id)) tracks.add(t);
    }

    try {
      final entities = data['entities'] as Map<String, dynamic>?;
      if (entities == null) return tracks;

      final items = entities['items'] as Map<String, dynamic>?;
      if (items == null) return tracks;

      for (final entry in items.values) {
        final m = entry as Map<String, dynamic>?;
        if (m == null) continue;

        switch (m['__typename'] as String?) {
          // ── TRACK page ──────────────────────────────────────────────────
          case 'Track':
            add(_trackFromModernEntry(m));
            // Also pull sibling tracks from albumOfTrack.tracks.items
            final albumObj = m['albumOfTrack'] as Map<String, dynamic>?;
            final albumItems =
                (albumObj?['tracks'] as Map<String, dynamic>?)?['items']
                    as List<dynamic>?;
            for (final item in albumItems ?? []) {
              final node = (item as Map<String, dynamic>?)?['track']
                  as Map<String, dynamic>?;
              if (node != null) {
                add(_trackFromModernEntry(_enrichSiblingTrack(node, albumObj)));
              }
            }

          // ── ALBUM page ──────────────────────────────────────────────────
          case 'Album':
            final albumName = m['name'] as String? ?? '';
            final coverArtObj = m['coverArt'] as Map<String, dynamic>? ?? {};
            final trackItems =
                (m['tracksV2'] as Map<String, dynamic>?)?['items']
                    as List<dynamic>? ??
                [];
            for (final item in trackItems) {
              final node = (item as Map<String, dynamic>?)?['track']
                  as Map<String, dynamic>?;
              if (node == null) continue;
              add(_trackFromModernEntry({
                ...node,
                'albumOfTrack': {'name': albumName, 'coverArt': coverArtObj},
              }));
            }

          // ── PLAYLIST page ───────────────────────────────────────────────
          case 'Playlist':
            final contentItems =
                (m['content'] as Map<String, dynamic>?)?['items']
                    as List<dynamic>? ??
                [];
            for (final item in contentItems) {
              final itemV2 = (item as Map<String, dynamic>?)?['itemV2']
                  as Map<String, dynamic>?;
              if (itemV2?['__typename'] != 'TrackResponseWrapper') continue;
              final d = itemV2!['data'] as Map<String, dynamic>?;
              if (d == null) continue;
              add(_trackFromModernEntry(d));
            }
        }
      }

      // ── Legacy shape fallback ───────────────────────────────────────────
      if (tracks.isEmpty) {
        final legacyTracks = entities['tracks'] as Map<String, dynamic>?;
        for (final entry in legacyTracks?.values ?? []) {
          final entryMap = entry as Map<String, dynamic>?;
          if (entryMap != null) add(_trackFromLegacyEntry(entryMap));
        }
      }
    } catch (_) {
      // Return whatever we managed to collect rather than crashing.
    }

    tracks.sort((a, b) {
      final disc = a.discNumber.compareTo(b.discNumber);
      return disc != 0 ? disc : a.trackNumber.compareTo(b.trackNumber);
    });

    return tracks;
  }

  /// Copies album-level fields (name, coverArt) into a sibling track node
  /// so that [_trackFromModernEntry] can build a fully populated [Track].
  Map<String, dynamic> _enrichSiblingTrack(
    Map<String, dynamic> trackNode,
    Map<String, dynamic>? albumObj,
  ) {
    if (albumObj == null) return trackNode;
    return {
      ...trackNode,
      'albumOfTrack': {
        'name': albumObj['name'],
        'coverArt': albumObj['coverArt'],
      },
    };
  }

  /// Builds a [Track] from the **modern** initialState entry format.
  ///
  /// Actual Spotify shape observed:
  /// ```json
  /// {
  ///   "__typename": "Track",
  ///   "id": "4uLU6hMCjMI75M1A2tKUQC",
  ///   "name": "Never Gonna Give You Up",
  ///   "duration": { "totalMilliseconds": 213573 },
  ///   "trackNumber": 1,
  ///   "artists": { "items": [ { "profile": { "name": "Rick Astley" } } ] },
  ///   "albumOfTrack": {
  ///     "name": "Whenever You Need Somebody",
  ///     "coverArt": { "sources": [ { "url": "https://…", "height": 640 } ] }
  ///   }
  /// }
  /// ```
  Track? _trackFromModernEntry(Map<String, dynamic> d) {
    try {
      // id can be a bare Spotify ID, a full URI "spotify:track:XXX", or
      // absent (playlist tracks only carry uri, not id).
      final rawId =
          (d['id'] as String? ?? d['uri'] as String? ?? '');
      final id = rawId.contains(':') ? rawId.split(':').last : rawId;

      final title = d['name'] as String? ?? '';

      // Duration
      final durationObj = d['duration'] as Map<String, dynamic>?;
      final durationMs = durationObj?['totalMilliseconds'] as int? ?? 0;

      // Track / disc numbers
      final trackNumber = d['trackNumber'] as int? ?? 1;
      final discNumber = d['discNumber'] as int? ?? 1;

      // Artists — top-level track entries use firstArtist / otherArtists.
      // Sibling track nodes (from albumOfTrack.tracks.items) use artists.items.
      List<String> artists = [];

      // Shape A: firstArtist + otherArtists (primary track entity)
      final firstArtistObj = d['firstArtist'] as Map<String, dynamic>?;
      final firstArtistItems =
          firstArtistObj?['items'] as List<dynamic>? ?? [];
      if (firstArtistItems.isNotEmpty) {
        final all = <Map<String, dynamic>>[
          ...firstArtistItems.cast<Map<String, dynamic>>(),
          ...((d['otherArtists'] as Map<String, dynamic>?)?['items']
                  as List<dynamic>? ??
              [])
              .cast<Map<String, dynamic>>(),
        ];
        artists = all.map((a) {
          final profile = a['profile'] as Map<String, dynamic>? ?? {};
          return profile['name'] as String? ?? '';
        }).where((n) => n.isNotEmpty).toList();
      }

      // Shape B: artists.items[].profile.name (sibling track nodes)
      if (artists.isEmpty) {
        final artistsObj = d['artists'] as Map<String, dynamic>?;
        final artistItems = artistsObj?['items'] as List<dynamic>? ?? [];
        artists = artistItems.map((a) {
          final aMap = a as Map<String, dynamic>? ?? {};
          final profile = aMap['profile'] as Map<String, dynamic>? ?? {};
          return profile['name'] as String? ?? '';
        }).where((n) => n.isNotEmpty).toList();
      }

      // Album name + cover art
      final albumObj = d['albumOfTrack'] as Map<String, dynamic>? ?? {};
      final album = albumObj['name'] as String? ?? '';
      final coverArtObj = albumObj['coverArt'] as Map<String, dynamic>? ?? {};
      final sources = coverArtObj['sources'] as List<dynamic>? ?? [];

      // Prefer the largest image (Spotify returns 64 / 300 / 640 px).
      String coverArtUrl = '';
      if (sources.isNotEmpty) {
        final sorted = List<Map<String, dynamic>>.from(
          sources.map((s) => s as Map<String, dynamic>),
        )..sort(
          (a, b) =>
              ((b['height'] as int?) ?? 0).compareTo((a['height'] as int?) ?? 0),
        );
        coverArtUrl = sorted.first['url'] as String? ?? '';
      }

      if (id.isEmpty || title.isEmpty) return null;

      return Track(
        id: id,
        title: title,
        artists: artists,
        album: album,
        coverArtUrl: coverArtUrl,
        durationMs: durationMs,
        trackNumber: trackNumber,
        discNumber: discNumber,
      );
    } catch (_) {
      return null;
    }
  }

  /// Builds a [Track] from the **legacy** initialState entry format.
  ///
  /// Legacy shape mirrors the public Spotify Web API track object closely,
  /// so [Track.fromJson] handles it directly.
  Track? _trackFromLegacyEntry(Map<String, dynamic> d) {
    try {
      return Track.fromJson(d);
    } catch (_) {
      return null;
    }
  }
}
