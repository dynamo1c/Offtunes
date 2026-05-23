import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

void main() async {
  final dir = Directory('assets/sounds');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }

  await _generateWav('assets/sounds/click_primary.wav', _generateClickPrimary());
  await _generateWav('assets/sounds/click_soft.wav', _generateClickSoft());
  await _generateWav('assets/sounds/nav_tap.wav', _generateNavTap());
  await _generateWav('assets/sounds/success.wav', _generateSuccess());
  await _generateWav('assets/sounds/error.wav', _generateError());
  stdout.writeln('All sounds generated successfully.');
}

Future<void> _generateWav(String path, List<int> pcmData) async {
  final file = File(path);
  final byteData = ByteData(44 + pcmData.length * 2);

  // RIFF header
  byteData.setUint8(0, 'R'.codeUnitAt(0));
  byteData.setUint8(1, 'I'.codeUnitAt(0));
  byteData.setUint8(2, 'F'.codeUnitAt(0));
  byteData.setUint8(3, 'F'.codeUnitAt(0));
  byteData.setUint32(4, 36 + pcmData.length * 2, Endian.little);
  byteData.setUint8(8, 'W'.codeUnitAt(0));
  byteData.setUint8(9, 'A'.codeUnitAt(0));
  byteData.setUint8(10, 'V'.codeUnitAt(0));
  byteData.setUint8(11, 'E'.codeUnitAt(0));

  // fmt chunk
  byteData.setUint8(12, 'f'.codeUnitAt(0));
  byteData.setUint8(13, 'm'.codeUnitAt(0));
  byteData.setUint8(14, 't'.codeUnitAt(0));
  byteData.setUint8(15, ' '.codeUnitAt(0));
  byteData.setUint32(16, 16, Endian.little); // chunk size
  byteData.setUint16(20, 1, Endian.little); // PCM
  byteData.setUint16(22, 1, Endian.little); // mono
  byteData.setUint32(24, 44100, Endian.little); // sample rate
  byteData.setUint32(28, 44100 * 2, Endian.little); // byte rate
  byteData.setUint16(32, 2, Endian.little); // block align
  byteData.setUint16(34, 16, Endian.little); // bits per sample

  // data chunk
  byteData.setUint8(36, 'd'.codeUnitAt(0));
  byteData.setUint8(37, 'a'.codeUnitAt(0));
  byteData.setUint8(38, 't'.codeUnitAt(0));
  byteData.setUint8(39, 'a'.codeUnitAt(0));
  byteData.setUint32(40, pcmData.length * 2, Endian.little);

  // PCM data
  for (int i = 0; i < pcmData.length; i++) {
    byteData.setInt16(44 + i * 2, pcmData[i], Endian.little);
  }

  await file.writeAsBytes(byteData.buffer.asUint8List());
}

List<int> _generateClickPrimary() {
  // 15ms retro click (Square wave + noise)
  final samples = (44100 * 0.015).round();
  final data = <int>[];
  final rand = Random();
  for (int i = 0; i < samples; i++) {
    final t = i / 44100;
    final env = exp(-t * 300); // very fast decay
    final sqr = (sin(2 * pi * 800 * t) > 0 ? 1.0 : -1.0);
    final noise = (rand.nextDouble() * 2 - 1.0);
    final val = ((sqr * 0.6 + noise * 0.4) * env * 32767 * 0.25).round();
    data.add(val);
  }
  return data;
}

List<int> _generateClickSoft() {
  // 10ms soft tick, mostly filtered noise
  final samples = (44100 * 0.010).round();
  final data = <int>[];
  final rand = Random();
  for (int i = 0; i < samples; i++) {
    final t = i / 44100;
    final env = exp(-t * 500); 
    final noise = (rand.nextDouble() * 2 - 1.0);
    final val = (noise * env * 32767 * 0.15).round();
    data.add(val);
  }
  return data;
}

List<int> _generateNavTap() {
  // 20ms square wave blip
  final samples = (44100 * 0.020).round();
  final data = <int>[];
  for (int i = 0; i < samples; i++) {
    final t = i / 44100;
    final env = exp(-t * 200);
    final sqr = (sin(2 * pi * 1200 * t) > 0 ? 1.0 : -1.0);
    final val = (sqr * env * 32767 * 0.15).round();
    data.add(val);
  }
  return data;
}

List<int> _generateSuccess() {
  // 8-bit coin/success sound (two rapid square notes)
  final samples1 = (44100 * 0.060).round();
  final samples2 = (44100 * 0.120).round();
  final data = <int>[];
  
  for (int i = 0; i < samples1; i++) {
    final t = i / 44100;
    final env = 1.0; 
    final sqr = (sin(2 * pi * 987.77 * t) > 0 ? 1.0 : -1.0); // B5
    final val = (sqr * env * 32767 * 0.15).round();
    data.add(val);
  }
  for (int i = 0; i < samples2; i++) {
    final t = i / 44100;
    final env = exp(-t * 30);
    final sqr = (sin(2 * pi * 1318.51 * t) > 0 ? 1.0 : -1.0); // E6
    final val = (sqr * env * 32767 * 0.15).round();
    data.add(val);
  }
  return data;
}

List<int> _generateError() {
  // 8-bit error sound (low buzzy square wave)
  final samples = (44100 * 0.150).round();
  final data = <int>[];
  for (int i = 0; i < samples; i++) {
    final t = i / 44100;
    final env = exp(-t * 20);
    final sqr = (sin(2 * pi * 150 * t) > 0 ? 1.0 : -1.0);
    final val = (sqr * env * 32767 * 0.15).round();
    data.add(val);
  }
  return data;
}
