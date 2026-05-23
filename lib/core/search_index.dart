import '../models/track.dart';

/// Fast ranked search index over the local track library.
class SearchIndex {
  final List<Track> _tracks = [];

  /// Rebuilds the index from the given track list.
  void build(List<Track> tracks) {
    _tracks.clear();
    _tracks.addAll(tracks);
  }

  /// Returns up to [maxResults] ranked results for [query].
  List<SearchResult> search(String query, {int maxResults = 25}) {
    if (query.trim().isEmpty) return [];

    final q = query.toLowerCase().trim();
    final results = <SearchResult>[];

    for (final track in _tracks) {
      final titleLower = track.title.toLowerCase();
      final artistLower = track.artistString.toLowerCase();

      int score = 0;

      if (titleLower.startsWith(q)) {
        score = 100;
      } else if (titleLower.contains(q)) {
        score = 70;
      } else if (artistLower.startsWith(q)) {
        score = 60;
      } else if (artistLower.contains(q)) {
        score = 40;
      } else {
        // Word-level prefix match in title
        for (final word in titleLower.split(RegExp(r'\s+'))) {
          if (word.startsWith(q)) {
            score = 55;
            break;
          }
        }
      }

      // Fuzzy fallback: all chars of query appear in order in title
      if (score == 0 && _fuzzyMatch(q, titleLower)) score = 20;

      if (score > 0) {
        results.add(SearchResult(track: track, score: score));
      }
    }

    results.sort((a, b) {
      final diff = b.score - a.score;
      if (diff != 0) return diff;
      return a.track.title.compareTo(b.track.title);
    });

    return results.take(maxResults).toList();
  }

  bool _fuzzyMatch(String query, String text) {
    int qi = 0;
    for (int i = 0; i < text.length && qi < query.length; i++) {
      if (text[i] == query[qi]) qi++;
    }
    return qi == query.length;
  }
}

class SearchResult {
  final Track track;
  final int score;

  const SearchResult({required this.track, required this.score});
}
