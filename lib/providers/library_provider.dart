import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/search_index.dart';
import '../models/saved_playlist.dart';
import '../models/track.dart';
import '../services/library_service.dart';

final libraryProvider = ChangeNotifierProvider<LibraryProvider>((ref) {
  return LibraryProvider();
});

class LibraryProvider extends ChangeNotifier {
  final LibraryService _libraryService = LibraryService();
  final SearchIndex _searchIndex = SearchIndex();

  List<Track> _allTracks = [];
  Map<String, List<Track>> _albums = {};
  List<SavedPlaylist> _playlists = [];
  bool _isLoading = false;
  int _folderSizeBytes = 0;

  List<Track> get allTracks => _allTracks;
  Map<String, List<Track>> get albums => _albums;
  List<SavedPlaylist> get playlists => _playlists;
  bool get isLoading => _isLoading;
  int get folderSizeBytes => _folderSizeBytes;
  SearchIndex get searchIndex => _searchIndex;

  /// Human-readable folder size string.
  String get folderSizeFormatted {
    if (_folderSizeBytes == 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    int idx = 0;
    double size = _folderSizeBytes.toDouble();
    while (size >= 1024 && idx < units.length - 1) {
      size /= 1024;
      idx++;
    }
    return '${size.toStringAsFixed(1)} ${units[idx]}';
  }

  /// Scans the Offtunes music folder and rebuilds the library.
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();

    try {
      _allTracks = await _libraryService.scanLibrary();
      _albums = _libraryService.groupByAlbum(_allTracks);
      _folderSizeBytes = await _libraryService.getFolderSizeBytes();
      _playlists = await _libraryService.loadPlaylists(_allTracks);
      _searchIndex.build(_allTracks);

      // ── First-launch bootstrap (Option B) ──────────────────────────────────
      // If the library has songs but no playlists have ever been saved,
      // treat all existing tracks as "Playlist 1" so the tab isn't empty.
      if (_playlists.isEmpty && _allTracks.isNotEmpty) {
        await _libraryService.savePlaylist('Playlist 1', _allTracks);
        _playlists = await _libraryService.loadPlaylists(_allTracks);
      }
    } catch (e) {
      debugPrint('LibraryProvider: refresh failed — $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Renames a playlist and refreshes the library.
  Future<void> renamePlaylist(int index, String newName) async {
    try {
      await _libraryService.renamePlaylist(index, newName);
      await refresh();
    } catch (e) {
      debugPrint('LibraryProvider: renamePlaylist failed — $e');
      rethrow;
    }
  }

  /// Merges source playlist into destination playlist, then refreshes.
  Future<void> mergePlaylists(int sourceIndex, int destIndex) async {
    try {
      await _libraryService.mergePlaylists(sourceIndex, destIndex);
      await refresh();
    } catch (e) {
      debugPrint('LibraryProvider: mergePlaylists failed — $e');
      rethrow;
    }
  }
}
