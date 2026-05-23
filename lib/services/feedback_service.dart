import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class FeedbackService {
  static final FeedbackService instance = FeedbackService._internal();
  FeedbackService._internal();
  
  final AudioPlayer _player = AudioPlayer();
  bool _soundEnabled = true;
  bool _hapticsEnabled = true;
  
  Future<void> init() async {
    // Configure audio context to mix with other audio and NOT request audio focus.
    // This prevents UI click sounds from pausing the music player!
    await AudioPlayer.global.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.assistanceSonification,
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
          options: const {},
        ),
      ),
    );

    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setVolume(0.4);
  }
  
  Future<void> clickPrimary() async {
    _haptic(HapticFeedback.mediumImpact);
    await _playSound('sounds/click_primary.wav');
  }
  
  Future<void> clickSoft() async {
    _haptic(HapticFeedback.lightImpact);
    await _playSound('sounds/click_soft.wav');
  }
  
  Future<void> navTap() async {
    _haptic(HapticFeedback.selectionClick);
    await _playSound('sounds/nav_tap.wav');
  }
  
  Future<void> success() async {
    _haptic(HapticFeedback.heavyImpact);
    await _playSound('sounds/success.wav');
  }
  
  Future<void> error() async {
    _haptic(HapticFeedback.vibrate);
    await _playSound('sounds/error.wav');
  }
  
  void _haptic(Future<void> Function() type) {
    if (_hapticsEnabled && Platform.isAndroid) {
      type();
    }
  }
  
  Future<void> _playSound(String asset) async {
    if (!_soundEnabled) return;
    try {
      await _player.play(AssetSource(asset));
    } catch (_) {}
  }
  
  void setSoundEnabled(bool v) => _soundEnabled = v;
  void setHapticsEnabled(bool v) => _hapticsEnabled = v;
  bool get soundEnabled => _soundEnabled;
  bool get hapticsEnabled => _hapticsEnabled;
}
