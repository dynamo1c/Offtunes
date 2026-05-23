import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../models/track.dart';

/// Singleton audio playback service using just_audio with background support.
class AudioService {
  AudioService._internal() {
    _init();
    
    // Listen for index changes from the player (important for background skip)
    _player.currentIndexStream.listen((index) {
      if (index != null) {
        _currentIndex = index;
      }
    });
  }

  static final AudioService instance = AudioService._internal();

  final AudioPlayer _player = AudioPlayer();
  List<Track> _queue = [];
  int _currentIndex = 0;

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    
    // Handle interruptions (phone calls, etc.)
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        switch (event.type) {
          case AudioInterruptionType.duck:
            _player.setVolume(0.5);
            break;
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            _player.pause();
            break;
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.duck:
            _player.setVolume(1.0);
            break;
          case AudioInterruptionType.pause:
            _player.play();
            break;
          case AudioInterruptionType.unknown:
            break;
        }
      }
    });

    // Handle unplugging headphones
    session.becomingNoisyEventStream.listen((_) {
      _player.pause();
    });
  }

  // ── Playback Controls ──────────────────────────────────────────────────────

  /// Plays a specific track, optionally setting the queue.
  Future<void> playTrack(Track track, {List<Track>? queue, int index = 0}) async {
    if (queue != null) {
      _queue = List.from(queue);
      _currentIndex = index;
    } else {
      // If not already in queue, add it
      final existing = _queue.indexWhere((t) => t.id == track.id);
      if (existing >= 0) {
        _currentIndex = existing;
      } else {
        _queue.insert(0, track);
        _currentIndex = 0;
      }
    }
    await _setupQueueAndPlay(initialIndex: _currentIndex);
  }

  /// Plays all tracks starting from index 0.
  Future<void> playAll(List<Track> tracks) async {
    _queue = List.from(tracks);
    _currentIndex = 0;
    await _setupQueueAndPlay(initialIndex: 0);
  }

  /// Shuffles the list, then plays from index 0.
  Future<void> shuffle(List<Track> tracks) async {
    final shuffled = List<Track>.from(tracks)..shuffle();
    await playAll(shuffled);
  }

  Future<void> pause() async => _player.pause();
  Future<void> resume() async => _player.play();

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> next() async {
    if (_player.hasNext) {
      await _player.seekToNext();
      if (!_player.playing) await _player.play();
    }
  }

  Future<void> previous() async {
    if (_player.hasPrevious) {
      await _player.seekToPrevious();
      if (!_player.playing) await _player.play();
    }
  }

  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
  }

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume.clamp(0.0, 1.0));
  }

  /// Jumps to a specific index in the current queue.
  Future<void> jumpTo(int index) async {
    if (index >= 0 && index < _queue.length) {
      await _player.seek(Duration.zero, index: index);
      if (!_player.playing) await _player.play();
    }
  }

  /// Clears the playback queue and stops.
  Future<void> clearQueue() async {
    _queue = [];
    _currentIndex = 0;
    await _player.stop();
  }

  // ── Streams ────────────────────────────────────────────────────────────────

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<int?> get currentIndexStream => _player.currentIndexStream;

  // ── Getters ────────────────────────────────────────────────────────────────

  Track? get currentTrack => _queue.isEmpty ? null : _queue[_currentIndex];
  List<Track> get queue => _queue;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _player.playing;
  double get volume => _player.volume;

  // ── Internal ───────────────────────────────────────────────────────────────

  Future<void> _setupQueueAndPlay({int initialIndex = 0}) async {
    if (_queue.isEmpty) return;

    try {
      final audioSources = _queue.map((track) {
        Uri? artUri;
        if (track.coverArtUrl.isNotEmpty) {
          if (track.coverArtUrl.startsWith('http')) {
            artUri = Uri.parse(track.coverArtUrl);
          } else {
            artUri = Uri.file(track.coverArtUrl);
          }
        }

        return AudioSource.uri(
          Uri.file(track.filePath),
          tag: MediaItem(
            id: track.id,
            album: track.album,
            title: track.title,
            artist: track.artistString,
            artUri: artUri,
            duration: Duration(milliseconds: track.durationMs),
          ),
        );
      }).toList();

      final playlist = ConcatenatingAudioSource(children: audioSources);
      
      await _player.setAudioSource(playlist, initialIndex: initialIndex);
      await _player.play();
    } catch (e) {
      debugPrint('[AudioService] ERROR setting up playlist: $e');
    }
  }
}
