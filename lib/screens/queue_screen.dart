import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/constants.dart';
import '../services/audio_service.dart';
import '../widgets/hw_button.dart';

class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            border: Border(
              top: BorderSide(color: AppColors.pink, width: 1.5),
              left: BorderSide(color: AppColors.pink, width: 1.5),
              right: BorderSide(color: AppColors.pink, width: 1.5),
            ),
          ),
          child: Column(
            children: [
              // ── Handle ──
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.pink,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ── Header ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'QUEUE',
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        color: AppColors.mauve,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                      ),
                    ),
                    HwButton(
                      text: 'CLEAR ALL',
                      onTap: () {
                        AudioService.instance.clearQueue();
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),

              // ── Track List ──
              Expanded(
                child: StreamBuilder<PlayerState>(
                  stream: AudioService.instance.playerStateStream,
                  builder: (context, snapshot) {
                    final audio = AudioService.instance;
                    final queue = audio.queue;
                    final currentIdx = audio.currentIndex;
                    final currentTrack = audio.currentTrack;

                    return ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        // Currently playing
                        if (currentTrack != null) ...[
                          const SizedBox(height: 4),
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                top: -14,
                                left: 16,
                                child: Text(
                                  '▶ NOW',
                                  style: GoogleFonts.shareTechMono(
                                      fontSize: 9, color: AppColors.rose),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceRaised,
                                  borderRadius: BorderRadius.circular(4),
                                  border: const Border(
                                    left: BorderSide(
                                        color: AppColors.rose, width: 3),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currentTrack.title,
                                      style: GoogleFonts.shareTechMono(
                                          fontSize: 14,
                                          color: AppColors.text),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      currentTrack.artistString,
                                      style: GoogleFonts.dmSans(
                                          fontSize: 11,
                                          color: AppColors.textSoft),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Upcoming tracks
                        ...List.generate(
                          queue.length - (currentIdx + 1) > 0
                              ? queue.length - (currentIdx + 1)
                              : 0,
                          (i) {
                            final trackIdx = currentIdx + 1 + i;
                            final track = queue[trackIdx];
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                AudioService.instance.jumpTo(trackIdx);
                              },
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                        color: AppColors.pink, width: 1),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                        PhosphorIconsRegular.dotsSixVertical,
                                        color: AppColors.textSoft,
                                        size: 16),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            track.title,
                                            style:
                                                GoogleFonts.shareTechMono(
                                                    fontSize: 14,
                                                    color: AppColors.text),
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            track.artistString,
                                            style: GoogleFonts.dmSans(
                                                fontSize: 11,
                                                color:
                                                    AppColors.textSoft),
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow.ellipsis,
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
                      ],
                    );
                  },
                ),
              ),

              // ── Bottom bar ──
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppColors.bg,
                  border: Border(
                    top: BorderSide(color: AppColors.pink, width: 1.5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PLAYBACK MODE',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        letterSpacing: 2.5,
                        color: AppColors.textSoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    _HwToggle(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Hardware-style toggle switch.
class _HwToggle extends StatefulWidget {
  @override
  State<_HwToggle> createState() => _HwToggleState();
}

class _HwToggleState extends State<_HwToggle> {
  bool _isOn = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _isOn = !_isOn),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 24,
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          border: Border.all(color: AppColors.pink, width: 1.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              left: _isOn ? 24 : 2,
              top: 1.5,
              child: Container(
                width: 20,
                height: 18,
                decoration: BoxDecoration(
                  color: _isOn ? AppColors.rose : AppColors.mauve,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
