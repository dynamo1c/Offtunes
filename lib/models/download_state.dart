import 'track.dart';

enum DownloadStatus { queued, searching, downloading, converting, tagging, done, failed, paused }

class TrackDownloadState {
  final Track track;
  DownloadStatus status;
  double progress; // 0.0 to 1.0
  String? errorMessage;
  String? outputPath;
  String? youtubeId;

  TrackDownloadState({
    required this.track,
    this.status = DownloadStatus.queued,
    this.progress = 0.0,
    this.errorMessage,
    this.outputPath,
    this.youtubeId,
  });
}
