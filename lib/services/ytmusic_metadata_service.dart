import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/track.dart';

/// YouTube Music metadata fetching service.
///
/// Uses the YouTube Music internal `browse` API to fetch playlist/album
/// metadata, and the `player` API for single tracks.
/// This is SEPARATE from [YtMusicService] which handles search/scoring.
class YtMusicMetadataService {
  static const String _browseUrl =
      'https://music.youtube.com/youtubei/v1/browse?key=AIzaSyC9XL3ZjWd'
      'dXya6X74dJoCTL-WEYFDNX30';

  static const String _playerUrl =
      'https://music.youtube.com/youtubei/v1/player?key=AIzaSyC9XL3ZjWd'
      'dXya6X74dJoCTL-WEYFDNX30';

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'X-YouTube-Client-Name': '67',
    'X-YouTube-Client-Version': '1.20240101.01.00',
    'Origin': 'https://music.youtube.com',
    'Referer': 'https://music.youtube.com/',
  };

  static const Map<String, dynamic> _clientContext = {
    'client': {
      'clientName': 'WEB_REMIX',
      'clientVersion': '1.20240101.01.00',
    },
  };

  // ── Public Methods ───────────────────────────────────────────────────────

  /// Detects URL type and routes to the correct fetch method.
  /// Returns a list of [Track] objects extracted from the URL.
  Future<List<Track>> fetchFromUrl(String url) async {
    final type = _detectType(url);
    debugPrint('YTMusic Meta: type=$type');

    switch (type) {
      case 'track':
        final videoId = _extractVideoId(url);
        if (videoId == null) {
          throw Exception('YTMusic Meta: could not extract videoId from URL');
        }
        final track = await fetchTrack(videoId);
        return [track];

      case 'album':
      case 'playlist':
        final playlistId = _extractPlaylistId(url);
        if (playlistId == null) {
          throw Exception(
              'YTMusic Meta: could not extract playlistId from URL');
        }
        return type == 'album'
            ? fetchAlbum(playlistId)
            : fetchPlaylist(playlistId);

      default:
        throw Exception('YTMusic Meta: unsupported URL type');
    }
  }

  /// Fetches all tracks from a YouTube Music playlist.
  Future<List<Track>> fetchPlaylist(String playlistId) async {
    return _fetchBrowse(playlistId);
  }

  /// Fetches all tracks from a YouTube Music album.
  /// Uses the same browse logic as playlists.
  Future<List<Track>> fetchAlbum(String playlistId) async {
    return _fetchBrowse(playlistId);
  }

  /// Fetches metadata for a single track via the player endpoint.
  Future<Track> fetchTrack(String videoId) async {
    final body = jsonEncode({
      'context': _clientContext,
      'videoId': videoId,
    });

    try {
      final response = await http.post(
        Uri.parse(_playerUrl),
        headers: _headers,
        body: body,
      );

      debugPrint('YTMusic Meta: HTTP status ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception(
            'YTMusic Meta: player request failed (${response.statusCode})');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final details = _get(data, 'videoDetails') as Map<String, dynamic>?;

      if (details == null) {
        throw Exception('YTMusic Meta: no videoDetails in player response');
      }

      final title = _get(details, 'title') as String? ?? '';
      final artist = _get(details, 'author') as String? ?? '';
      final lengthSeconds =
          int.tryParse(_get(details, 'lengthSeconds')?.toString() ?? '0') ?? 0;
      final fetchedVideoId =
          _get(details, 'videoId') as String? ?? videoId;

      // Cover art — take the last (highest res) thumbnail
      String coverArtUrl = '';
      try {
        final thumb = _get(details, 'thumbnail') as Map<String, dynamic>?;
        final thumbnails = _get(thumb, 'thumbnails') as List<dynamic>?;
        if (thumbnails != null && thumbnails.isNotEmpty) {
          final last = thumbnails.last as Map<String, dynamic>?;
          coverArtUrl = _get(last, 'url') as String? ?? '';
        }
      } catch (_) {
        // Cover art extraction is non-critical
      }

      final track = Track(
        id: fetchedVideoId,
        title: title,
        artists: [artist],
        album: '', // Not available from player endpoint
        coverArtUrl: coverArtUrl,
        durationMs: lengthSeconds * 1000,
        trackNumber: 1,
        discNumber: 1,
      );

      debugPrint('YTMusic Meta: tracks found 1');
      debugPrint('YTMusic Meta: first track title ${track.title}');

      return track;
    } catch (e) {
      if (e is Exception && e.toString().contains('YTMusic Meta:')) {
        rethrow;
      }
      throw Exception('YTMusic Meta: failed to fetch track — $e');
    }
  }

  // ── Browse (Playlist/Album) Logic ────────────────────────────────────────

  /// Fetches tracks via the browse API with automatic pagination.
  Future<List<Track>> _fetchBrowse(String playlistId) async {
    final browseId = 'VL$playlistId';
    debugPrint('YTMusic Meta: browseId=$browseId');

    final List<Track> allTracks = [];

    // ── Initial request ──
    final initialBody = jsonEncode({
      'context': _clientContext,
      'browseId': browseId,
    });

    try {
      final response = await http.post(
        Uri.parse(_browseUrl),
        headers: _headers,
        body: initialBody,
      );

      debugPrint('YTMusic Meta: HTTP status ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception(
            'YTMusic Meta: browse request failed (${response.statusCode})');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // Parse tracks from the initial response
      final tracks = _parseShelfContents(data);
      allTracks.addAll(tracks);

      // ── Pagination: check for continuations ──
      String? continuationToken = _extractContinuationToken(data);

      while (continuationToken != null) {
        await Future.delayed(const Duration(milliseconds: 300));

        final contBody = jsonEncode({
          'context': _clientContext,
          'continuation': continuationToken,
        });

        final contResponse = await http.post(
          Uri.parse(_browseUrl),
          headers: _headers,
          body: contBody,
        );

        if (contResponse.statusCode != 200) {
          debugPrint('YTMusic Meta: continuation request failed '
              '(${contResponse.statusCode}), stopping pagination');
          break;
        }

        final contData =
            jsonDecode(contResponse.body) as Map<String, dynamic>;

        // Continuation responses have a different structure
        final contTracks = _parseContinuationContents(contData);
        allTracks.addAll(contTracks);

        // Check for further continuations
        continuationToken = _extractContinuationTokenFromCont(contData);
      }

      debugPrint('YTMusic Meta: tracks found ${allTracks.length}');
      if (allTracks.isNotEmpty) {
        debugPrint('YTMusic Meta: first track title ${allTracks.first.title}');
      }

      return allTracks;
    } catch (e) {
      if (e is Exception && e.toString().contains('YTMusic Meta:')) {
        rethrow;
      }
      throw Exception('YTMusic Meta: failed to fetch browse data — $e');
    }
  }

  // ── Response Parsing ─────────────────────────────────────────────────────

  /// Parses track items from the initial browse response.
  /// Handles both layout variants:
  ///   - twoColumnBrowseResultsRenderer → secondaryContents (albums/playlists)
  ///   - singleColumnBrowseResultsRenderer → tabs (older/other formats)
  List<Track> _parseShelfContents(Map<String, dynamic> data) {
    try {
      final contents = _get(data, 'contents') as Map<String, dynamic>?;

      // ── Path 1: twoColumnBrowseResultsRenderer (albums & playlists) ──
      final twoCol =
          _get(contents, 'twoColumnBrowseResultsRenderer') as Map<String, dynamic>?;
      if (twoCol != null) {
        final secondary =
            _get(twoCol, 'secondaryContents') as Map<String, dynamic>?;
        final sectionList =
            _get(secondary, 'sectionListRenderer') as Map<String, dynamic>?;
        final sectionContents = _get(sectionList, 'contents') as List<dynamic>?;
        if (sectionContents != null && sectionContents.isNotEmpty) {
          final section0 = sectionContents[0] as Map<String, dynamic>?;

          // Try musicPlaylistShelfRenderer first (most common for albums)
          final playlistShelf =
              _get(section0, 'musicPlaylistShelfRenderer') as Map<String, dynamic>?;
          if (playlistShelf != null) {
            final items = _get(playlistShelf, 'contents') as List<dynamic>?;
            if (items != null) return _parseItems(items);
          }

          // Fallback: musicShelfRenderer
          final shelf =
              _get(section0, 'musicShelfRenderer') as Map<String, dynamic>?;
          if (shelf != null) {
            final items = _get(shelf, 'contents') as List<dynamic>?;
            if (items != null) return _parseItems(items);
          }
        }
      }

      // ── Path 2: singleColumnBrowseResultsRenderer (fallback) ──
      final singleCol =
          _get(contents, 'singleColumnBrowseResultsRenderer') as Map<String, dynamic>?;
      if (singleCol != null) {
        final tabs = _get(singleCol, 'tabs') as List<dynamic>?;
        if (tabs != null && tabs.isNotEmpty) {
          final tab0 = tabs[0] as Map<String, dynamic>?;
          final tabRenderer =
              _get(tab0, 'tabRenderer') as Map<String, dynamic>?;
          final content =
              _get(tabRenderer, 'content') as Map<String, dynamic>?;
          final sectionList =
              _get(content, 'sectionListRenderer') as Map<String, dynamic>?;
          final sectionContents =
              _get(sectionList, 'contents') as List<dynamic>?;
          if (sectionContents != null && sectionContents.isNotEmpty) {
            final section0 = sectionContents[0] as Map<String, dynamic>?;

            final playlistShelf =
                _get(section0, 'musicPlaylistShelfRenderer') as Map<String, dynamic>?;
            if (playlistShelf != null) {
              final items = _get(playlistShelf, 'contents') as List<dynamic>?;
              if (items != null) return _parseItems(items);
            }

            final shelf =
                _get(section0, 'musicShelfRenderer') as Map<String, dynamic>?;
            if (shelf != null) {
              final items = _get(shelf, 'contents') as List<dynamic>?;
              if (items != null) return _parseItems(items);
            }
          }
        }
      }

      return [];
    } catch (e) {
      debugPrint('YTMusic Meta: error parsing shelf contents — $e');
      return [];
    }
  }

  /// Parses track items from a continuation response.
  /// Checks both musicShelfContinuation and musicPlaylistShelfContinuation.
  List<Track> _parseContinuationContents(Map<String, dynamic> data) {
    try {
      final contContents =
          _get(data, 'continuationContents') as Map<String, dynamic>?;

      // Try musicPlaylistShelfContinuation first
      final playlistCont =
          _get(contContents, 'musicPlaylistShelfContinuation') as Map<String, dynamic>?;
      if (playlistCont != null) {
        final items = _get(playlistCont, 'contents') as List<dynamic>?;
        if (items != null) return _parseItems(items);
      }

      // Fallback: musicShelfContinuation
      final shelfCont =
          _get(contContents, 'musicShelfContinuation') as Map<String, dynamic>?;
      if (shelfCont != null) {
        final items = _get(shelfCont, 'contents') as List<dynamic>?;
        if (items != null) return _parseItems(items);
      }

      return [];
    } catch (e) {
      debugPrint('YTMusic Meta: error parsing continuation contents — $e');
      return [];
    }
  }

  /// Parses individual musicResponsiveListItemRenderer items into [Track]s.
  List<Track> _parseItems(List<dynamic> items) {
    final tracks = <Track>[];
    int trackNumber = 1;

    for (final item in items) {
      try {
        final itemMap = item as Map<String, dynamic>?;
        final renderer =
            _get(itemMap, 'musicResponsiveListItemRenderer') as Map<String, dynamic>?;
        if (renderer == null) continue;

        final flexColumns = _get(renderer, 'flexColumns') as List<dynamic>?;

        // Title (flexColumns[0])
        String title = '';
        if (flexColumns != null && flexColumns.isNotEmpty) {
          final col0 = flexColumns[0] as Map<String, dynamic>?;
          final colRenderer =
              _get(col0, 'musicResponsiveListItemFlexColumnRenderer') as Map<String, dynamic>?;
          final textObj = _get(colRenderer, 'text') as Map<String, dynamic>?;
          final runs = _get(textObj, 'runs') as List<dynamic>?;
          if (runs != null && runs.isNotEmpty) {
            final run0 = runs[0] as Map<String, dynamic>?;
            title = _get(run0, 'text') as String? ?? '';
          }
        }

        if (title.isEmpty) continue;

        // Artist (flexColumns[1])
        String artist = '';
        if (flexColumns != null && flexColumns.length > 1) {
          final col1 = flexColumns[1] as Map<String, dynamic>?;
          final colRenderer =
              _get(col1, 'musicResponsiveListItemFlexColumnRenderer') as Map<String, dynamic>?;
          final textObj = _get(colRenderer, 'text') as Map<String, dynamic>?;
          final runs = _get(textObj, 'runs') as List<dynamic>?;
          if (runs != null && runs.isNotEmpty) {
            final run0 = runs[0] as Map<String, dynamic>?;
            artist = _get(run0, 'text') as String? ?? '';
          }
        }

        // Album (flexColumns[2] — may not exist for playlists)
        String album = '';
        if (flexColumns != null && flexColumns.length > 2) {
          final col2 = flexColumns[2] as Map<String, dynamic>?;
          final colRenderer =
              _get(col2, 'musicResponsiveListItemFlexColumnRenderer') as Map<String, dynamic>?;
          final textObj = _get(colRenderer, 'text') as Map<String, dynamic>?;
          final runs = _get(textObj, 'runs') as List<dynamic>?;
          if (runs != null && runs.isNotEmpty) {
            final run0 = runs[0] as Map<String, dynamic>?;
            album = _get(run0, 'text') as String? ?? '';
          }
        }

        // Duration (fixedColumns[0])
        String durationStr = '';
        final fixedColumns = _get(renderer, 'fixedColumns') as List<dynamic>?;
        if (fixedColumns != null && fixedColumns.isNotEmpty) {
          final fc0 = fixedColumns[0] as Map<String, dynamic>?;
          final fcRenderer =
              _get(fc0, 'musicResponsiveListItemFixedColumnRenderer') as Map<String, dynamic>?;
          final textObj = _get(fcRenderer, 'text') as Map<String, dynamic>?;
          final runs = _get(textObj, 'runs') as List<dynamic>?;
          if (runs != null && runs.isNotEmpty) {
            final run0 = runs[0] as Map<String, dynamic>?;
            durationStr = _get(run0, 'text') as String? ?? '';
          }
        }
        final durationMs = _parseDurationToMs(durationStr);

        // Video ID (from overlay)
        String videoId = '';
        final overlay = _get(renderer, 'overlay') as Map<String, dynamic>?;
        final thumbOverlay =
            _get(overlay, 'musicItemThumbnailOverlayRenderer') as Map<String, dynamic>?;
        final overlayContent =
            _get(thumbOverlay, 'content') as Map<String, dynamic>?;
        final playButton =
            _get(overlayContent, 'musicPlayButtonRenderer') as Map<String, dynamic>?;
        final playNav =
            _get(playButton, 'playNavigationEndpoint') as Map<String, dynamic>?;
        final watchEndpoint =
            _get(playNav, 'watchEndpoint') as Map<String, dynamic>?;
        videoId = _get(watchEndpoint, 'videoId') as String? ?? '';

        if (videoId.isEmpty) continue;

        // Cover Art — take the last thumbnail (highest res)
        String coverArtUrl = '';
        try {
          final thumbObj = _get(renderer, 'thumbnail') as Map<String, dynamic>?;
          final musicThumb =
              _get(thumbObj, 'musicThumbnailRenderer') as Map<String, dynamic>?;
          final thumbInner =
              _get(musicThumb, 'thumbnail') as Map<String, dynamic>?;
          final thumbnails = _get(thumbInner, 'thumbnails') as List<dynamic>?;
          if (thumbnails != null && thumbnails.isNotEmpty) {
            final last = thumbnails.last as Map<String, dynamic>?;
            coverArtUrl = _get(last, 'url') as String? ?? '';
          }
        } catch (_) {
          // Cover art extraction is non-critical
        }

        tracks.add(Track(
          id: videoId,
          title: title,
          artists: artist.isNotEmpty ? [artist] : [],
          album: album,
          coverArtUrl: coverArtUrl,
          durationMs: durationMs,
          trackNumber: trackNumber,
          discNumber: 1,
        ));

        trackNumber++;
      } catch (e) {
        debugPrint('YTMusic Meta: skipping item due to parse error — $e');
        continue;
      }
    }

    return tracks;
  }

  // ── Continuation Token Extraction ────────────────────────────────────────

  /// Extracts the continuation token from the initial browse response.
  /// Checks both twoColumn and singleColumn structures, and both
  /// musicPlaylistShelfRenderer and musicShelfRenderer.
  String? _extractContinuationToken(Map<String, dynamic> data) {
    try {
      final contents = _get(data, 'contents') as Map<String, dynamic>?;

      // Collect all sectionListRenderers to check
      final List<Map<String, dynamic>> sectionLists = [];

      // ── twoColumnBrowseResultsRenderer ──
      final twoCol =
          _get(contents, 'twoColumnBrowseResultsRenderer') as Map<String, dynamic>?;
      if (twoCol != null) {
        final secondary =
            _get(twoCol, 'secondaryContents') as Map<String, dynamic>?;
        final sl =
            _get(secondary, 'sectionListRenderer') as Map<String, dynamic>?;
        if (sl != null) sectionLists.add(sl);
      }

      // ── singleColumnBrowseResultsRenderer ──
      final singleCol =
          _get(contents, 'singleColumnBrowseResultsRenderer') as Map<String, dynamic>?;
      if (singleCol != null) {
        final tabs = _get(singleCol, 'tabs') as List<dynamic>?;
        if (tabs != null && tabs.isNotEmpty) {
          final tab0 = tabs[0] as Map<String, dynamic>?;
          final tabRenderer =
              _get(tab0, 'tabRenderer') as Map<String, dynamic>?;
          final content =
              _get(tabRenderer, 'content') as Map<String, dynamic>?;
          final sl =
              _get(content, 'sectionListRenderer') as Map<String, dynamic>?;
          if (sl != null) sectionLists.add(sl);
        }
      }

      for (final sectionList in sectionLists) {
        // Check sectionListRenderer.continuations
        final continuations =
            _get(sectionList, 'continuations') as List<dynamic>?;
        if (continuations != null && continuations.isNotEmpty) {
          final cont0 = continuations[0] as Map<String, dynamic>?;
          final nextData =
              _get(cont0, 'nextContinuationData') as Map<String, dynamic>?;
          final token = _get(nextData, 'continuation') as String?;
          if (token != null) return token;
        }

        // Check inside shelf renderers
        final sectionContents =
            _get(sectionList, 'contents') as List<dynamic>?;
        if (sectionContents != null && sectionContents.isNotEmpty) {
          final section0 = sectionContents[0] as Map<String, dynamic>?;

          // musicPlaylistShelfRenderer
          final playlistShelf =
              _get(section0, 'musicPlaylistShelfRenderer') as Map<String, dynamic>?;
          final pConts =
              _get(playlistShelf, 'continuations') as List<dynamic>?;
          if (pConts != null && pConts.isNotEmpty) {
            final cont0 = pConts[0] as Map<String, dynamic>?;
            final nextData =
                _get(cont0, 'nextContinuationData') as Map<String, dynamic>?;
            final token = _get(nextData, 'continuation') as String?;
            if (token != null) return token;
          }

          // musicShelfRenderer
          final shelf =
              _get(section0, 'musicShelfRenderer') as Map<String, dynamic>?;
          final sConts = _get(shelf, 'continuations') as List<dynamic>?;
          if (sConts != null && sConts.isNotEmpty) {
            final cont0 = sConts[0] as Map<String, dynamic>?;
            final nextData =
                _get(cont0, 'nextContinuationData') as Map<String, dynamic>?;
            final token = _get(nextData, 'continuation') as String?;
            if (token != null) return token;
          }
        }
      }
    } catch (_) {
      // No continuation token found
    }
    return null;
  }

  /// Extracts the continuation token from a continuation response.
  /// Checks both musicPlaylistShelfContinuation and musicShelfContinuation.
  String? _extractContinuationTokenFromCont(Map<String, dynamic> data) {
    try {
      final contContents =
          _get(data, 'continuationContents') as Map<String, dynamic>?;

      // Check musicPlaylistShelfContinuation
      final playlistCont =
          _get(contContents, 'musicPlaylistShelfContinuation') as Map<String, dynamic>?;
      if (playlistCont != null) {
        final continuations =
            _get(playlistCont, 'continuations') as List<dynamic>?;
        if (continuations != null && continuations.isNotEmpty) {
          final cont0 = continuations[0] as Map<String, dynamic>?;
          final nextData =
              _get(cont0, 'nextContinuationData') as Map<String, dynamic>?;
          final token = _get(nextData, 'continuation') as String?;
          if (token != null) return token;
        }
      }

      // Fallback: musicShelfContinuation
      final shelfCont =
          _get(contContents, 'musicShelfContinuation') as Map<String, dynamic>?;
      if (shelfCont != null) {
        final continuations =
            _get(shelfCont, 'continuations') as List<dynamic>?;
        if (continuations != null && continuations.isNotEmpty) {
          final cont0 = continuations[0] as Map<String, dynamic>?;
          final nextData =
              _get(cont0, 'nextContinuationData') as Map<String, dynamic>?;
          return _get(nextData, 'continuation') as String?;
        }
      }
    } catch (_) {
      // No further continuation
    }
    return null;
  }

  // ── URL Parsing ──────────────────────────────────────────────────────────

  /// Detects whether the URL points to a track, album, or playlist.
  String _detectType(String url) {
    if (url.contains('watch?v=') ||
        (url.contains('watch?') && url.contains('v='))) {
      // A watch URL with a list= that starts with OLAK5uy_ is an album view
      if (url.contains('list=OLAK5uy_')) {
        return 'album';
      } else if (url.contains('list=')) {
        return 'playlist';
      }
      return 'track';
    }
    if (url.contains('list=OLAK5uy_')) return 'album';
    if (url.contains('list=')) return 'playlist';
    return 'track'; // fallback
  }

  /// Extracts the `list=` parameter value from the URL query string.
  /// Works for both music.youtube.com and youtube.com URLs.
  String? _extractPlaylistId(String url) {
    try {
      final uri = Uri.parse(url);
      final listParam = uri.queryParameters['list'];
      if (listParam != null && listParam.isNotEmpty) {
        return listParam;
      }
    } catch (_) {
      // Try regex fallback for malformed URLs
      final match = RegExp(r'list=([a-zA-Z0-9_-]+)').firstMatch(url);
      if (match != null) return match.group(1);
    }
    return null;
  }

  /// Extracts the `v=` parameter value from the URL query string.
  String? _extractVideoId(String url) {
    try {
      final uri = Uri.parse(url);
      final vParam = uri.queryParameters['v'];
      if (vParam != null && vParam.isNotEmpty) {
        return vParam;
      }
    } catch (_) {
      // Try regex fallback for malformed URLs
      final match = RegExp(r'v=([a-zA-Z0-9_-]{11})').firstMatch(url);
      if (match != null) return match.group(1);
    }
    return null;
  }

  // ── Duration Parsing ─────────────────────────────────────────────────────

  /// Converts a duration string like "3:45" or "1:02:30" to milliseconds.
  int _parseDurationToMs(String durationStr) {
    if (durationStr.isEmpty) return 0;

    try {
      final parts = durationStr.split(':');
      if (parts.length == 2) {
        final minutes = int.parse(parts[0]);
        final seconds = int.parse(parts[1]);
        return (minutes * 60 + seconds) * 1000;
      } else if (parts.length == 3) {
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        final seconds = int.parse(parts[2]);
        return (hours * 3600 + minutes * 60 + seconds) * 1000;
      }
    } catch (_) {
      // Malformed duration string
    }
    return 0;
  }

  // ── Null-safe JSON helper ────────────────────────────────────────────────

  /// Safely accesses a key on a possibly-null dynamic map.
  /// Returns null if [obj] is null or not a Map, or if [key] is missing.
  dynamic _get(dynamic obj, String key) {
    if (obj == null) return null;
    if (obj is Map<String, dynamic>) return obj[key];
    return null;
  }
}
