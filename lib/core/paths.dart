import 'dart:io';

/// Returns the Offtunes music directory path for the current platform.
/// On Windows: C:\Users\{user}\Music\Offtunes\
/// On Android: /storage/emulated/0/Music/Offtunes/
Future<Directory> getOfftunesDir() async {
  String basePath;

  if (Platform.isWindows) {
    final userProfile = Platform.environment['USERPROFILE'] ?? 'C:\\Users\\Default';
    basePath = '$userProfile\\Music\\Offtunes';
  } else if (Platform.isAndroid) {
    basePath = '/storage/emulated/0/Music/Offtunes';
  } else {
    // Fallback for other platforms
    basePath = '${Platform.environment['HOME'] ?? '.'}/Music/Offtunes';
  }

  final dir = Directory(basePath);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}

/// Returns the Offtunes directory path as a String.
Future<String> getOfftunsDirPath() async {
  final dir = await getOfftunesDir();
  return dir.path;
}
