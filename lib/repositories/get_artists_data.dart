import '../api/client.dart';
import '../api/sunoh_api.dart';
import '../models/song_model.dart';
import '../models/user_model.dart';

class GetArtistsData {
  final _api = SunohApi(buildSunohDio());

  Future<UserModel> getUserData(String id) async {
    try {
      final artist = await _api.fetchArtist(id);
      return UserModel(
        id: artist.id,
        username: artist.id,
        name: artist.name,
        avatar: artist.artwork,
      );
    } catch (e) {
      print('[GetArtistsData] getUserData error: $e');
      return UserModel(id: id, name: 'Artist');
    }
  }

  Future<List<SongModel>> getSongs(String id) async {
    try {
      final artist = await _api.fetchArtist(id);
      return artist.topSongs
          .map(
            (s) => SongModel(
              songid: s.id,
              songname: s.title,
              userid: s.source ?? artist.source,
              trackid: s.mediaUrls.isNotEmpty
                  ? s.mediaUrls.last.link
                  : s.id,
              duration: s.duration,
              coverImageUrl: s.artwork ?? artist.artwork,
              name: s.displaySubtitle ?? artist.name,
            ),
          )
          .toList();
    } catch (e) {
      print('[GetArtistsData] getSongs error: $e');
      return [];
    }
  }
}
