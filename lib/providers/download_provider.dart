import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../core/paths.dart';

import '../models/download_state.dart';
import '../models/track.dart';
import '../services/library_service.dart';
import '../services/metadata_service.dart';
import '../services/ytmusic_service.dart';
import '../services/feedback_service.dart';
import '../services/downloader_service.dart';
import '../services/ffmpeg_service.dart';
import 'library_provider.dart';

final downloadProvider = ChangeNotifierProvider<DownloadProvider>((ref) {
  return DownloadProvider(
    metadataService: MetadataService(),
    ytMusicService: YtMusicService(),
    downloaderService: DownloaderService(),
    ffmpegService: FfmpegService(),
    onTrackComplete: () async {
      final library = ref.read(libraryProvider);
      // Refresh library after each track finishes
      await library.refresh();
    },
    onBatchComplete: (completedTracks) async {
      final library = ref.read(libraryProvider);
      if (completedTracks.isNotEmpty) {
        // Count existing playlists before adding the new one
        final count = await LibraryService().playlistCount();
        await LibraryService()
            .savePlaylist('Playlist ${count + 1}', completedTracks);
        // Refresh again so the playlist shows up immediately
        await library.refresh();
      }
    },
  );
});


class DownloadProvider extends ChangeNotifier {
  final MetadataService _metadataService;
  final YtMusicService _ytMusicService;
  final DownloaderService _downloaderService;
  final FfmpegService _ffmpegService;
  final Future<void> Function()? _onTrackComplete;
  final Future<void> Function(List<Track> completedTracks)? _onBatchComplete;

  DownloadProvider({
    required MetadataService metadataService,
    required YtMusicService ytMusicService,
    required DownloaderService downloaderService,
    required FfmpegService ffmpegService,
    Future<void> Function()? onTrackComplete,
    Future<void> Function(List<Track> completedTracks)? onBatchComplete,
  })  : _metadataService = metadataService,
        _ytMusicService = ytMusicService,
        _downloaderService = downloaderService,
        _ffmpegService = ffmpegService,
        _onTrackComplete = onTrackComplete,
        _onBatchComplete = onBatchComplete;

  final List<TrackDownloadState> _queue = [];
  int _activeDownloads = 0;
  int _maxParallel = 7;

  int get maxParallel => _maxParallel;
  set maxParallel(int value) {
    _maxParallel = value;
    notifyListeners();
    // Kick the queue in case we just increased the limit
    _processQueue();
  }

  // Batch tracking for playlist auto-save
  bool _batchSaved = true; // starts true so pre-batch checks are no-ops

  // ── Fetch-only state ─────────────────────────────────────────────────────

  /// Tracks fetched from metadata but NOT yet queued for download.
  List<Track> _fetchedTracks = [];
  List<Track> get fetchedTracks => _fetchedTracks;

  bool _isFetching = false;
  bool get isFetching => _isFetching;

  String? _fetchError;
  String? get fetchError => _fetchError;

  // ── Download control state ───────────────────────────────────────────────

  bool _isPaused = false;
  bool get isPaused => _isPaused;

  bool _isStopped = false;

  // ── Existing getters ─────────────────────────────────────────────────────

  List<TrackDownloadState> get queue => _queue;
  int get completedCount =>
      _queue.where((t) => t.status == DownloadStatus.done).length;
  int get failedCount =>
      _queue.where((t) => t.status == DownloadStatus.failed).length;
  bool get isRunning => _activeDownloads > 0;

  /// True when tracks have been fetched and are ready to download.
  bool get hasFetchedTracks => _fetchedTracks.isNotEmpty;

  /// True when downloading has been started (queue is populated).
  bool get hasQueuedTracks => _queue.isNotEmpty;

  // ── Step 1: Fetch metadata (does NOT start downloading) ──────────────────

  Future<void> fetchTracks(String url) async {
    _fetchError = null;
    _isFetching = true;
    _fetchedTracks = [];

    // Clear old queue so stopped/failed items from a previous
    // session don't get mixed with the new import.
    _queue.clear();
    _activeDownloads = 0;
    _isPaused = false;
    _isStopped = false;

    notifyListeners();

    try {
      final tracks = await _metadataService.fetchFromUrl(url);
      _fetchedTracks = tracks;
      if (tracks.isEmpty) {
        _fetchError = 'No tracks found at this URL.';
      }
    } catch (e) {
      _fetchError = e.toString();
      debugPrint("Failed to fetch tracks: $e");
    } finally {
      _isFetching = false;
      notifyListeners();
    }
  }

  /// Removes a track from the fetched list before downloading starts.
  void removeFetchedTrack(int index) {
    if (index >= 0 && index < _fetchedTracks.length) {
      _fetchedTracks.removeAt(index);
      notifyListeners();
    }
  }

  /// Clears the fetched tracks list (e.g. user wants to paste a new URL).
  void clearFetchedTracks() {
    _fetchedTracks = [];
    _fetchError = null;
    notifyListeners();
  }

  // ── Step 2: Start downloading the fetched tracks ─────────────────────────

  void startDownloading() {
    if (_fetchedTracks.isEmpty) return;

    _isPaused = false;
    _isStopped = false;
    _batchSaved = false; // new batch starting

    for (final track in _fetchedTracks) {
      _queue.add(TrackDownloadState(track: track));
    }
    _fetchedTracks = [];
    _processQueue();
    notifyListeners();
  }

  // ── Legacy: combined fetch + download (keep for backwards compat) ────────

  Future<void> startDownload(String url) async {
    try {
      final tracks = await _metadataService.fetchFromUrl(url);
      _isPaused = false;
      _isStopped = false;
      for (final track in tracks) {
        _queue.add(TrackDownloadState(track: track));
      }
      _processQueue();
      notifyListeners();
    } catch (e) {
      debugPrint("Failed to start download for URL: $e");
    }
  }

  // ── Download queue processing ────────────────────────────────────────────

  void _processQueue() {
    if (_isPaused || _isStopped) return;

    while (_activeDownloads < maxParallel) {
      final queuedTrack = _queue.cast<TrackDownloadState?>().firstWhere(
            (t) => t != null && t.status == DownloadStatus.queued,
            orElse: () => null,
          );

      if (queuedTrack == null) break;

      _activeDownloads++;
      _downloadTrack(queuedTrack);
    }

    // When nothing is actively downloading and every track is terminal,
    // fire the batch-complete callback so the playlist gets saved.
    if (_activeDownloads == 0 && _queue.isNotEmpty && !_batchSaved) {
      final allTerminal = _queue.every((t) =>
          t.status == DownloadStatus.done ||
          t.status == DownloadStatus.failed);
      if (allTerminal) {
        _batchSaved = true;
        final completedTracks = _queue
            .where((t) =>
                t.status == DownloadStatus.done && t.outputPath != null)
            .map((t) {
               // Assign the filePath directly so it can be saved in playlist
               t.track.filePath = t.outputPath!;
               return t.track;
            })
            .toList();
        debugPrint('[DownloadProvider] Batch complete. '
            '${completedTracks.length} succeeded, '
            '${_queue.where((t) => t.status == DownloadStatus.failed).length} failed.');
        if (completedTracks.isNotEmpty && _onBatchComplete != null) {
          // Run callback async and notify UI when done
          _onBatchComplete(completedTracks).then((_) {
            debugPrint('[DownloadProvider] Playlist saved & library refreshed.');
            notifyListeners();
          }).catchError((e) {
            debugPrint('[DownloadProvider] onBatchComplete error: $e');
          });
        }
      }
    }
  }

  String sanitizeFilename(String name) {
    var cleanName = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
    cleanName = cleanName.replaceAll(' ', '_');
    if (cleanName.length > 100) {
      cleanName = cleanName.substring(0, 100);
    }
    return cleanName;
  }

  Future<void> _downloadTrack(TrackDownloadState state) async {
    try {
      // Check stop flag before each major step
      if (_isStopped) {
        state.status = DownloadStatus.queued;
        notifyListeners();
        return;
      }

      // 1. Searching — skip if track already has a YouTube videoId
      state.status = DownloadStatus.searching;
      notifyListeners();

      String? youtubeId;
      final isYouTubeSource = state.track.id.length == 11 &&
          RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(state.track.id);

      if (isYouTubeSource) {
        youtubeId = state.track.id; // Already a YouTube videoId — skip search
      } else {
        youtubeId = await _ytMusicService.findYouTubeId(state.track);
      }

      if (_isStopped) {
        state.status = DownloadStatus.queued;
        notifyListeners();
        return;
      }

      if (youtubeId == null) {
        throw Exception("No YouTube match found");
      }
      state.youtubeId = youtubeId;

      // 2. Downloading
      state.status = DownloadStatus.downloading;
      notifyListeners();

      final tempDir = (await getTemporaryDirectory()).path;
      final finalOutputDir = await getOfftunesDir();

      final rawPath = await _downloaderService.downloadAudio(
        youtubeVideoId: youtubeId,
        outputDir: tempDir,
        filename: sanitizeFilename(state.track.title),
        onProgress: (p) {
          state.progress = p * 0.95; // 95% is download, 5% is tagging
          notifyListeners();
        },
      );

      if (_isStopped) {
        state.status = DownloadStatus.queued;
        notifyListeners();
        return;
      }

      if (rawPath == null) {
        throw Exception("Downloader failed to return path");
      }

      // 3. Tagging (stream-copy — near-instant)
      state.status = DownloadStatus.converting;
      notifyListeners();

      final finalPath = await _ffmpegService.processAudio(
        rawM4aPath: rawPath,
        track: state.track,
        outputDir: finalOutputDir.path,
      );

      state.progress = 1.0;

      // 4. Done
      state.status = DownloadStatus.done;
      FeedbackService.instance.success();
      state.outputPath = finalPath;
      notifyListeners();
      
      // Trigger library refresh
      if (_onTrackComplete != null) {
        _onTrackComplete().catchError((e) {
          debugPrint('[DownloadProvider] onTrackComplete error: $e');
        });
      }
    } catch (e) {
      state.status = DownloadStatus.failed;
      FeedbackService.instance.error();
      state.errorMessage = e.toString();
      notifyListeners();
    } finally {
      _activeDownloads--;
      _processQueue();
    }
  }

  // ── Pause / Resume / Stop controls ───────────────────────────────────────

  /// Pauses the download queue. In-progress downloads finish their current
  /// step, but no new tracks are pulled from the queue.
  void pauseDownloads() {
    _isPaused = true;
    // Mark all queued tracks as paused visually
    for (final state in _queue) {
      if (state.status == DownloadStatus.queued) {
        state.status = DownloadStatus.paused;
      }
    }
    notifyListeners();
  }

  /// Resumes the download queue after a pause.
  void resumeDownloads() {
    _isPaused = false;
    // Un-pause all paused tracks back to queued
    for (final state in _queue) {
      if (state.status == DownloadStatus.paused) {
        state.status = DownloadStatus.queued;
      }
    }
    _processQueue();
    notifyListeners();
  }

  /// Stops all downloads. In-progress downloads will finish their current
  /// step, but remaining queued tracks are marked failed.
  void stopDownloads() {
    _isStopped = true;
    _isPaused = false;
    for (final state in _queue) {
      if (state.status == DownloadStatus.queued ||
          state.status == DownloadStatus.paused) {
        state.status = DownloadStatus.failed;
        state.errorMessage = 'Stopped by user';
      }
    }
    notifyListeners();
  }

  // ── Existing helpers ─────────────────────────────────────────────────────

  void retryFailed() {
    _isStopped = false;
    _isPaused = false;
    bool hasFailed = false;
    for (final state in _queue) {
      if (state.status == DownloadStatus.failed) {
        state.status = DownloadStatus.queued;
        state.errorMessage = null;
        state.progress = 0.0;
        hasFailed = true;
      }
    }
    if (hasFailed) {
      _processQueue();
      notifyListeners();
    }
  }

  void clearCompleted() {
    _queue.removeWhere((t) => t.status == DownloadStatus.done);
    notifyListeners();
  }

  /// Clears everything — fetched tracks, queue, resets all state.
  void clearAll() {
    _fetchedTracks = [];
    _queue.clear();
    _activeDownloads = 0;
    _isPaused = false;
    _isStopped = false;
    _fetchError = null;
    _isFetching = false;
    notifyListeners();
  }
}
