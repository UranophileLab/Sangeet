import '../api/client.dart';
import '../api/sunoh_api.dart';
import '../models/song_model.dart';
import '../models/user.dart';

class SearchRepository {
  final _api = SunohApi(buildSunohDio());

  Future<List<User>> getUsers(String tag) async {
    try {
      final sections = await _api.fetchSearch(tag);
      final List<User> users = [];

      for (final section in sections) {
        for (final item in section.items) {
          if (item.type == 'artist' || item.type == 'channel' || item.type == 'playlist') {
            users.add(
              User(
                avatar: item.artwork,
                username: item.id,
                name: item.title,
              ),
            );
          }
        }
      }

      if (users.isEmpty) {
        final recos = await _api.fetchRecommendations(query: tag);
        for (final item in recos) {
          users.add(
            User(
              avatar: item.artwork,
              username: item.id,
              name: item.displaySubtitle ?? item.title,
            ),
          );
        }
      }

      return users;
    } catch (e) {
      print('[SearchRepository] getUsers error: $e');
      return [];
    }
  }

  Future<List<SongModel>> getSongs(String tag) async {
    try {
      final sections = await _api.fetchSearch(tag);
      final List<SongModel> songs = [];

      for (final section in sections) {
        for (final item in section.items) {
          if (item.type == 'song' || item.type == 'album' || item.type == 'playlist') {
            songs.add(
              SongModel(
                songid: item.id,
                songname: item.title,
                userid: item.source,
                trackid: item.mediaUrls.isNotEmpty
                    ? item.mediaUrls.last.link
                    : item.id,
                duration: item.duration,
                coverImageUrl: item.artwork,
                name: item.displaySubtitle ?? item.subtitle ?? '',
                type: item.type,
              ),
            );
          }
        }
      }

      if (songs.isEmpty) {
        final recos = await _api.fetchRecommendations(query: tag);
        for (final item in recos) {
          songs.add(
            SongModel(
              songid: item.id,
              songname: item.title,
              userid: item.source,
              trackid: item.mediaUrls.isNotEmpty
                  ? item.mediaUrls.last.link
                  : item.id,
              duration: item.duration,
              coverImageUrl: item.artwork,
              name: item.displaySubtitle ?? item.subtitle ?? '',
              type: item.type,
            ),
          );
        }
      }

      return songs;
    } catch (e) {
      print('[SearchRepository] getSongs error: $e');
      return [];
    }
  }
}
