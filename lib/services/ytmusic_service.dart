import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../models/track.dart';

/// YouTube Music search service.
/// Searches YouTube Music using direct HTTP POST requests to its internal API.
///
/// Anti-remix defence layers (highest → lowest priority):
///  1. videoType bonus/penalty  — ATC (official audio) +15 | UGC (user-gen) −30
///  2. Blacklist title scoring  — "remix", "cover", "live" etc. −60 each unless
///     the original track title also contains the same keyword.
///  3. Query string exclusion   — appends "-remix -cover -live" so YouTube's own
///     ranking deprioritises those results before we even score them.
class YtMusicService {
  static const String _searchUrl =
      'https://music.youtube.com/youtubei/v1/search?key=AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30';

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'X-YouTube-Client-Name': '67',
    'X-YouTube-Client-Version': '1.20240101.01.00',
    'Origin': 'https://music.youtube.com',
    'Referer': 'https://music.youtube.com/',
  };

  // ── Layer 2: Blacklist keywords ──────────────────────────────────────────
  // Each word here triggers a −60 point penalty on the result's score,
  // UNLESS the original track title also contains the same word (e.g. a song
  // legitimately called "Remix" by an artist).
  static const List<String> _blacklist = [
    'remix',
    'cover',
    'live',
    'karaoke',
    'instrumental',
    'mashup',
    'acoustic',
    'lofi',
    'lo-fi',
    'slowed',
    'reverb',
    'sped up',
    'nightcore',
    'tribute',
    'recreation',
    'rendition',
    'bootleg',
  ];

  // ── Layer 3: Query exclusions ────────────────────────────────────────────
  // Appended to every search query so YouTube's own ranking pushes these down.
  static const String _queryExclusions = ' -remix -cover -live -karaoke';

  /// Searches YouTube Music for the track.
  /// Runs the scoring algorithm and returns the best matching YouTube video ID,
  /// or null if no good match is found (score <= 30).
  Future<String?> findYouTubeId(Track track) async {
    // Layer 3 — append exclusions to query
    final query =
        '${track.title} ${track.artistString}$_queryExclusions';

    final body = jsonEncode({
      "context": {
        "client": {
          "clientName": "WEB_REMIX",
          "clientVersion": "1.20240101.01.00",
        }
      },
      "query": query,
      "params": "EgWKAQIIAWoKEAoQAxAEEAkQBQ%3D%3D", // Filters to "Songs" only
    });

    try {
      final response = await http.post(
        Uri.parse(_searchUrl),
        headers: _headers,
        body: body,
      );

      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = _extractResults(data);

      if (results.isEmpty) return null;

      // Find max views for scoring tiebreaker
      int maxViews = 0;
      for (final res in results) {
        if (res.views > maxViews) maxViews = res.views;
      }

      String? bestVideoId;
      double highestScore = 0;

      for (final res in results) {
        final score = _calculateScore(track, res, maxViews);
        if (score > highestScore) {
          highestScore = score;
          bestVideoId = res.videoId;
        }
      }

      // Threshold: return null if no result scores above 30
      if (highestScore <= 30.0) {
        return null;
      }

      return bestVideoId;
    } catch (e) {
      return null;
    }
  }

  /// Batch method: returns `Map<trackId, youtubeVideoId?>`.
  /// Adds a 300ms delay between requests to avoid rate limiting.
  Future<Map<String, String?>> findYouTubeIds(List<Track> tracks) async {
    final Map<String, String?> results = {};

    for (final track in tracks) {
      final videoId = await findYouTubeId(track);
      results[track.id] = videoId;
      await Future.delayed(const Duration(milliseconds: 300));
    }

    return results;
  }

  // ── Scoring Algorithm ───────────────────────────────────────────────────
  //
  // Score breakdown (max 115 points):
  //   40  — Title similarity
  //   30  — Artist match
  //   20  — Duration match (within ≤2s / ≤5s / ≤10s)
  //   10  — View count tiebreaker
  //   15  — Layer 1: videoType ATC bonus
  //  −30  — Layer 1: videoType UGC penalty
  //  −60  — Layer 2: blacklist keyword penalty (per word, if not in original)

  double _calculateScore(Track track, _YtResult result, int maxViews) {
    double totalScore = 0;
    final searchTitleLower = track.title.toLowerCase();
    final resultTitleLower = result.title.toLowerCase();

    // 1. Title similarity (40 points max)
    if (searchTitleLower == resultTitleLower) {
      totalScore += 40.0;
    } else {
      final searchWords = searchTitleLower
          .split(RegExp(r'\W+'))
          .where((w) => w.isNotEmpty)
          .toList();
      if (searchWords.isNotEmpty) {
        int matched = 0;
        for (final word in searchWords) {
          if (resultTitleLower.contains(word)) matched++;
        }
        totalScore += (matched / searchWords.length) * 40.0;
      }
    }

    // 2. Artist match (30 points max)
    if (track.artists.isNotEmpty) {
      final subtitleLower = result.subtitle.toLowerCase();
      int matchedArtists = 0;
      for (final artist in track.artists) {
        if (subtitleLower.contains(artist.toLowerCase())) {
          matchedArtists++;
        }
      }
      totalScore += (matchedArtists / track.artists.length) * 30.0;
    }

    // 3. Duration match (20 points max)
    if (result.durationSecs > 0 && track.durationMs > 0) {
      final trackSecs = track.durationMs ~/ 1000;
      final diff = (trackSecs - result.durationSecs).abs();

      if (diff <= 2) {
        totalScore += 20.0;
      } else if (diff <= 5) {
        totalScore += 15.0;
      } else if (diff <= 10) {
        totalScore += 8.0;
      }
    }

    // 4. View count tiebreaker (10 points max)
    if (result.views > 0 && maxViews > 0) {
      final viewLog = math.log(result.views);
      final maxLog = math.log(maxViews);
      if (maxLog > 0) {
        totalScore += (viewLog / maxLog) * 10.0;
      }
    }

    // ── Layer 1: videoType scoring ────────────────────────────────────────
    // ATC  = Official Audio Track → strongly preferred
    // OMV  = Official Music Video → neutral (still valid)
    // UGC  = User Generated Content (covers, remixes) → heavily penalised
    // OSM  = Official Source Music (label upload) → slight bonus
    switch (result.videoType) {
      case 'MUSIC_VIDEO_TYPE_ATC':
        totalScore += 15.0;
        break;
      case 'MUSIC_VIDEO_TYPE_OFFICIAL_SOURCE_MUSIC':
        totalScore += 5.0;
        break;
      case 'MUSIC_VIDEO_TYPE_UGC':
        totalScore -= 30.0;
        break;
      default:
        break; // OMV and unknown → no change
    }

    // ── Layer 2: Blacklist keyword penalty ────────────────────────────────
    // Only penalise if the *original* track title does NOT contain the same
    // keyword (e.g. a song literally called "Acoustic" won't be penalised).
    for (final keyword in _blacklist) {
      final resultHas = resultTitleLower.contains(keyword);
      final originalHas = searchTitleLower.contains(keyword);
      if (resultHas && !originalHas) {
        totalScore -= 60.0;
      }
    }

    return totalScore;
  }

  // ── Parsing Helpers ─────────────────────────────────────────────────────

  List<_YtResult> _extractResults(Map<String, dynamic> data) {
    final parsedResults = <_YtResult>[];

    try {
      final tabs = data['contents']?['tabbedSearchResultsRenderer']?['tabs']
          as List<dynamic>?;
      if (tabs == null || tabs.isEmpty) return parsedResults;

      final contents = tabs[0]?['tabRenderer']?['content']
          ?['sectionListRenderer']?['contents'] as List<dynamic>?;
      if (contents == null) return parsedResults;

      for (final section in contents) {
        final shelf = section['musicShelfRenderer'] as Map<String, dynamic>?;
        if (shelf == null) continue;

        final items = shelf['contents'] as List<dynamic>? ?? [];
        for (final item in items) {
          final renderer =
              item['musicResponsiveListItemRenderer'] as Map<String, dynamic>?;
          if (renderer == null) continue;

          // Extract Video ID
          final videoId = renderer['overlay']
                  ?['musicItemThumbnailOverlayRenderer']?['content']
                  ?['musicPlayButtonRenderer']?['playNavigationEndpoint']
              ?['watchEndpoint']?['videoId'] as String?;

          if (videoId == null || videoId.isEmpty) continue;

          // Extract Title
          String title = '';
          final titleRuns = renderer['flexColumns']?[0]
                  ?['musicResponsiveListItemFlexColumnRenderer']?['text']
              ?['runs'] as List<dynamic>?;
          if (titleRuns != null && titleRuns.isNotEmpty) {
            title = titleRuns[0]?['text'] as String? ?? '';
          }

          // Extract Subtitle (contains artists, views, duration)
          String subtitle = '';
          final subtitleRuns = renderer['flexColumns']?[1]
                  ?['musicResponsiveListItemFlexColumnRenderer']?['text']
              ?['runs'] as List<dynamic>?;
          if (subtitleRuns != null) {
            for (final run in subtitleRuns) {
              subtitle += (run['text'] as String? ?? '');
            }
          }

          // ── Layer 1: Extract videoType ───────────────────────────────────
          // Path: musicItemThumbnailOverlayRenderer → musicPlayButtonRenderer
          //       → playNavigationEndpoint → watchEndpoint → musicVideoType
          String videoType = '';
          try {
            videoType = renderer['overlay']
                        ?['musicItemThumbnailOverlayRenderer']?['content']
                        ?['musicPlayButtonRenderer']?['playNavigationEndpoint']
                    ?['watchEndpoint']?['musicVideoType'] as String? ??
                '';
          } catch (_) {}

          // Also try the navigationEndpoint path (alternate location)
          if (videoType.isEmpty) {
            try {
              videoType = renderer['navigationEndpoint']
                          ?['watchEndpoint']?['musicVideoType'] as String? ??
                  '';
            } catch (_) {}
          }

          // Parse Duration from end of subtitle (e.g. "3:45")
          int durationSecs = 0;
          final durMatch =
              RegExp(r'(\d+:\d+(?::\d+)?)$').firstMatch(subtitle.trim());
          if (durMatch != null) {
            durationSecs = _parseDurationToSeconds(durMatch.group(1)!);
          }

          // Parse Views/Plays if present
          int views = 0;
          final viewMatch = RegExp(r'([\d,\.]+)([MKBmkb]?)\s+(plays|views)')
              .firstMatch(subtitle);
          if (viewMatch != null) {
            String numStr = viewMatch.group(1)!.replaceAll(',', '');
            double num = double.tryParse(numStr) ?? 0;
            String multiplier = viewMatch.group(2)!.toUpperCase();
            if (multiplier == 'B') {
              num *= 1000000000;
            } else if (multiplier == 'M') {
              num *= 1000000;
            } else if (multiplier == 'K') {
              num *= 1000;
            }
            views = num.toInt();
          }

          parsedResults.add(_YtResult(
            videoId: videoId,
            title: title,
            subtitle: subtitle,
            videoType: videoType,
            durationSecs: durationSecs,
            views: views,
          ));
        }
      }
    } catch (e) {
      // Ignore parsing errors — return whatever was successfully extracted
    }

    return parsedResults;
  }

  int _parseDurationToSeconds(String durationStr) {
    final parts = durationStr.split(':');
    if (parts.length == 2) {
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    } else if (parts.length == 3) {
      return int.parse(parts[0]) * 3600 +
          int.parse(parts[1]) * 60 +
          int.parse(parts[2]);
    }
    return 0;
  }
}

/// Internal data class to hold parsed YouTube Music results before scoring.
class _YtResult {
  final String videoId;
  final String title;
  final String subtitle;
  final String videoType; // MUSIC_VIDEO_TYPE_ATC | OMV | UGC | OFFICIAL_SOURCE_MUSIC
  final int durationSecs;
  final int views;

  _YtResult({
    required this.videoId,
    required this.title,
    required this.subtitle,
    required this.videoType,
    required this.durationSecs,
    required this.views,
  });
}
