import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/paths.dart';

import '../models/download_state.dart';
import '../models/track.dart';
import '../providers/download_provider.dart';
import '../widgets/hw_button.dart';
import '../widgets/panel.dart';
import '../widgets/track_download_tile.dart';
import '../core/constants.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _handleFetch() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    ref.read(downloadProvider).fetchTracks(url);
  }

  void _handleStartDownload() {
    ref.read(downloadProvider).startDownloading();
    _urlController.clear();
  }

  void _handleClearFetched() {
    ref.read(downloadProvider).clearFetchedTracks();
    _urlController.clear();
  }

  Future<void> _openFolder() async {
    try {
      final dir = await getOfftunesDir();
      final path = dir.path;

      if (Platform.isWindows) {
        await Process.run('explorer.exe', [path]);
      } else if (Platform.isAndroid) {
        // On modern Android, opening a specific folder is restrictive.
        // We attempt to open the standard Music directory as a fallback
        // or the specific Offtunes folder if supported by the file manager.
        final uri = Uri.parse('content://com.android.externalstorage.documents/document/primary:Music/Offtunes');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          // Fallback to generic music folder
          await launchUrl(Uri.parse('content://com.android.externalstorage.documents/document/primary:Music'));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open folder: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(downloadProvider);

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── URL Input Section ──
          Text(
            'DATA INPUT',
            style: GoogleFonts.dmSans(
              fontSize: 10,
              letterSpacing: 2.5,
              color: AppColors.textSoft,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Panel(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _urlController,
              style: GoogleFonts.shareTechMono(fontSize: 14, color: AppColors.text),
              decoration: InputDecoration(
                hintText: 'PASTE PLAYLIST URL_',
                hintStyle: GoogleFonts.shareTechMono(color: AppColors.textSoft),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) => _handleFetch(),
            ),
          ),
          const SizedBox(height: 20),

          // ── Action buttons — context-dependent ──
          _buildActionButtons(provider),

          // ── Fetch error display ──
          if (provider.fetchError != null && !provider.isFetching) ...[
            const SizedBox(height: 12),
            Panel(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(PhosphorIconsRegular.warningCircle,
                      color: AppColors.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      provider.fetchError!,
                      style: GoogleFonts.dmSans(
                          fontSize: 12, color: AppColors.error),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Fetched tracks preview (before download starts) ──
          if (provider.hasFetchedTracks) ...[
            const SizedBox(height: 24),
            _buildSectionHeader(
              'TRACKS FOUND — ${provider.fetchedTracks.length}',
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: provider.fetchedTracks.length,
                itemBuilder: (context, index) {
                  final track = provider.fetchedTracks[index];
                  return _buildFetchedTrackTile(track, index);
                },
              ),
            ),
          ],

          // ── Download queue (after download starts) ──
          if (!provider.hasFetchedTracks && provider.hasQueuedTracks) ...[
            const SizedBox(height: 24),
            _buildSectionHeader(
              'DOWNLOAD QUEUE — ${provider.completedCount}/${provider.queue.length}',
            ),
            const SizedBox(height: 4),
            // ── Download controls row ──
            _buildDownloadControls(provider),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: provider.queue.length,
                itemBuilder: (context, index) {
                  return TrackDownloadTile(state: provider.queue[index]);
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: HwButton(
                text: 'OPEN FOLDER',
                onTap: _openFolder,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Action Buttons (context-dependent) ─────────────────────────────────

  Widget _buildActionButtons(DownloadProvider provider) {
    // While fetching metadata
    if (provider.isFetching) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: HwButton(
          text: 'FETCHING ...',
          isPrimary: true,
          onTap: () {}, // disabled while fetching
        ),
      );
    }

    // After tracks are fetched — show START DOWNLOAD + CLEAR
    if (provider.hasFetchedTracks) {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 52,
              child: HwButton(
                text: 'START DOWNLOAD',
                isPrimary: true,
                icon: const Icon(PhosphorIconsRegular.downloadSimple,
                    color: AppColors.bg, size: 16),
                onTap: _handleStartDownload,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 52,
            width: 52,
            child: HwButton(
              text: '✕',
              onTap: _handleClearFetched,
            ),
          ),
        ],
      );
    }

    // Default: show LOAD button
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: HwButton(
        text: 'LOAD',
        isPrimary: true,
        onTap: _handleFetch,
      ),
    );
  }

  // ── Download Controls (Pause / Resume / Stop) ───────────────────────────

  Widget _buildDownloadControls(DownloadProvider provider) {
    final allDone = provider.queue.every(
      (t) =>
          t.status == DownloadStatus.done ||
          t.status == DownloadStatus.failed,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          // Pause / Resume toggle (only while downloads are active)
          if (!allDone) ...[
            if (provider.isPaused)
              _buildSmallButton(
                icon: PhosphorIconsRegular.play,
                label: 'RESUME',
                onTap: () => provider.resumeDownloads(),
              )
            else
              _buildSmallButton(
                icon: PhosphorIconsRegular.pause,
                label: 'PAUSE',
                onTap: () => provider.pauseDownloads(),
              ),
            const SizedBox(width: 8),
            // Stop
            _buildSmallButton(
              icon: PhosphorIconsRegular.stop,
              label: 'STOP',
              onTap: () => provider.stopDownloads(),
              isDestructive: true,
            ),
          ],

          // Resume failed downloads (when all done but some failed)
          if (allDone && provider.failedCount > 0)
            _buildSmallButton(
              icon: PhosphorIconsRegular.arrowClockwise,
              label: 'RESUME ${provider.failedCount}',
              onTap: () => provider.retryFailed(),
            ),

          const Spacer(),

          // New Import — always visible to let user reset and start fresh
          _buildSmallButton(
            icon: PhosphorIconsRegular.plusCircle,
            label: 'NEW IMPORT',
            onTap: () => provider.clearAll(),
          ),
        ],
      ),
    );
  }

  // ── Fetched Track Tile (preview before download) ───────────────────────

  Widget _buildFetchedTrackTile(Track track, int index) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          // Track number
          SizedBox(
            width: 28,
            child: Text(
              '${index + 1}',
              style: GoogleFonts.shareTechMono(
                fontSize: 12,
                color: AppColors.textSoft,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          // Cover art
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(2),
              image: track.coverArtUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(track.coverArtUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: track.coverArtUrl.isEmpty
                ? const Icon(PhosphorIconsRegular.musicNote,
                    color: AppColors.textSoft, size: 18)
                : null,
          ),
          const SizedBox(width: 12),
          // Title + Artist
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  style: GoogleFonts.shareTechMono(
                      fontSize: 13, color: AppColors.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  track.artistString,
                  style: GoogleFonts.dmSans(
                      fontSize: 11, color: AppColors.textSoft),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Duration
          if (track.durationMs > 0)
            Text(
              _formatDuration(track.durationMs),
              style: GoogleFonts.shareTechMono(
                  fontSize: 11, color: AppColors.textSoft),
            ),
          const SizedBox(width: 8),
          // Remove button
          GestureDetector(
            onTap: () => ref.read(downloadProvider).removeFetchedTrack(index),
            child: const Icon(PhosphorIconsRegular.x,
                color: AppColors.textSoft, size: 16),
          ),
        ],
      ),
    );
  }

  // ── Small Control Button ───────────────────────────────────────────────

  Widget _buildSmallButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDestructive
              ? AppColors.error.withValues(alpha: 0.1)
              : AppColors.surfaceRaised,
          border: Border.all(
            color: isDestructive ? AppColors.error : AppColors.pink,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: isDestructive ? AppColors.error : AppColors.mauve),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDestructive ? AppColors.error : AppColors.mauve,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section Header ────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.rose, width: 2)),
      ),
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        title,
        style: GoogleFonts.dmSans(
          fontSize: 10,
          letterSpacing: 2.5,
          color: AppColors.textSoft,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ── Duration Formatter ────────────────────────────────────────────────

  String _formatDuration(int ms) {
    final totalSeconds = ms ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
