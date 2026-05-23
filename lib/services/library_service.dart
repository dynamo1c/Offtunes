import 'dart:convert';
import 'dart:io';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';

import '../core/paths.dart';
import '../models/saved_playlist.dart';
import '../models/track.dart';

/// Service that scans the Offtunes music folder and builds the track library.
class LibraryService {
  /// Scans the Offtunes directory for MP3 files and reads ID3 tags.
  Future<List<Track>> scanLibrary() async {
    final dir = await getOfftunesDir();
    if (!await dir.exists()) return [];

    final List<Track> tracks = [];
    final List<FileSystemEntity> entities;
    
    try {
      entities = dir.listSync(recursive: true);
    } catch (e) {
      debugPrint('LibraryService: Failed to list directory (permission denied?): $e');
      return [];
    }

      final files = entities
          .whereType<File>()
          .where((f) {
            final lower = f.path.toLowerCase();
            return lower.endsWith('.mp3') || lower.endsWith('.m4a');
          })
          .toList();

    for (final file in files) {
      try {
        final metadata = readMetadata(file, getImage: true);

        final title = metadata.title?.isNotEmpty == true
            ? metadata.title!
            : _fileNameWithoutExt(file);
        final artistName = metadata.artist ?? 'Unknown Artist';
        final albumName = metadata.album ?? 'Unknown Album';
        final trackNum = metadata.trackNumber ?? 1;
        final discNum = metadata.discNumber ?? 1;
        final durationMs = metadata.duration?.inMilliseconds ?? 0;

        // Extract cover art if available
        String coverArtUrl = '';
        if (metadata.pictures.isNotEmpty) {
          try {
            final pic = metadata.pictures.first;
            final tempDir = Directory.systemTemp;
            final hash = file.path.hashCode.toRadixString(16);
            final coverFile = File('${tempDir.path}/offtunes_cover_$hash.jpg');
            if (!coverFile.existsSync()) {
              await coverFile.writeAsBytes(pic.bytes);
            }
            coverArtUrl = coverFile.path;
          } catch (_) {
            // Cover art extraction failed — not critical
          }
        }

        tracks.add(Track(
          id: file.path.hashCode.toRadixString(16),
          title: title,
          artists: artistName.split(',').map((s) => s.trim()).toList(),
          album: albumName,
          coverArtUrl: coverArtUrl,
          durationMs: durationMs,
          trackNumber: trackNum,
          discNumber: discNum,
          filePath: file.path,
        ));
      } catch (e) {
        debugPrint('LibraryService: failed to read tags for ${file.path}: $e');
      }
    }

    // Sort alphabetically by title
    tracks.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    return tracks;
  }

  /// Groups tracks by album name.
  Map<String, List<Track>> groupByAlbum(List<Track> tracks) {
    final map = <String, List<Track>>{};
    for (final track in tracks) {
      map.putIfAbsent(track.album, () => []).add(track);
    }
    final sorted = Map.fromEntries(
      map.entries.toList()
        ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase())),
    );
    return sorted;
  }

  /// Gets the total disk size of the Offtunes folder in bytes.
  Future<int> getFolderSizeBytes() async {
    final dir = await getOfftunesDir();
    if (!await dir.exists()) return 0;

    int totalSize = 0;
    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
    } catch (_) {}
    return totalSize;
  }

  // ── Playlist persistence ───────────────────────────────────────────────────

  Future<File> _playlistsFile() async {
    final dir = await getOfftunesDir();
    return File('${dir.path}${Platform.pathSeparator}playlists.json');
  }

  /// Saves a new playlist to playlists.json (appends; does not overwrite).
  Future<void> savePlaylist(String name, List<Track> tracks) async {
    if (tracks.isEmpty) return;
    try {
      final file = await _playlistsFile();
      List<dynamic> existing = [];
      if (await file.exists()) {
        final raw = await file.readAsString();
        if (raw.trim().isNotEmpty) {
          existing = jsonDecode(raw) as List<dynamic>;
        }
      }
      existing.add({
        'name': name,
        'createdAt': DateTime.now().toIso8601String(),
        'trackFilePaths': tracks.map((t) => t.filePath).toList(),
      });
      await file.writeAsString(jsonEncode(existing));
    } catch (e) {
      debugPrint('LibraryService: savePlaylist failed — $e');
    }
  }

  /// Loads all saved playlists, resolving tracks against the scanned library.
  Future<List<SavedPlaylist>> loadPlaylists(List<Track> libraryTracks) async {
    try {
      final file = await _playlistsFile();
      if (!await file.exists()) return [];
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return [];

      final list = jsonDecode(raw) as List<dynamic>;
      final pathToTrack = {for (final t in libraryTracks) t.filePath: t};

      return list.map((entry) {
        final map = entry as Map<String, dynamic>;
        final paths = (map['trackFilePaths'] as List<dynamic>)
            .cast<String>();
        final resolved = paths
            .map((p) => pathToTrack[p])
            .whereType<Track>()
            .toList();
        return SavedPlaylist(
          name: map['name'] as String,
          createdAt: DateTime.parse(map['createdAt'] as String),
          tracks: resolved,
        );
      }).toList();
    } catch (e) {
      debugPrint('LibraryService: loadPlaylists failed — $e');
      return [];
    }
  }

  /// Returns the current number of saved playlists without fully loading them.
  Future<int> playlistCount() async {
    try {
      final file = await _playlistsFile();
      if (!await file.exists()) return 0;
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return 0;
      final list = jsonDecode(raw) as List<dynamic>;
      return list.length;
    } catch (_) {
      return 0;
    }
  }

  /// Renames a playlist at the given index in playlists.json.
  Future<void> renamePlaylist(int index, String newName) async {
    final file = await _playlistsFile();
    if (!await file.exists()) return;
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return;

    final list = jsonDecode(raw) as List<dynamic>;
    if (index < 0 || index >= list.length) return;

    (list[index] as Map<String, dynamic>)['name'] = newName;
    await file.writeAsString(jsonEncode(list));
  }

  /// Merges a source playlist into a destination playlist, then deletes the source.
  Future<void> mergePlaylists(int sourceIndex, int destIndex) async {
    final file = await _playlistsFile();
    if (!await file.exists()) return;
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return;

    final list = jsonDecode(raw) as List<dynamic>;
    if (sourceIndex < 0 || sourceIndex >= list.length || destIndex < 0 || destIndex >= list.length || sourceIndex == destIndex) return;

    final sourcePlaylist = list[sourceIndex] as Map<String, dynamic>;
    final destPlaylist = list[destIndex] as Map<String, dynamic>;

    final sourcePaths = (sourcePlaylist['trackFilePaths'] as List<dynamic>).cast<String>();
    final destPaths = (destPlaylist['trackFilePaths'] as List<dynamic>).cast<String>();

    // Add paths from source to dest, avoiding exact duplicates
    final newDestPaths = destPaths.toList();
    for (var path in sourcePaths) {
      if (!newDestPaths.contains(path)) {
        newDestPaths.add(path);
      }
    }
    
    destPlaylist['trackFilePaths'] = newDestPaths;
    
    // Remove the source playlist
    list.removeAt(sourceIndex);

    await file.writeAsString(jsonEncode(list));
  }

  String _fileNameWithoutExt(File file) {
    final name = file.uri.pathSegments.last;
    final dotIndex = name.lastIndexOf('.');
    return dotIndex > 0
        ? name.substring(0, dotIndex).replaceAll('_', ' ')
        : name;
  }
}
