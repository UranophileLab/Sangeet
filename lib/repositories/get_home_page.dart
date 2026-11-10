import '../api/client.dart';
import '../api/dto.dart';
import '../api/sunoh_api.dart';
import '../models/song_model.dart';
import '../models/user.dart';

class HomeDataResult {
  final List<HomeSection> sections;
  final List<User> users;
  final List<SongModel> songs;

  HomeDataResult({
    required this.sections,
    required this.users,
    required this.songs,
  });
}

class GetHomePage {
  final _api = SunohApi(buildSunohDio());

  Future<HomeDataResult> fetchAllHomeData() async {
    try {
      final homeSections = await _api.fetchHome();
      final List<User> users = [];
      final List<SongModel> songs = [];

      for (final section in homeSections) {
        for (final item in section.items) {
          if (item.type == 'artist' || item.type == 'channel') {
            users.add(
              User(
                avatar: item.artwork,
                username: item.id,
                name: item.title,
              ),
            );
          } else if (item.type == 'song' ||
              item.type == 'album' ||
              item.type == 'playlist') {
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

      if (users.length < 20 || songs.length < 20) {
        try {
          final List<Future<dynamic>> requests = [];
          bool fetchedSearch = false;
          bool fetchedReco = false;

          if (users.length < 20) {
            requests.add(_api.fetchTrendingSearch().catchError((_) => <HomeSection>[]));
            fetchedSearch = true;
          }
          if (songs.length < 20) {
            requests.add(_api.fetchRecommendations(query: 'trending').catchError((_) => <FeedItem>[]));
            fetchedReco = true;
          }

          final results = await Future.wait(requests);
          int index = 0;

          if (fetchedSearch && index < results.length) {
            final searchSections = results[index] as List<HomeSection>;
            index++;
            for (final section in searchSections) {
              for (final item in section.items) {
                if (item.type == 'artist' ||
                    item.type == 'channel' ||
                    item.type == 'playlist') {
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
          }

          if (fetchedReco && index < results.length) {
            final recos = results[index] as List<FeedItem>;
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
        } catch (_) {}
      }

      final originalUsersLen = users.length;
      while (users.length < 20 && originalUsersLen > 0) {
        users.add(users[users.length % originalUsersLen]);
      }

      final originalSongsLen = songs.length;
      while (songs.length < 20 && originalSongsLen > 0) {
        songs.add(songs[songs.length % originalSongsLen]);
      }

      return HomeDataResult(
        sections: homeSections,
        users: users,
        songs: songs,
      );
    } catch (e) {
      print('[GetHomePage] fetchAllHomeData error: $e');
      return HomeDataResult(sections: [], users: [], songs: []);
    }
  }

  Future<List<HomeSection>> getHomeSections() async {
    try {
      final sections = await _api.fetchHome();
      return sections;
    } catch (e) {
      print('[GetHomePage] getHomeSections error: $e');
      return [];
    }
  }

  Future<List<User>> getUsers() async {
    final res = await fetchAllHomeData();
    return res.users;
  }

  Future<List<SongModel>> getSongs() async {
    final res = await fetchAllHomeData();
    return res.songs;
  }
}
