/// Data model representing a music track sourced from Spotify.
library;

class Track {
  /// Spotify track ID.
  final String id;

  /// Track title / name.
  final String title;

  /// List of artist names.
  final List<String> artists;

  /// Album name.
  final String album;

  /// URL of the album cover artwork.
  final String coverArtUrl;

  /// Track duration in milliseconds.
  final int durationMs;

  /// Position of the track within its album (1-based).
  final int trackNumber;

  /// Disc number for multi-disc albums (1-based).
  final int discNumber;

  /// Absolute path to the audio file on disk (set when scanned from library).
  String filePath;

  Track({
    required this.id,
    required this.title,
    required this.artists,
    required this.album,
    required this.coverArtUrl,
    required this.durationMs,
    required this.trackNumber,
    required this.discNumber,
    this.filePath = '',
  });

  // ── Helper getters ────────────────────────────────────────────────────────

  /// Returns all artist names joined by a comma-space separator.
  String get artistString => artists.join(', ');

  // ── Serialisation ─────────────────────────────────────────────────────────

  /// Creates a [Track] from a JSON map (Spotify API response compatible).
  factory Track.fromJson(Map<String, dynamic> json) {
    // Artists can be nested objects {"name": "…"} or plain strings.
    final rawArtists = json['artists'] as List<dynamic>? ?? [];
    final artistNames = rawArtists.map((a) {
      if (a is Map<String, dynamic>) return a['name'] as String? ?? '';
      return a.toString();
    }).toList();

    // Cover art: Spotify wraps images in album.images[].url
    String coverArt = '';
    final album = json['album'] as Map<String, dynamic>?;
    if (album != null) {
      final images = album['images'] as List<dynamic>?;
      if (images != null && images.isNotEmpty) {
        coverArt =
            (images.first as Map<String, dynamic>)['url'] as String? ?? '';
      }
    }

    return Track(
      id: json['id'] as String? ?? '',
      title: json['name'] as String? ?? '',
      artists: artistNames,
      album: album?['name'] as String? ?? json['album'] as String? ?? '',
      coverArtUrl:
          coverArt.isNotEmpty ? coverArt : json['coverArtUrl'] as String? ?? '',
      durationMs: json['duration_ms'] as int? ?? json['durationMs'] as int? ?? 0,
      trackNumber:
          json['track_number'] as int? ?? json['trackNumber'] as int? ?? 1,
      discNumber:
          json['disc_number'] as int? ?? json['discNumber'] as int? ?? 1,
      filePath: json['filePath'] as String? ?? '',
    );
  }

  /// Converts this [Track] to a JSON-serialisable map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': title,
        'artists': artists.map((a) => {'name': a}).toList(),
        'album': {
          'name': album,
          'images': coverArtUrl.isNotEmpty ? [{'url': coverArtUrl}] : <Map<String, String>>[],
        },
        'duration_ms': durationMs,
        'track_number': trackNumber,
        'disc_number': discNumber,
        // Flat convenience fields for local storage
        'coverArtUrl': coverArtUrl,
        'durationMs': durationMs,
        'trackNumber': trackNumber,
        'discNumber': discNumber,
        'filePath': filePath,
      };

  // ── Object overrides ──────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Track && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Track(id: $id, title: $title, artists: $artistString, album: $album)';
}
