import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'core/constants.dart';
import 'providers/library_provider.dart';
import 'screens/main_screen.dart';

import 'services/feedback_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
    androidNotificationIcon: 'mipmap/ic_launcher',
    // Set notification color to pastel pink
    notificationColor: const Color(0xFFF4B8CC), 
  );

  await FeedbackService.instance.init();
  runApp(const ProviderScope(child: OddtunesApp()));
}

class OddtunesApp extends ConsumerStatefulWidget {
  const OddtunesApp({super.key});

  @override
  ConsumerState<OddtunesApp> createState() => _OddtunesAppState();
}

class _OddtunesAppState extends ConsumerState<OddtunesApp> {
  @override
  void initState() {
    super.initState();
    // Request permissions and scan library on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initApp();
    });
  }

  Future<void> _initApp() async {
    try {
      bool hasPermission = true; // default true for non-Android platforms

      if (Platform.isAndroid) {
        hasPermission = await _requestPermissions();
      }

      if (hasPermission) {
        await ref.read(libraryProvider).refresh();
      } else {
        debugPrint('InitApp: Skipping library scan — no storage permission');
      }
    } catch (e) {
      debugPrint('InitApp: Error during initialization: $e');
    }
  }

  /// Requests storage permissions on Android and returns whether
  /// we have enough access to scan the music library.
  Future<bool> _requestPermissions() async {
    // On Android 11+, we need MANAGE_EXTERNAL_STORAGE to write directly to /Music/
    // using the File API without SAF.
    final manageStatus = await Permission.manageExternalStorage.request();
    if (manageStatus.isGranted) return true;

    // Android 10 and below: Use legacy storage permission (WRITE_EXTERNAL_STORAGE)
    final storageStatus = await Permission.storage.request();
    if (storageStatus.isGranted) return true;

    // Android 13+ granular media permission (Note: this only grants READ access, 
    // but is a last resort fallback so the app doesn't completely crash)
    final audioStatus = await Permission.audio.request();
    if (audioStatus.isGranted) return true;

    debugPrint('InitApp: All permission requests denied or unavailable');
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offtunes',
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.bg,
        textTheme: GoogleFonts.dmSansTextTheme(),
        colorScheme: const ColorScheme.light(
          primary: AppColors.rose,
          surface: AppColors.surface,
          error: AppColors.error,
        ),
      ),
      home: const MainScreen(),
    );
  }
}
