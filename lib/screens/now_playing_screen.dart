import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/constants.dart';
import '../services/audio_service.dart';
import '../widgets/hw_button.dart';
import 'queue_screen.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _formatTime(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showQueueSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QueueScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audio = AudioService.instance;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Row — fixed ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  HwButton(
                    text: '',
                    icon: const Icon(PhosphorIconsRegular.caretDown,
                        size: 20, color: AppColors.mauve),
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  Text(
                    'PLAYBACK ACTIVE',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      letterSpacing: 2.5,
                      color: AppColors.textSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  HwButton(
                    text: '',
                    icon: const Icon(PhosphorIconsRegular.listNumbers,
                        size: 20, color: AppColors.mauve),
                    onTap: _showQueueSheet,
                  ),
                ],
              ),
            ),

            // ── Scrollable content ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // ── NOW PLAYING label ──
                    Text(
                      'NOW PLAYING',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        letterSpacing: 2.5,
                        color: AppColors.textSoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ── LCD Display Panel ──
                    StreamBuilder<int?>(
                      stream: audio.currentIndexStream,
                      builder: (context, indexSnapshot) {
                        return StreamBuilder<PlayerState>(
                          stream: audio.playerStateStream,
                          builder: (context, snapshot) {
                            final track = audio.currentTrack;
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                border:
                                    Border.all(color: AppColors.pink, width: 2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Column(
                                children: [
                                  // Title
                                  Text(
                                    track?.title ?? 'NO SIGNAL',
                                    style: GoogleFonts.shareTechMono(
                                        fontSize: 20, color: AppColors.text),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 4),
                                  // Artist
                                  Text(
                                    track?.artistString ?? '---',
                                    style: GoogleFonts.dmSans(
                                        fontSize: 12, color: AppColors.textSoft),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),

                                  // Glyph Matrix Visualizer
                                  Builder(
                                    builder: (context) {
                                      final playerState = snapshot.data;
                                      final isPlaying =
                                          playerState?.playing == true &&
                                          playerState?.processingState !=
                                              ProcessingState.idle &&
                                          playerState?.processingState !=
                                              ProcessingState.loading;
                                      return GlyphMatrixVisualizer(
                                        isPlaying: isPlaying,
                                        dotColor: AppColors.lcd,
                                        dotOffColor: const Color(0xFFD4C9BE),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 10),

                                  // Time + badges
                                  StreamBuilder<Duration>(
                                    stream: audio.positionStream,
                                    builder: (context, posSnap) {
                                      final pos = posSnap.data ?? Duration.zero;
                                      return StreamBuilder<Duration?>(
                                        stream: audio.durationStream,
                                        builder: (context, durSnap) {
                                          final dur =
                                              durSnap.data ?? Duration.zero;
                                          return Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                '${_formatTime(pos)} / ${_formatTime(dur)}',
                                                style:
                                                    GoogleFonts.shareTechMono(
                                                        fontSize: 13,
                                                        color: AppColors.rose),
                                              ),
                                              Row(
                                                children: [
                                                  _badge(_getFormatBadge()),
                                                  const SizedBox(width: 6),
                                                  _badge(_getBitrateBadge()),
                                                ],
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // ── Seek Slider ──
                    StreamBuilder<Duration>(
                      stream: audio.positionStream,
                      builder: (context, posSnap) {
                        final pos = posSnap.data ?? Duration.zero;
                        return StreamBuilder<Duration?>(
                          stream: audio.durationStream,
                          builder: (context, durSnap) {
                            final dur = durSnap.data ?? Duration.zero;
                            final maxVal = dur.inMilliseconds
                                .toDouble()
                                .clamp(1.0, double.infinity);
                            final curVal = pos.inMilliseconds
                                .toDouble()
                                .clamp(0.0, maxVal);
                            return SliderTheme(
                              data: _sliderTheme(),
                              child: Slider(
                                value: curVal,
                                min: 0,
                                max: maxVal,
                                onChanged: (v) => audio.seekTo(
                                    Duration(milliseconds: v.toInt())),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // ── Transport Controls ──
                    StreamBuilder<PlayerState>(
                      stream: audio.playerStateStream,
                      builder: (context, snapshot) {
                        final isPlaying = snapshot.data?.playing ?? false;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 64,
                              height: 48,
                              child: HwButton(
                                text: '',
                                icon: const Icon(
                                    PhosphorIconsRegular.skipBack,
                                    size: 24, color: AppColors.mauve),
                                onTap: () => audio.previous(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 120,
                              height: 48,
                              child: HwButton(
                                text: '',
                                isPrimary: true,
                                icon: Icon(
                                  isPlaying
                                      ? PhosphorIconsRegular.pause
                                      : PhosphorIconsRegular.play,
                                  size: 28,
                                  color: AppColors.bg,
                                ),
                                onTap: () => audio.togglePlayPause(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 64,
                              height: 48,
                              child: HwButton(
                                text: '',
                                icon: const Icon(
                                    PhosphorIconsRegular.skipForward,
                                    size: 24, color: AppColors.mauve),
                                onTap: () => audio.next(),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // ── Volume Row ──
                    Row(
                      children: [
                        Text(
                          'VOL ▸',
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            letterSpacing: 2.5,
                            color: AppColors.textSoft,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatefulBuilder(
                            builder: (context, setSlider) {
                              double vol = audio.volume;
                              return SliderTheme(
                                data: _sliderTheme(),
                                child: Slider(
                                  value: vol,
                                  min: 0,
                                  max: 1,
                                  onChanged: (v) {
                                    audio.setVolume(v);
                                    setSlider(() {});
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Bottom Action Row ──
                    Row(
                      children: [
                        Expanded(
                          child: HwButton(
                            text: 'QUEUE',
                            onTap: _showQueueSheet,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: HwButton(
                            text: '+ PLAYLIST',
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Coming soon')),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: HwButton(
                            text: 'SHARE',
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Coming soon')),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFormatBadge() {
    final track = AudioService.instance.currentTrack;
    if (track == null || track.filePath.isEmpty) return 'M4A';
    final ext = track.filePath.split('.').last.toUpperCase();
    return ext == 'MP3' ? 'MP3' : 'M4A';
  }

  String _getBitrateBadge() {
    final track = AudioService.instance.currentTrack;
    if (track == null || track.filePath.isEmpty) return 'AAC';
    final ext = track.filePath.split('.').last.toLowerCase();
    return ext == 'mp3' ? '192' : 'AAC';
  }

  Widget _badge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.pink, width: 1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        '[ $label ]',
        style: GoogleFonts.shareTechMono(
            fontSize: 9, color: AppColors.textSoft),
      ),
    );
  }

  SliderThemeData _sliderTheme() {
    return SliderThemeData(
      activeTrackColor: AppColors.rose,
      inactiveTrackColor: AppColors.pink,
      thumbColor: AppColors.mauve,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
      trackHeight: 4,
      overlayShape: SliderComponentShape.noOverlay,
    );
  }
}
// ─────────────────────────────────────────────────────────
// Glyph Matrix Visualizer
// ─────────────────────────────────────────────────────────

class GlyphMatrixVisualizer extends StatefulWidget {
  final bool isPlaying;
  final Color dotColor;
  final Color dotOffColor;
  final int columns;
  final int rows;

  const GlyphMatrixVisualizer({
    super.key,
    required this.isPlaying,
    required this.dotColor,
    required this.dotOffColor,
    this.columns = 16,
    this.rows = 9,
  });

  @override
  State<GlyphMatrixVisualizer> createState() => _GlyphMatrixVisualizerState();
}

class _GlyphMatrixVisualizerState extends State<GlyphMatrixVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<double> _heights;
  late List<double> _peaks;
  final List<double> _frequencies = [];
  final List<double> _phases = [];
  final List<double> _amplitudes = [];
  double _tick = 0.0;

  @override
  void initState() {
    super.initState();
    _heights = List.filled(widget.columns, 0.0);
    _peaks = List.filled(widget.columns, 0.0);

    final rng = math.Random();
    for (int i = 0; i < widget.columns; i++) {
      final double position = i / widget.columns.toDouble();
      _frequencies.add(0.8 + position * 3.5);
      final double bassBoost =
          math.exp(-math.pow(position - 0.15, 2) / 0.05);
      final double midRange =
          math.exp(-math.pow(position - 0.45, 2) / 0.08);
      final double presence =
          math.exp(-math.pow(position - 0.70, 2) / 0.04);
      _amplitudes.add(
          0.35 + bassBoost * 0.65 + midRange * 0.45 + presence * 0.30);
      _phases.add(rng.nextDouble() * math.pi * 2);
    }

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    )..addListener(_onTick);

    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(GlyphMatrixVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _controller.repeat();
    } else if (!widget.isPlaying && oldWidget.isPlaying) {
      // Keep controller ticking so heights can decay to 0
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    }
  }

  void _onTick() {
    final rng = math.Random();

    if (widget.isPlaying) {
      _tick += 0.04;

      for (int i = 0; i < widget.columns; i++) {
        final double wave1 =
            math.sin(_tick * _frequencies[i] + _phases[i]);
        final double wave2 =
            math.sin(_tick * _frequencies[i] * 1.7 + _phases[i] * 0.6) * 0.4;
        final double transient =
            rng.nextDouble() < 0.008 ? rng.nextDouble() * 2.5 : 0.0;
        final double raw = (wave1 + wave2 + transient + 1.0) / 2.0;
        final double target = raw * _amplitudes[i] * widget.rows;

        if (target > _heights[i]) {
          _heights[i] += (target - _heights[i]) * 0.45;
        } else {
          _heights[i] += (target - _heights[i]) * 0.12;
        }
        _heights[i] = _heights[i].clamp(0.0, widget.rows.toDouble());
      }

      // Peak dots: track highest, gravity fall
      for (int i = 0; i < widget.columns; i++) {
        if (_heights[i] > _peaks[i]) {
          _peaks[i] = _heights[i];
        } else {
          _peaks[i] -= 0.04;
          _peaks[i] = _peaks[i].clamp(0.0, widget.rows.toDouble());
        }
      }
    } else {
      _tick += 0.01;
      for (int i = 0; i < widget.columns; i++) {
        _heights[i] *= 0.88;
        _peaks[i] *= 0.92;
      }
    }

    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 80,
      child: CustomPaint(
        painter: _GlyphMatrixPainter(
          heights: _heights,
          peaks: _peaks,
          columns: widget.columns,
          rows: widget.rows,
          dotColor: widget.dotColor,
          dotOffColor: widget.dotOffColor,
          peakColor: AppColors.rose,
        ),
      ),
    );
  }
}

class _GlyphMatrixPainter extends CustomPainter {
  final List<double> heights;
  final List<double> peaks;
  final int columns;
  final int rows;
  final Color dotColor;
  final Color dotOffColor;
  final Color peakColor;

  const _GlyphMatrixPainter({
    required this.heights,
    required this.peaks,
    required this.columns,
    required this.rows,
    required this.dotColor,
    required this.dotOffColor,
    required this.peakColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double hGap = 3.0;
    const double vGap = 2.0;
    final double blockW = (size.width - (columns - 1) * hGap) / columns;
    final double blockH = (size.height - (rows - 1) * vGap) / rows;
    final paint = Paint();

    for (int c = 0; c < columns; c++) {
      final int heightInt = heights[c].floor();
      final int peakRow = peaks[c].floor();
      final bool hasPeak = peaks[c] > 0.5;

      for (int r = 0; r < rows; r++) {
        final double x = c * (blockW + hGap);
        final double y = size.height - r * (blockH + vGap) - blockH;

        final bool isLit = r < heightInt;
        final bool isPeak = hasPeak && r == peakRow;

        paint.color = isPeak ? peakColor : isLit ? dotColor : dotOffColor;

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, blockW, blockH),
            const Radius.circular(1),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_GlyphMatrixPainter old) => true;
}
