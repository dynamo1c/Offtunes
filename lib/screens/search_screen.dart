import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/constants.dart';
import '../core/search_index.dart';
import '../providers/library_provider.dart';
import '../services/audio_service.dart';
import '../services/feedback_service.dart';
import 'now_playing_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<SearchResult> _results = [];
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 80), () {
      final library = ref.read(libraryProvider);
      setState(() {
        _results = library.searchIndex.search(val);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Search field ──
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.pink, width: 1.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(PhosphorIconsRegular.magnifyingGlass,
                    size: 16, color: AppColors.textSoft),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    onChanged: _onQueryChanged,
                    style: GoogleFonts.shareTechMono(
                        fontSize: 14, color: AppColors.text),
                    decoration: InputDecoration(
                      hintText: 'QUERY LOCAL_',
                      hintStyle: GoogleFonts.shareTechMono(
                          color: AppColors.textSoft),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (query.isNotEmpty)
                  IconButton(
                    icon: const Icon(PhosphorIconsRegular.x,
                        size: 16, color: AppColors.textSoft),
                    splashRadius: 16,
                    onPressed: () {
                      _controller.clear();
                      setState(() => _results = []);
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Results or empty states ──
          Expanded(
            child: query.isEmpty
                ? Center(
                    child: Text(
                      '[ QUERY LOCAL_ ]',
                      style: GoogleFonts.shareTechMono(
                          fontSize: 20, color: AppColors.lcd),
                    ),
                  )
                : _results.isEmpty
                    ? Center(
                        child: Text(
                          '[ NO MATCH ]',
                          style: GoogleFonts.shareTechMono(
                              fontSize: 16, color: AppColors.textSoft),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (context, index) => const Divider(
                            height: 1,
                            thickness: 1,
                            color: AppColors.pink),
                        itemBuilder: (context, i) {
                          final result = _results[i];
                          final track = result.track;
                          final library = ref.read(libraryProvider);

                          return InkWell(
                            onTapDown: (_) => FeedbackService.instance.clickSoft(),
                            onTap: () {
                              final allTracks = library.allTracks;
                              final idx = allTracks.indexOf(track);
                              AudioService.instance.playTrack(
                                track,
                                queue: allTracks,
                                index: idx >= 0 ? idx : 0,
                              );
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => const NowPlayingScreen()));
                            },
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  // Cover art
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: SizedBox(
                                      width: 44,
                                      height: 44,
                                      child: _buildCover(track.coverArtUrl),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Title (highlighted) + artist
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildHighlightedTitle(
                                            track.title, query),
                                        const SizedBox(height: 2),
                                        Text(
                                          track.artistString,
                                          style: GoogleFonts.shareTechMono(
                                              fontSize: 11,
                                              color: AppColors.textSoft),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatDuration(track.durationMs),
                                    style: GoogleFonts.shareTechMono(
                                        fontSize: 11,
                                        color: AppColors.textSoft),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightedTitle(String title, String query) {
    if (query.isEmpty) {
      return Text(
        title,
        style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.text),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final lowerTitle = title.toLowerCase();
    final lowerQuery = query.toLowerCase().trim();
    final matchStart = lowerTitle.indexOf(lowerQuery);

    if (matchStart < 0) {
      return Text(
        title,
        style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.text),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final matchEnd = matchStart + lowerQuery.length;
    return Text.rich(
      TextSpan(
        children: [
          if (matchStart > 0)
            TextSpan(
              text: title.substring(0, matchStart),
              style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text),
            ),
          TextSpan(
            text: title.substring(matchStart, matchEnd),
            style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.rose),
          ),
          if (matchEnd < title.length)
            TextSpan(
              text: title.substring(matchEnd),
              style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildCover(String url) {
    if (url.isEmpty) {
      return Container(
          color: AppColors.surfaceRaised,
          child: const Center(
              child: Icon(PhosphorIconsRegular.musicNote,
                  size: 18, color: AppColors.textSoft)));
    }
    if (url.startsWith('/') || url.contains('\\')) {
      return Image.file(File(url),
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, stack) => Container(
              color: AppColors.surfaceRaised,
              child: const Icon(PhosphorIconsRegular.musicNote,
                  size: 18, color: AppColors.textSoft)));
    }
    return Image.network(url,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => Container(
            color: AppColors.surfaceRaised,
            child: const Icon(PhosphorIconsRegular.musicNote,
                size: 18, color: AppColors.textSoft)));
  }

  String _formatDuration(int ms) {
    final m = ms ~/ 60000;
    final s = (ms ~/ 1000) % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
