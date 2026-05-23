import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/constants.dart';
import '../core/paths.dart';
import '../models/saved_playlist.dart';
import '../providers/library_provider.dart';
import '../services/ffmpeg_service.dart';
import '../services/feedback_service.dart';
import '../widgets/hw_button.dart';
import '../widgets/panel.dart';

/// Screen for converting M4A playlists to MP3 format.
/// Accessed from the Settings panel.
class ConvertScreen extends ConsumerStatefulWidget {
  const ConvertScreen({super.key});

  @override
  ConsumerState<ConvertScreen> createState() => _ConvertScreenState();
}

class _ConvertScreenState extends ConsumerState<ConvertScreen> {
  final FfmpegService _ffmpeg = FfmpegService();
  final Set<int> _selectedIndices = {};
  bool _isConverting = false;
  int _convertedCount = 0;
  int _totalToConvert = 0;
  String _currentTrackName = '';
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final playlists = library.playlists;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.caretLeft,
              color: AppColors.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'CONVERT TO MP3',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.0,
            color: AppColors.text,
          ),
        ),
        centerTitle: true,
      ),
      body: _isConverting ? _buildProgressView() : _buildSelectionView(playlists),
    );
  }

  // ── Selection View ──────────────────────────────────────────────────────

  Widget _buildSelectionView(List<SavedPlaylist> playlists) {
    if (playlists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIconsRegular.musicNote,
                size: 48, color: AppColors.textSoft),
            const SizedBox(height: 16),
            Text(
              'NO PLAYLISTS FOUND',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSoft,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Download some music first',
              style: GoogleFonts.shareTechMono(
                  fontSize: 12, color: AppColors.textSoft),
            ),
          ],
        ),
      );
    }

    // Count how many m4a tracks are in the selected playlists
    final m4aCount = _getM4aTracksFromSelection(playlists).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text(
            'SELECT PLAYLISTS TO CONVERT',
            style: GoogleFonts.dmSans(
              fontSize: 10,
              letterSpacing: 2.5,
              color: AppColors.textSoft,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Only M4A files will be converted. MP3 files are skipped.',
            style: GoogleFonts.shareTechMono(
                fontSize: 10, color: AppColors.textSoft),
          ),
        ),
        const SizedBox(height: 12),

        // Playlist list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: playlists.length,
            separatorBuilder: (context, index) => const Divider(
                height: 1, thickness: 1, color: AppColors.pink),
            itemBuilder: (context, i) {
              final playlist = playlists[i];
              final isSelected = _selectedIndices.contains(i);
              final m4aInPlaylist = playlist.tracks
                  .where((t) => t.filePath.toLowerCase().endsWith('.m4a'))
                  .length;

              return InkWell(
                onTapDown: (_) => FeedbackService.instance.clickSoft(),
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedIndices.remove(i);
                    } else {
                      _selectedIndices.add(i);
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    children: [
                      // Checkbox
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.rose
                                : AppColors.textSoft,
                            width: 2,
                          ),
                          color:
                              isSelected ? AppColors.rose : Colors.transparent,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                size: 14, color: AppColors.bg)
                            : null,
                      ),
                      const SizedBox(width: 14),
                      // Info
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
                              '${playlist.trackCount} tracks · $m4aInPlaylist convertible',
                              style: GoogleFonts.shareTechMono(
                                  fontSize: 11, color: AppColors.textSoft),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Bottom bar
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: const Border(
              top: BorderSide(color: AppColors.pink, width: 1),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_selectedIndices.length} PLAYLIST${_selectedIndices.length == 1 ? '' : 'S'}',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                      Text(
                        '$m4aCount M4A TRACK${m4aCount == 1 ? '' : 'S'}',
                        style: GoogleFonts.shareTechMono(
                            fontSize: 11, color: AppColors.textSoft),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 40,
                  width: 140,
                  child: HwButton(
                    text: 'CONVERT',
                    isPrimary: true,
                    onTap: (_selectedIndices.isEmpty || m4aCount == 0)
                        ? () {} // disabled
                        : () => _startConversion(playlists),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Progress View ───────────────────────────────────────────────────────

  Widget _buildProgressView() {
    final progress =
        _totalToConvert > 0 ? _convertedCount / _totalToConvert : 0.0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Spinning icon
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 3,
                color: AppColors.rose,
                backgroundColor: AppColors.pink,
              ),
            ),
            const SizedBox(height: 32),

            Text(
              'CONVERTING TO MP3',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              '$_convertedCount / $_totalToConvert',
              style: GoogleFonts.shareTechMono(
                  fontSize: 20, color: AppColors.rose),
            ),
            const SizedBox(height: 16),

            if (_currentTrackName.isNotEmpty)
              Text(
                _currentTrackName,
                style: GoogleFonts.shareTechMono(
                    fontSize: 11, color: AppColors.textSoft),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Panel(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _errorMessage!,
                  style: GoogleFonts.shareTechMono(
                      fontSize: 11, color: AppColors.error),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Conversion Logic ────────────────────────────────────────────────────

  List<String> _getM4aTracksFromSelection(List<SavedPlaylist> playlists) {
    final paths = <String>{};
    for (final idx in _selectedIndices) {
      if (idx < playlists.length) {
        for (final track in playlists[idx].tracks) {
          if (track.filePath.toLowerCase().endsWith('.m4a')) {
            paths.add(track.filePath);
          }
        }
      }
    }
    return paths.toList();
  }

  Future<void> _startConversion(List<SavedPlaylist> playlists) async {
    final m4aPaths = _getM4aTracksFromSelection(playlists);
    if (m4aPaths.isEmpty) return;

    setState(() {
      _isConverting = true;
      _convertedCount = 0;
      _totalToConvert = m4aPaths.length;
      _errorMessage = null;
    });

    // Save MP3s into a dedicated subfolder so they don't mix with M4A files
    final baseDir = await getOfftunesDir();
    final mp3Dir = Directory('${baseDir.path}${Platform.pathSeparator}MP3_Exports');
    if (!await mp3Dir.exists()) {
      await mp3Dir.create(recursive: true);
    }

    int failCount = 0;

    for (final m4aPath in m4aPaths) {
      final file = File(m4aPath);
      if (!await file.exists()) {
        failCount++;
        continue;
      }

      // Derive filename from the m4a path
      final basename = file.uri.pathSegments.last;
      final nameWithoutExt = basename.contains('.')
          ? basename.substring(0, basename.lastIndexOf('.'))
          : basename;

      setState(() {
        _currentTrackName = nameWithoutExt.replaceAll('_', ' ');
      });

      try {
        await _ffmpeg.convertToMp3(
          inputPath: m4aPath,
          outputDir: mp3Dir.path,
          filename: nameWithoutExt,
        );
      } catch (e) {
        failCount++;
        debugPrint('ConvertScreen: failed to convert $basename — $e');
      }

      setState(() {
        _convertedCount++;
      });
    }

    // Refresh the library so new MP3 files show up
    ref.read(libraryProvider).refresh();

    FeedbackService.instance.success();

    if (mounted) {
      setState(() {
        _isConverting = false;
        if (failCount > 0) {
          _errorMessage = '$failCount track${failCount == 1 ? '' : 's'} failed to convert.';
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failCount == 0
                ? 'Saved ${m4aPaths.length} MP3s to MP3_Exports/'
                : 'Converted ${m4aPaths.length - failCount}/${m4aPaths.length} tracks.',
          ),
          backgroundColor: AppColors.mauve,
        ),
      );

      Navigator.of(context).pop();
    }
  }
}
