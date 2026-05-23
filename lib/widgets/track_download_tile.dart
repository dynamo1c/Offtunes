import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/download_state.dart';
import '../core/constants.dart';

class TrackDownloadTile extends StatelessWidget {
  final TrackDownloadState state;

  const TrackDownloadTile({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final isActive = state.status == DownloadStatus.downloading ||
        state.status == DownloadStatus.converting ||
        state.status == DownloadStatus.tagging;

    return GestureDetector(
      onTap: state.status == DownloadStatus.done
          ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('File at: ${state.outputPath}')),
              );
            }
          : state.status == DownloadStatus.failed
              ? () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.surface,
                      title: Text('Download Failed',
                          style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.bold,
                              color: AppColors.text)),
                      content: Text(state.errorMessage ?? 'Unknown error',
                          style: GoogleFonts.shareTechMono(
                              fontSize: 12, color: AppColors.textSoft)),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text('OK',
                                style: GoogleFonts.dmSans(
                                    color: AppColors.rose)))
                      ],
                    ),
                  );
                }
              : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: cover + info + status icon ──
            Row(
              children: [
                // Cover art
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      image: state.track.coverArtUrl.isNotEmpty
                          ? DecorationImage(
                              image:
                                  NetworkImage(state.track.coverArtUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: state.track.coverArtUrl.isEmpty
                        ? const Center(
                            child: Icon(PhosphorIconsRegular.musicNote,
                                size: 20, color: AppColors.textSoft))
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                // Title + artist
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.track.title,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        state.track.artistString,
                        style: GoogleFonts.shareTechMono(
                            fontSize: 11, color: AppColors.textSoft),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Status icon
                _buildStatusIcon(),
              ],
            ),

            // ── Progress bar (only while downloading / converting) ──
            if (isActive) ...[
              const SizedBox(height: 10),
              _buildProgressBar(),
            ],
          ],
        ),
      ),
    );
  }

  // ── Status Icon ──────────────────────────────────────────────────────────

  Widget _buildStatusIcon() {
    switch (state.status) {
      case DownloadStatus.queued:
        return _statusChip('QUEUED', AppColors.textSoft);
      case DownloadStatus.paused:
        return _statusChip('PAUSED', AppColors.rose);
      case DownloadStatus.searching:
        return const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
              color: AppColors.rose, strokeWidth: 2),
        );
      case DownloadStatus.downloading:
        return Text(
          '${(state.progress * 100).toStringAsFixed(0)}%',
          style: GoogleFonts.shareTechMono(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.rose,
          ),
        );
      case DownloadStatus.converting:
      case DownloadStatus.tagging:
        return _statusChip('TAGGING', AppColors.mauve);
      case DownloadStatus.done:
        return const Icon(PhosphorIconsRegular.checkCircle,
            color: Color(0xFF4CAF50), size: 20);
      case DownloadStatus.failed:
        return const Icon(PhosphorIconsRegular.warningCircle,
            color: AppColors.error, size: 20);
    }
  }

  Widget _statusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withAlpha(80), width: 1),
      ),
      child: Text(
        text,
        style: GoogleFonts.shareTechMono(fontSize: 9, color: color),
      ),
    );
  }

  // ── Progress Bar ─────────────────────────────────────────────────────────

  Widget _buildProgressBar() {
    final pct = state.progress.clamp(0.0, 1.0);
    final isConverting = state.status == DownloadStatus.converting ||
        state.status == DownloadStatus.tagging;

    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: isConverting
            // Indeterminate shimmer for near-instant tagging step
            ? const LinearProgressIndicator(
                color: AppColors.mauve,
                backgroundColor: AppColors.pink,
              )
            // Determinate bar for download progress
            : LinearProgressIndicator(
                value: pct,
                color: AppColors.rose,
                backgroundColor: AppColors.pink,
              ),
      ),
    );
  }
}
