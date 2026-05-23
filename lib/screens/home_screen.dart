import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import '../core/constants.dart';
import '../core/paths.dart';
import '../models/track.dart';
import '../providers/library_provider.dart';
import '../services/audio_service.dart';
import '../services/feedback_service.dart';
import 'now_playing_screen.dart';
import 'playlist_detail_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isSongs = true;

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final tracks = library.allTracks;

    return Column(
      children: [
        // ── Top Bar ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('OFFTUNES',
                  style: GoogleFonts.shareTechMono(
                      fontSize: 20, color: AppColors.mauve)),
              // Track count badge (Songs tab) or folder size
              _isSongs
                  ? _lcdbadge('[ ${tracks.length} TRACKS ]')
                  : _lcdbadge('[ SYS ${library.folderSizeFormatted} ]'),
            ],
          ),
        ),

        // ── Tab switcher ──
        Container(
          decoration: const BoxDecoration(
            border: Border(
                bottom: BorderSide(color: AppColors.pink, width: 1.5)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 20),
              GestureDetector(
                onTap: () => setState(() => _isSongs = true),
                child: _buildTab('SONGS', _isSongs),
              ),
              const SizedBox(width: 24),
              GestureDetector(
                onTap: () => setState(() => _isSongs = false),
                child: _buildTab('PLAYLISTS', !_isSongs),
              ),
            ],
          ),
        ),

        // ── Content ──
        Expanded(
          child: library.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.rose))
              : _isSongs
                  ? _buildSongsTab(library)
                  : _buildPlaylistsTab(library),
        ),
      ],
    );
  }

  // ── Songs Tab ─────────────────────────────────────────────────────────────

  Widget _buildSongsTab(LibraryProvider library) {
    final tracks = library.allTracks;
    if (tracks.isEmpty) {
      return _buildEmptyState('NO MEDIA LOADED', 'Import a playlist to begin');
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: tracks.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, thickness: 1, color: AppColors.pink),
      itemBuilder: (context, i) {
        final track = tracks[i];
        return InkWell(
          onTapDown: (_) => FeedbackService.instance.clickSoft(),
          onTap: () {
            AudioService.instance
                .playTrack(track, queue: tracks, index: i);
            Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const NowPlayingScreen()),
            );
          },
          onLongPress: () => _showTrackOptions(context, track),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                // Cover art
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: _buildCoverArt(track.coverArtUrl),
                  ),
                ),
                const SizedBox(width: 12),
                // Title + artist
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        track.artistString,
                        style: GoogleFonts.shareTechMono(
                            fontSize: 11, color: AppColors.textSoft),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Duration
                Text(
                  _formatDuration(track.durationMs),
                  style: GoogleFonts.shareTechMono(
                      fontSize: 11, color: AppColors.textSoft),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Playlists Tab ─────────────────────────────────────────────────────────

  Widget _buildPlaylistsTab(LibraryProvider library) {
    final playlists = library.playlists;
    if (playlists.isEmpty) {
      return _buildEmptyState(
          'NO PLAYLISTS', 'Playlists are created after importing tracks');
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: playlists.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, thickness: 1, color: AppColors.pink),
      itemBuilder: (context, i) {
        final playlist = playlists[i];
        final cover = playlist.coverTrack;
        return InkWell(
          onTapDown: (_) => FeedbackService.instance.clickSoft(),
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    PlaylistDetailScreen(playlist: playlist)));
          },
          onLongPress: () => _showPlaylistOptions(context, i, playlist.name),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                // First track cover
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: _buildCoverArt(cover?.coverArtUrl ?? ''),
                  ),
                ),
                const SizedBox(width: 12),
                // Name + count
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.name,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${playlist.trackCount} tracks',
                        style: GoogleFonts.shareTechMono(
                            fontSize: 11, color: AppColors.textSoft),
                      ),
                    ],
                  ),
                ),
                const Icon(PhosphorIconsRegular.caretRight,
                    size: 16, color: AppColors.textSoft),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Track Context Menu ────────────────────────────────────────────────────

  void _showTrackOptions(BuildContext context, Track track) {
    FeedbackService.instance.clickPrimary();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Text(
                    track.title,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                const Divider(height: 1, color: AppColors.pink),
                // Rename
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.pencilSimple,
                      color: AppColors.mauve),
                  title: Text('Rename File',
                      style: GoogleFonts.dmSans(
                          fontSize: 14, color: AppColors.text)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showRenameDialog(context, track);
                  },
                ),
                // Share File
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.shareNetwork,
                      color: AppColors.mauve),
                  title: Text('Share',
                      style: GoogleFonts.dmSans(
                          fontSize: 14, color: AppColors.text)),
                  onTap: () {
                    Navigator.pop(ctx);
                    // ignore: deprecated_member_use
                    Share.shareXFiles([XFile(track.filePath)], text: 'Shared via Offtunes');
                  },
                ),
                // Open in Explorer
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.folderOpen,
                      color: AppColors.mauve),
                  title: Text(
                    Platform.isWindows
                        ? 'Show in Explorer'
                        : 'Open in File Manager',
                    style: GoogleFonts.dmSans(
                        fontSize: 14, color: AppColors.text),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openInExplorer(track.filePath);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRenameDialog(BuildContext context, Track track) {
    // Get current filename without extension
    final file = File(track.filePath);
    final fullName = file.uri.pathSegments.last;
    final ext = fullName.contains('.')
        ? fullName.substring(fullName.lastIndexOf('.'))
        : '';
    final nameWithoutExt = fullName.contains('.')
        ? fullName.substring(0, fullName.lastIndexOf('.'))
        : fullName;

    final controller = TextEditingController(text: nameWithoutExt);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            'RENAME FILE',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
              color: AppColors.text,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Extension: $ext',
                style: GoogleFonts.shareTechMono(
                    fontSize: 10, color: AppColors.textSoft),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                style: GoogleFonts.shareTechMono(
                    fontSize: 13, color: AppColors.text),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide:
                        const BorderSide(color: AppColors.pink, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide:
                        const BorderSide(color: AppColors.rose, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('CANCEL',
                  style: GoogleFonts.dmSans(
                      fontSize: 12, color: AppColors.textSoft)),
            ),
            TextButton(
              onPressed: () async {
                final newName = controller.text.trim();
                if (newName.isEmpty || newName == nameWithoutExt) {
                  Navigator.pop(ctx);
                  return;
                }
                // Sanitize
                final safeName = newName.replaceAll(
                    RegExp(r'[\\/:*?"<>|]'), '_');
                final dir = file.parent.path;
                final newPath =
                    '$dir${Platform.pathSeparator}$safeName$ext';

                try {
                  await file.rename(newPath);
                  if (context.mounted) {
                    ref.read(libraryProvider).refresh();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Renamed to $safeName$ext'),
                        backgroundColor: AppColors.mauve,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Rename failed: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text('RENAME',
                  style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.rose)),
            ),
          ],
        );
      },
    );
  }

  void _openInExplorer(String filePath) {
    if (Platform.isWindows) {
      // Open Explorer and select the file
      Process.run('explorer.exe', ['/select,', filePath]);
    } else {
      // On Android/other, open the containing folder
      final dir = File(filePath).parent.path;
      launchUrl(Uri.directory(dir));
    }
  }

  // ── Playlist Context Menu ─────────────────────────────────────────────────

  void _showPlaylistOptions(
      BuildContext context, int playlistIndex, String currentName) {
    FeedbackService.instance.clickPrimary();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Text(
                    currentName,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Divider(height: 1, color: AppColors.pink),
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.pencilSimple,
                      color: AppColors.mauve),
                  title: Text('Rename Playlist',
                      style: GoogleFonts.dmSans(
                          fontSize: 14, color: AppColors.text)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showRenamePlaylistDialog(
                        context, playlistIndex, currentName);
                  },
                ),
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.arrowsMerge,
                      color: AppColors.mauve),
                  title: Text('Merge into...',
                      style: GoogleFonts.dmSans(
                          fontSize: 14, color: AppColors.text)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showMergeDialog(context, playlistIndex, currentName);
                  },
                ),
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.shareNetwork,
                      color: AppColors.mauve),
                  title: Text('Share Playlist',
                      style: GoogleFonts.dmSans(
                          fontSize: 14, color: AppColors.text)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final tracks = ref.read(libraryProvider).playlists[playlistIndex].tracks;
                    final files = tracks.map((t) => XFile(t.filePath)).toList();
                    if (files.isNotEmpty) {
                      // ignore: deprecated_member_use
                      await Share.shareXFiles(files, text: 'Shared via Offtunes');
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.folderOpen,
                      color: AppColors.mauve),
                  title: Text(
                    Platform.isWindows
                        ? 'Open Music Folder'
                        : 'Open in File Manager',
                    style: GoogleFonts.dmSans(
                        fontSize: 14, color: AppColors.text),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final dir = await getOfftunsDirPath();
                    if (Platform.isWindows) {
                      Process.run('explorer.exe', [dir]);
                    } else {
                      launchUrl(Uri.directory(dir));
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRenamePlaylistDialog(
      BuildContext context, int playlistIndex, String currentName) {
    final controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            'RENAME PLAYLIST',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
              color: AppColors.text,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: GoogleFonts.shareTechMono(
                fontSize: 13, color: AppColors.text),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.bg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide:
                    const BorderSide(color: AppColors.pink, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide:
                    const BorderSide(color: AppColors.rose, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('CANCEL',
                  style: GoogleFonts.dmSans(
                      fontSize: 12, color: AppColors.textSoft)),
            ),
            TextButton(
              onPressed: () async {
                final newName = controller.text.trim();
                if (newName.isEmpty || newName == currentName) {
                  Navigator.pop(ctx);
                  return;
                }
                try {
                  await ref.read(libraryProvider).renamePlaylist(playlistIndex, newName);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Renamed to "$newName"'),
                        backgroundColor: AppColors.mauve,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Rename failed: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text('RENAME',
                  style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.rose)),
            ),
          ],
        );
      },
    );
  }

  void _showMergeDialog(
      BuildContext context, int sourceIndex, String currentName) {
    final library = ref.read(libraryProvider);
    final playlists = library.playlists;
    if (playlists.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Need at least 2 playlists to merge.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            'MERGE INTO...',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
              color: AppColors.text,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: playlists.length,
              itemBuilder: (context, i) {
                if (i == sourceIndex) return const SizedBox.shrink();
                return ListTile(
                  title: Text(playlists[i].name,
                      style: GoogleFonts.dmSans(color: AppColors.text)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      await ref.read(libraryProvider).mergePlaylists(sourceIndex, i);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Merged into "${playlists[i].name}"'),
                            backgroundColor: AppColors.mauve,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Merge failed: $e'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('CANCEL',
                  style: GoogleFonts.dmSans(
                      fontSize: 12, color: AppColors.textSoft)),
            ),
          ],
        );
      },
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _buildEmptyState(String title, String subtitle) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(PhosphorIconsRegular.cassetteTape,
            size: 64, color: AppColors.pink),
        const SizedBox(height: 16),
        Text(title,
            style: GoogleFonts.shareTechMono(
                fontSize: 16, color: AppColors.text)),
        const SizedBox(height: 8),
        Text(subtitle,
            style:
                GoogleFonts.dmSans(fontSize: 12, color: AppColors.textSoft)),
      ],
    );
  }

  Widget _buildCoverArt(String url) {
    if (url.isEmpty) {
      return Container(
        color: AppColors.surfaceRaised,
        child: const Center(
          child: Icon(PhosphorIconsRegular.musicNote,
              size: 24, color: AppColors.textSoft),
        ),
      );
    }
    if (url.startsWith('/') || url.contains('\\')) {
      return Image.file(File(url),
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, stack) => Container(
              color: AppColors.surfaceRaised,
              child: const Center(
                  child: Icon(PhosphorIconsRegular.musicNote,
                      size: 24, color: AppColors.textSoft))));
    }
    return Image.network(url,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => Container(
            color: AppColors.surfaceRaised,
            child: const Center(
                child: Icon(PhosphorIconsRegular.musicNote,
                    size: 24, color: AppColors.textSoft))));
  }

  Widget _buildTab(String label, bool isActive) {
    return Container(
      padding: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isActive ? AppColors.rose : Colors.transparent,
            width: 2,
          ),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isActive ? AppColors.rose : AppColors.textSoft,
        ),
      ),
    );
  }

  Widget _lcdbadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.pink, width: 1.5),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        text,
        style: GoogleFonts.shareTechMono(fontSize: 10, color: AppColors.text),
      ),
    );
  }

  String _formatDuration(int ms) {
    final m = ms ~/ 60000;
    final s = (ms ~/ 1000) % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

