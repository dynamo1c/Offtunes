import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants.dart';
import '../core/paths.dart';
import '../providers/download_provider.dart';
import '../providers/library_provider.dart';
import '../widgets/hw_button.dart';
import '../widgets/panel.dart';
import '../services/feedback_service.dart';
import 'convert_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONFIGURATION',
            style: GoogleFonts.dmSans(
              fontSize: 10,
              letterSpacing: 2.5,
              color: AppColors.textSoft,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 120,
            ),
            children: [
              // Panel 1 — Audio Quality
              _buildStaticPanel('AUDIO FORMAT', 'M4A NATIVE'),

              // Panel 2 — Download Path
              _buildDownloadPathPanel(context),

              // Panel 3 — Concurrent DL
              _buildParallelDlPanel(ref),

              // Panel 4 — Library
              _buildLibraryPanel(context, ref, library),

              // Panel 5 — Click Sounds
              _buildClickSoundsPanel(),

              // Panel 6 — Haptics
              if (Platform.isAndroid) _buildHapticsPanel(),

              // Panel 7 — Convert to MP3
              _buildConvertPanel(context),
            ],
          ),
          const SizedBox(height: 24),

          // Version info
          Panel(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Column(
                children: [
                  Text('v1.0.0',
                      style: GoogleFonts.shareTechMono(
                          fontSize: 14, color: AppColors.text)),
                  const SizedBox(height: 4),
                  Text('SERIAL: OFT-0001',
                      style: GoogleFonts.shareTechMono(
                          fontSize: 11, color: AppColors.textSoft)),
                  const SizedBox(height: 12),
                  Text('OFFTUNES SYSTEMS',
                      style: GoogleFonts.dmSans(
                          fontSize: 10, color: AppColors.textSoft)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaticPanel(String title, String value) {
    return Panel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 10,
              letterSpacing: 2.5,
              color: AppColors.textSoft,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.shareTechMono(
                fontSize: 13, color: AppColors.rose),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildParallelDlPanel(WidgetRef ref) {
    final dlProvider = ref.watch(downloadProvider);
    final current = dlProvider.maxParallel;
    const options = [5, 7, 8, 10];

    return Panel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'PARALLEL DL',
            style: GoogleFonts.dmSans(
              fontSize: 10,
              letterSpacing: 2.5,
              color: AppColors.textSoft,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.pink, width: 1),
            ),
            child: DropdownButton<int>(
              value: options.contains(current) ? current : 7,
              dropdownColor: AppColors.surface,
              underline: const SizedBox.shrink(),
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down,
                  color: AppColors.rose, size: 18),
              style: GoogleFonts.shareTechMono(
                  fontSize: 13, color: AppColors.rose),
              items: options.map((val) {
                return DropdownMenuItem<int>(
                  value: val,
                  child: Text('$val STREAMS'),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  FeedbackService.instance.clickSoft();
                  ref.read(downloadProvider).maxParallel = val;
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadPathPanel(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'DOWNLOAD PATH',
            style: GoogleFonts.dmSans(
              fontSize: 10,
              letterSpacing: 2.5,
              color: AppColors.textSoft,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          FutureBuilder<String>(
            future: getOfftunsDirPath(),
            builder: (context, snap) {
              final path = snap.data ?? '...';
              // Shorten the path for display
              final short = path.length > 20
                  ? '...${path.substring(path.length - 20)}'
                  : path;
              return Text(
                short,
                style: GoogleFonts.shareTechMono(
                    fontSize: 10, color: AppColors.rose),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              );
            },
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 28,
            child: HwButton(
              text: 'OPEN',
              onTap: () async {
                final path = await getOfftunsDirPath();
                final uri = Uri.directory(path);
                try {
                  await launchUrl(uri);
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cannot open folder')),
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryPanel(
      BuildContext context, WidgetRef ref, LibraryProvider library) {
    return Panel(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'LIBRARY',
            style: GoogleFonts.dmSans(
              fontSize: 10,
              letterSpacing: 2.5,
              color: AppColors.textSoft,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            library.isLoading
                ? 'SCANNING...'
                : '${library.allTracks.length} TRACKS',
            style: GoogleFonts.shareTechMono(
                fontSize: 13, color: AppColors.rose),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 28,
            child: HwButton(
              text: 'RESCAN',
              onTap: () => ref.read(libraryProvider).refresh(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClickSoundsPanel() {
    return Panel(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'CLICK SOUNDS',
            style: GoogleFonts.dmSans(
              fontSize: 10,
              letterSpacing: 2.5,
              color: AppColors.textSoft,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Switch(
            value: FeedbackService.instance.soundEnabled,
            onChanged: (v) {
              setState(() => FeedbackService.instance.setSoundEnabled(v));
            },
            activeTrackColor: AppColors.rose,
            inactiveThumbColor: AppColors.textSoft,
            inactiveTrackColor: AppColors.pink,
          ),
        ],
      ),
    );
  }

  Widget _buildHapticsPanel() {
    return Panel(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'HAPTICS',
            style: GoogleFonts.dmSans(
              fontSize: 10,
              letterSpacing: 2.5,
              color: AppColors.textSoft,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Switch(
            value: FeedbackService.instance.hapticsEnabled,
            onChanged: (v) {
              setState(() => FeedbackService.instance.setHapticsEnabled(v));
            },
            activeTrackColor: AppColors.rose,
            inactiveThumbColor: AppColors.textSoft,
            inactiveTrackColor: AppColors.pink,
          ),
        ],
      ),
    );
  }

  Widget _buildConvertPanel(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'CONVERT TO MP3',
            style: GoogleFonts.dmSans(
              fontSize: 10,
              letterSpacing: 2.5,
              color: AppColors.textSoft,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '192kbps LAME',
            style: GoogleFonts.shareTechMono(
                fontSize: 10, color: AppColors.rose),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 28,
            child: HwButton(
              text: 'CONVERT',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ConvertScreen()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
