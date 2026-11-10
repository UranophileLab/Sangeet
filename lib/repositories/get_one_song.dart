import '../api/client.dart';
import '../api/sunoh_api.dart';
import '../models/song_model.dart';

class GetOneSong {
  final _api = SunohApi(buildSunohDio());

  Future<SongModel> getSongs(String name) async {
    try {
      final item = await _api.fetchSong(name);
      if (item != null) {
        return SongModel(
          songid: item.id,
          songname: item.title,
          userid: item.source,
          trackid: item.mediaUrls.isNotEmpty
              ? item.mediaUrls.last.link
              : item.id,
          duration: item.duration,
          coverImageUrl: item.artwork,
          name: item.displaySubtitle ?? item.subtitle ?? '',
        );
      }

      final sections = await _api.fetchSearch(name);
      for (final section in sections) {
        for (final s in section.items) {
          if (s.type == 'song') {
            return SongModel(
              songid: s.id,
              songname: s.title,
              userid: s.source,
              trackid: s.mediaUrls.isNotEmpty
                  ? s.mediaUrls.last.link
                  : s.id,
              duration: s.duration,
              coverImageUrl: s.artwork,
              name: s.displaySubtitle ?? s.subtitle ?? '',
            );
          }
        }
      }
      throw Exception('Song not found');
    } catch (e) {
      print('[GetOneSong] error: $e');
      return SongModel(
        songid: name,
        songname: name,
        trackid: name,
      );
    }
  }
}
