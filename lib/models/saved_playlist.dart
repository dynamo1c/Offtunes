import 'track.dart';

/// A playlist saved to disk after a batch of downloads completes.
class SavedPlaylist {
  final String name;
  final DateTime createdAt;
  final List<Track> tracks;

  const SavedPlaylist({
    required this.name,
    required this.createdAt,
    required this.tracks,
  });

  /// The first track, used as cover art representative.
  Track? get coverTrack => tracks.isNotEmpty ? tracks.first : null;

  int get trackCount => tracks.length;
}
