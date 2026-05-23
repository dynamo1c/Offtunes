import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/constants.dart';
import '../services/audio_service.dart';
import '../screens/now_playing_screen.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int?>(
      stream: AudioService.instance.currentIndexStream,
      builder: (context, indexSnap) {
        return StreamBuilder<PlayerState>(
          stream: AudioService.instance.playerStateStream,
          builder: (context, stateSnap) {
            final audio = AudioService.instance;
            final track = audio.currentTrack;

            // If no track loaded, show empty state
            if (track == null) {
              return _buildEmpty();
            }

            final isPlaying = stateSnap.data?.playing ?? false;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NowPlayingScreen()),
                );
              },
              child: Container(
                height: 56,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceRaised,
                  border: Border(
                      top: BorderSide(color: AppColors.pink, width: 1.5)),
                ),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          // Cover art or icon
                          _buildThumb(track.coverArtUrl),
                          const SizedBox(width: 12),
                          // Title + Artist
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  track.title,
                                  style: GoogleFonts.shareTechMono(
                                      fontSize: 14, color: AppColors.text),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
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
                          // Play/pause button
                          _MiniPlayButton(
                            isPlaying: isPlaying,
                            onTap: () => audio.togglePlayPause(),
                          ),
                        ],
                      ),
                    ),
                    // Progress bar
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: StreamBuilder<Duration>(
                        stream: audio.positionStream,
                        builder: (context, posSnap) {
                          return StreamBuilder<Duration?>(
                            stream: audio.durationStream,
                            builder: (context, durSnap) {
                              final pos = posSnap.data ?? Duration.zero;
                              final dur = durSnap.data ?? Duration.zero;
                              final pct = dur.inMilliseconds > 0
                                  ? pos.inMilliseconds / dur.inMilliseconds
                                  : 0.0;
                              return FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: pct.clamp(0.0, 1.0),
                                child: Container(height: 2, color: AppColors.rose),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(
            top: BorderSide(color: AppColors.pink, width: 1.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(2),
              ),
              child: const Icon(PhosphorIconsRegular.musicNote,
                  color: AppColors.textSoft),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NO MEDIA',
                      style: GoogleFonts.shareTechMono(
                          fontSize: 14, color: AppColors.text)),
                  Text('—',
                      style: GoogleFonts.dmSans(
                          fontSize: 11, color: AppColors.textSoft)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumb(String coverArtUrl) {
    if (coverArtUrl.isNotEmpty &&
        (coverArtUrl.startsWith('/') || coverArtUrl.contains('\\'))) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Image.file(
          File(coverArtUrl),
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => _placeholderThumb(),
        ),
      );
    }
    return _placeholderThumb();
  }

  Widget _placeholderThumb() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(2),
      ),
      child: const Icon(PhosphorIconsRegular.musicNote,
          color: AppColors.textSoft, size: 20),
    );
  }
}

/// Small play/pause button that stops propagation so the mini player
/// GestureDetector doesn't navigate to NowPlayingScreen.
class _MiniPlayButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const _MiniPlayButton({required this.isPlaying, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          border: Border.all(color: AppColors.pink, width: 1.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          isPlaying ? PhosphorIconsRegular.pause : PhosphorIconsRegular.play,
          size: 16,
          color: AppColors.mauve,
        ),
      ),
    );
  }
}
