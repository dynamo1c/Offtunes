import '../models/track.dart';
import 'spotify_service.dart';
import 'gaana_service.dart';
import 'ytmusic_metadata_service.dart';


class MetadataService {
  Future<List<Track>> fetchFromUrl(String url) {
    if (url.contains("spotify.com")) {
      return SpotifyService().fetchFromUrl(url);
    } else if (url.contains("gaana.com")) {
      return GaanaService().fetchFromUrl(url);
    } else if (url.contains("music.youtube.com") ||
               url.contains("youtube.com/playlist")) {
      return YtMusicMetadataService().fetchFromUrl(url);
    } else {
      throw Exception("Unsupported music provider. Paste a Spotify, Gaana, or YouTube Music link.");
    }
  }
}
