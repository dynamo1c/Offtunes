import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/constants.dart';
import '../models/saved_playlist.dart';
import '../models/track.dart';
import '../services/audio_service.dart';
import '../services/feedback_service.dart';
import '../widgets/hw_button.dart';
import 'now_playing_screen.dart';

class PlaylistDetailScreen extends StatelessWidget {
  final SavedPlaylist playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    final tracks = playlist.tracks;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  HwButton(
                    text: '',
                    icon: const Icon(PhosphorIconsRegular.caretLeft,
                        size: 20, color: AppColors.mauve),
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      playlist.name.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.shareTechMono(
                          fontSize: 14, color: AppColors.mauve),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Spacer to keep title centred
                  const SizedBox(width: 60),
                ],
              ),
            ),

            // ── Cover grid + info ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // 2×2 cover grid
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      width: 120,
                      height: 120,
                      child: _buildCoverGrid(tracks),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    playlist.name,
                    style: GoogleFonts.dmSans(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${playlist.trackCount} TRACKS',
                    style: GoogleFonts.shareTechMono(
                        fontSize: 11, color: AppColors.textSoft),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HwButton(
                        text: '▶ PLAY ALL',
                        isPrimary: true,
                        onTap: () {
                          if (tracks.isEmpty) return;
                          AudioService.instance
                              .playTrack(tracks.first, queue: tracks, index: 0);
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => const NowPlayingScreen()));
                        },
                      ),
                      const SizedBox(width: 12),
                      HwButton(
                        text: '⇄ SHUFFLE',
                        onTap: () {
                          if (tracks.isEmpty) return;
                          AudioService.instance.shuffle(tracks);
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => const NowPlayingScreen()));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // ── Track list ──
            Expanded(
              child: tracks.isEmpty
                  ? Center(
                      child: Text(
                        '[ NO TRACKS ]',
                        style: GoogleFonts.shareTechMono(
                            fontSize: 16, color: AppColors.textSoft),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: tracks.length,
                      separatorBuilder: (context, index) => const Divider(
                          height: 1, thickness: 1, color: AppColors.pink),
                      itemBuilder: (context, i) {
                        final track = tracks[i];
                        return _TrackRow(
                          track: track,
                          onTap: () {
                            AudioService.instance.playTrack(track,
                                queue: tracks, index: i);
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const NowPlayingScreen()));
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverGrid(List<Track> tracks) {
    final covers = tracks.take(4).toList();
    if (covers.isEmpty) {
      return Container(
        color: AppColors.surfaceRaised,
        child: const Center(
          child: Icon(PhosphorIconsRegular.musicNote,
              size: 40, color: AppColors.textSoft),
        ),
      );
    }
    return GridView.count(
      crossAxisCount: 2,
      physics: const NeverScrollableScrollPhysics(),
      children: List.generate(4, (i) {
        final track = i < covers.length ? covers[i] : null;
        return _coverCell(track);
      }),
    );
  }

  Widget _coverCell(Track? track) {
    if (track == null || track.coverArtUrl.isEmpty) {
      return Container(
        color: AppColors.surfaceRaised,
        child: const Center(
          child: Icon(PhosphorIconsRegular.musicNote,
              size: 20, color: AppColors.textSoft),
        ),
      );
    }
    if (track.coverArtUrl.startsWith('/') ||
        track.coverArtUrl.contains('\\')) {
      return Image.file(File(track.coverArtUrl),
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, stack) => Container(
              color: AppColors.surfaceRaised,
              child: const Icon(PhosphorIconsRegular.musicNote,
                  size: 20, color: AppColors.textSoft)));
    }
    return Image.network(track.coverArtUrl,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => Container(
            color: AppColors.surfaceRaised,
            child: const Icon(PhosphorIconsRegular.musicNote,
                size: 20, color: AppColors.textSoft)));
  }
}

// ── Shared track row widget ────────────────────────────────────────────────

class _TrackRow extends StatelessWidget {
  final Track track;
  final VoidCallback onTap;

  const _TrackRow({required this.track, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTapDown: (_) => FeedbackService.instance.clickSoft(),
      onTap: onTap,
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
                child: _buildCover(track.coverArtUrl),
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
  }

  Widget _buildCover(String url) {
    if (url.isEmpty) {
      return Container(
          color: AppColors.surfaceRaised,
          child: const Center(
              child: Icon(PhosphorIconsRegular.musicNote,
                  size: 20, color: AppColors.textSoft)));
    }
    if (url.startsWith('/') || url.contains('\\')) {
      return Image.file(File(url),
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, stack) => Container(
              color: AppColors.surfaceRaised,
              child: const Icon(PhosphorIconsRegular.musicNote,
                  size: 20, color: AppColors.textSoft)));
    }
    return Image.network(url,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => Container(
            color: AppColors.surfaceRaised,
            child: const Icon(PhosphorIconsRegular.musicNote,
                size: 20, color: AppColors.textSoft)));
  }

  String _formatDuration(int ms) {
    final m = ms ~/ 60000;
    final s = (ms ~/ 1000) % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
