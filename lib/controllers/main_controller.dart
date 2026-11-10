import 'dart:async';

import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../api/client.dart';
import '../api/dto.dart';
import '../api/sunoh_api.dart';
import '../models/song_model.dart';

class MainController extends ChangeNotifier {
  final _api = SunohApi(buildSunohDio());

  var audios = <Audio>[
    Audio.network(
      'https://cdn.pixabay.com/download/audio/2022/01/20/audio_f1b4f4c8b1.mp3?filename=welcome-to-the-games-15238.mp3',
      metas: Metas(
        id: 'Online',
        title: 'Welcome Here',
        artist: 'Ankan Raj',
        album: 'OnlineAlbum',
        image: const MetasImage.network(
            'https://images.unsplash.com/photo-1611339555312-e607c8352fd7?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=774&q=80'),
      ),
    ),
  ];
  bool isNext = true;
  AssetsAudioPlayer player = AssetsAudioPlayer.withId('Playing audio');

  final List<StreamSubscription> _subscriptions = [];

  bool _isMediaStreamUrl(String url) {
    if (!url.startsWith('http://') && !url.startsWith('https://')) return false;
    final lower = url.toLowerCase();
    if (lower.contains('jiosaavn.com') || lower.contains('gaana.com')) {
      return false;
    }
    return lower.contains('.mp3') ||
        lower.contains('.mp4') ||
        lower.contains('.m3u8') ||
        lower.contains('.m4a') ||
        lower.contains('.aac') ||
        lower.contains('cdn') ||
        lower.contains('akamaized') ||
        lower.contains('googlevideo');
  }

  Future<Audio> _resolveAudioStream(Audio audio, {bool forceRefresh = false}) async {
    if (!forceRefresh && _isMediaStreamUrl(audio.path)) {
      return audio;
    }
    try {
      final songId = (audio.metas.id != null && audio.metas.id!.isNotEmpty)
          ? audio.metas.id!
          : audio.path;
      final provider = audio.metas.album;

      // 1. Try as direct song first
      FeedItem? song;
      if (provider != null && provider.isNotEmpty) {
        song = await _api.fetchSong(songId, provider: provider);
      }
      song ??= await _api.fetchSong(songId, provider: 'gaana');
      song ??= await _api.fetchSong(songId, provider: 'saavn');
      song ??= await _api.fetchSong(songId);

      if (song != null && song.mediaUrls.isNotEmpty) {
        final streamUrl = song.mediaUrls.last.link;
        if (_isMediaStreamUrl(streamUrl)) {
          return Audio.network(
            streamUrl,
            metas: audio.metas,
          );
        }
      }

      // 2. Try as playlist
      try {
        final playlist = await _api.fetchPlaylist(songId, provider: provider);
        if (playlist.songs.isNotEmpty && playlist.songs.first.mediaUrls.isNotEmpty) {
          final s = playlist.songs.first;
          final streamUrl = s.mediaUrls.last.link;
          return Audio.network(
            streamUrl,
            metas: Metas(
              id: s.id,
              title: s.title,
              artist: s.displaySubtitle ?? audio.metas.artist,
              album: audio.metas.album,
              image: MetasImage.network(s.artwork ?? audio.metas.image?.path ?? ''),
            ),
          );
        }
      } catch (_) {}

      // 3. Try as album
      try {
        final album = await _api.fetchAlbum(songId, provider: provider);
        if (album.songs.isNotEmpty && album.songs.first.mediaUrls.isNotEmpty) {
          final s = album.songs.first;
          final streamUrl = s.mediaUrls.last.link;
          return Audio.network(
            streamUrl,
            metas: Metas(
              id: s.id,
              title: s.title,
              artist: s.displaySubtitle ?? audio.metas.artist,
              album: audio.metas.album,
              image: MetasImage.network(s.artwork ?? audio.metas.image?.path ?? ''),
            ),
          );
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('[MainController] error resolving audio stream: $e');
    }
    return audio;
  }

  List<dynamic> getRecentlyPlayed() {
    try {
      if (!Hive.isBoxOpen('RecentlyPlayed')) return [];
      List<dynamic> data = [];
      var box = Hive.box('RecentlyPlayed');
      for (var i = 0; i < box.length; i++) {
        final val = box.getAt(i);
        if (val != null) data.add(val);
      }
      return data;
    } catch (e) {
      debugPrint('[MainController] getRecentlyPlayed error: $e');
      return [];
    }
  }

  List<Audio> converLocalSongToAudio(songs) {
    if (songs == null) return [];
    return (songs as List).map((audio) {
      if (audio is! Map) {
        return Audio.network('');
      }
      final track = audio['track']?.toString() ?? '';
      final cover = (audio['cover'] != null && audio['cover'].toString().isNotEmpty)
          ? audio['cover'].toString()
          : 'https://images.unsplash.com/photo-1611339555312-e607c8352fd7?ixlib=rb-1.2.1&auto=format&fit=crop&w=774&q=80';
      return Audio.network(
        track,
        metas: Metas(
          id: audio['id']?.toString() ?? '',
          title: audio['songname']?.toString() ?? 'Unknown',
          artist: audio['fullname']?.toString() ?? '',
          album: audio['username']?.toString() ?? '',
          image: MetasImage.network(cover),
        ),
      );
    }).where((audio) => audio.path.isNotEmpty).toList();
  }

  void init() async {
    try {
      _subscriptions.add(player.playlistAudioFinished.listen((data) async {
        if (data.playlist.currentIndex < 0 ||
            data.playlist.currentIndex >= data.playlist.audios.length) {
          return;
        }
        final myAudio = data.playlist.audios[data.playlist.currentIndex];
        if (!Hive.isBoxOpen('RecentlyPlayed')) return;
        var box = Hive.box('RecentlyPlayed');
        final coverUrl = myAudio.metas.image?.path ??
            'https://images.unsplash.com/photo-1611339555312-e607c8352fd7?ixlib=rb-1.2.1&auto=format&fit=crop&w=774&q=80';
        await box.put(myAudio.metas.title ?? 'Unknown', {
          "songname": myAudio.metas.title ?? 'Unknown',
          "fullname": myAudio.metas.artist ?? '',
          "username": myAudio.metas.album ?? '',
          "cover": coverUrl,
          "track": myAudio.path,
          "id": myAudio.metas.id ?? '',
          "created": DateTime.now().toString(),
        });
      }));

      _subscriptions.add(player.audioSessionId.listen((sessionId) {}));
      AssetsAudioPlayer.addNotificationOpenAction((notification) {
        return false;
      });

      _subscriptions.add(player.current.listen((playing) async {
        if (playing == null) return;
        final index = playing.index;
        if (index >= 0 && index < audios.length) {
          final audio = audios[index];
          if (!_isMediaStreamUrl(audio.path)) {
            debugPrint('[MainController] current track at index $index is unresolved, resolving stream...');
            final resolved = await _resolveAudioStream(audio);
            if (_isMediaStreamUrl(resolved.path)) {
              audios[index] = resolved;
              await openPlayer(newlist: audios, initial: index);
              await player.play();
            }
          }
          _preloadNextTrack(index);
        }
      }));

      final recentSongs = getRecentlyPlayed();
      recentSongs.sort((a, b) {
        if (a is Map && b is Map) {
          final aCreated = a["created"]?.toString() ?? '';
          final bCreated = b["created"]?.toString() ?? '';
          return bCreated.compareTo(aCreated);
        }
        return 0;
      });

      List<Audio> initialPlaylist = [];
      if (recentSongs.isNotEmpty) {
        final converted = converLocalSongToAudio(recentSongs);
        if (converted.isNotEmpty) {
          initialPlaylist = converted;
        }
      }

      if (initialPlaylist.isNotEmpty) {
        audios = initialPlaylist;
      }

      try {
        await openPlayer(newlist: audios);
      } catch (e) {
        debugPrint('[MainController] error opening player: $e, using default audio');
        audios = [
          Audio.network(
            'https://cdn.pixabay.com/download/audio/2022/01/20/audio_f1b4f4c8b1.mp3?filename=welcome-to-the-games-15238.mp3',
            metas: Metas(
              id: 'Online',
              title: 'Welcome Here',
              artist: 'Ankan Raj',
              album: 'OnlineAlbum',
              image: const MetasImage.network(
                  'https://images.unsplash.com/photo-1611339555312-e607c8352fd7?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=774&q=80'),
            ),
          ),
        ];
        await openPlayer(newlist: audios);
      }
    } catch (e) {
      debugPrint('[MainController] init error: $e');
    }
  }

  Future<void> _preloadNextTrack(int currentIndex) async {
    if (audios.isEmpty) return;
    final nextIndex = currentIndex + 1;
    if (nextIndex >= 0 && nextIndex < audios.length) {
      final nextAudio = audios[nextIndex];
      if (!_isMediaStreamUrl(nextAudio.path)) {
        try {
          final resolved = await _resolveAudioStream(nextAudio);
          if (_isMediaStreamUrl(resolved.path)) {
            audios[nextIndex] = resolved;
          }
        } catch (e) {
          debugPrint('[MainController] error preloading next track: $e');
        }
      }
    }
  }

  void addToFavorite(
      {required String name,
      required String fullname,
      required String username,
      required String cover,
      required String track}) {
    if (!Hive.isBoxOpen('liked')) return;
    var box = Hive.box('liked');

    box.put(name, {
      "songname": name,
      "fullname": fullname,
      "username": username,
      "cover": cover,
      "track": track
    });
  }

  Future<void> openPlayer(
      {required List<Audio> newlist, int initial = 0}) async {
    await player.open(Playlist(audios: newlist, startIndex: initial),
        showNotification: true,
        autoStart: false,
        headPhoneStrategy: HeadPhoneStrategy.pauseOnUnplug,
        notificationSettings: const NotificationSettings(stopEnabled: false));

    notifyListeners();
  }

  void playSong(List<Audio> newPlaylist, int initial) async {
    if (newPlaylist.isEmpty) return;
    if (isNext) {
      isNext = false;
      try {
        await player.pause();

        final validIndex =
            (initial >= 0 && initial < newPlaylist.length) ? initial : 0;
        newPlaylist[validIndex] =
            await _resolveAudioStream(newPlaylist[validIndex]);

        if (!_isMediaStreamUrl(newPlaylist[validIndex].path)) {
          debugPrint('[MainController] Cannot play: stream URL could not be resolved for track ${newPlaylist[validIndex].metas.title}');
          return;
        }

        audios = newPlaylist;
        await openPlayer(newlist: newPlaylist, initial: validIndex);
        await player.play();
        _preloadNextTrack(validIndex);
      } catch (e) {
        debugPrint('[MainController] playSong error: $e');
      } finally {
        isNext = true;
      }
    }
  }

  Future<void> playNext() async {
    if (audios.isEmpty) return;
    final currentIndex = player.current.value?.index ?? 0;
    final nextIndex = (currentIndex + 1) % audios.length;
    await playSongAtIndex(nextIndex);
  }

  Future<void> playPrevious() async {
    if (audios.isEmpty) return;
    final currentIndex = player.current.value?.index ?? 0;
    final prevIndex = (currentIndex - 1 + audios.length) % audios.length;
    await playSongAtIndex(prevIndex);
  }

  Future<void> playSongAtIndex(int index) async {
    if (audios.isEmpty) return;
    final validIndex = (index >= 0 && index < audios.length) ? index : 0;
    try {
      await player.pause();

      if (!_isMediaStreamUrl(audios[validIndex].path)) {
        audios[validIndex] = await _resolveAudioStream(audios[validIndex]);
      }

      if (!_isMediaStreamUrl(audios[validIndex].path)) {
        debugPrint('[MainController] Cannot play: stream URL could not be resolved for track ${audios[validIndex].metas.title}');
        return;
      }

      await openPlayer(newlist: audios, initial: validIndex);
      await player.play();
      _preloadNextTrack(validIndex);
    } catch (e) {
      debugPrint('[MainController] playSongAtIndex error: $e');
      try {
        audios[validIndex] = await _resolveAudioStream(audios[validIndex], forceRefresh: true);
        if (!_isMediaStreamUrl(audios[validIndex].path)) return;
        await openPlayer(newlist: audios, initial: validIndex);
        await player.play();
      } catch (err) {
        debugPrint('[MainController] playSongAtIndex retry error: $err');
      }
    }
  }

  Future<void> seek(Duration position) async {
    try {
      final currentInfo = player.realtimePlayingInfos.value;
      final totalDuration = currentInfo.duration;

      Duration target = position;
      if (totalDuration > Duration.zero) {
        if (target >= totalDuration) {
          target = totalDuration - const Duration(milliseconds: 500);
        }
      }
      if (target < Duration.zero) {
        target = Duration.zero;
      }

      final wasPlaying = player.isPlaying.value;
      await player.seek(target);

      // Always explicitly resume playback if audio was playing prior to seeking
      if (wasPlaying) {
        await player.play();
      }

      // Check after a short delay if playback is stalled or paused unexpectedly
      await Future.delayed(const Duration(milliseconds: 400));
      if (wasPlaying && !player.isPlaying.value) {
        debugPrint('[MainController] Player did not resume after seek, retrying play...');
        await player.play();

        // If player is still not playing sound after retry, refresh the track stream
        await Future.delayed(const Duration(milliseconds: 300));
        if (wasPlaying && !player.isPlaying.value) {
          debugPrint('[MainController] Player still stalled after seek, refreshing track stream...');
          await refreshCurrentTrackAndSeek(target);
        }
      }
    } catch (e) {
      debugPrint('[MainController] seek error: $e, attempting stream refresh...');
      await refreshCurrentTrackAndSeek(position);
    }
  }

  Future<void> refreshCurrentTrackAndSeek(Duration targetPosition) async {
    try {
      final currentPlaying = player.current.value;
      if (currentPlaying == null) return;

      final currentAudio = currentPlaying.audio.audio;
      final freshAudio =
          await _resolveAudioStream(currentAudio, forceRefresh: true);

      final currentIndex = player.current.value?.index ?? 0;
      if (currentIndex >= 0 && currentIndex < audios.length) {
        audios[currentIndex] = freshAudio;
        await openPlayer(newlist: audios, initial: currentIndex);
        await player.seek(targetPosition);
        await player.play();
      }
    } catch (e) {
      debugPrint('[MainController] refreshCurrentTrackAndSeek error: $e');
    }
  }

  void changeIndex(int newIndex, int oldIndex) {
    if (player.playlist != null &&
        oldIndex >= 0 &&
        oldIndex < player.playlist!.audios.length &&
        newIndex >= 0 &&
        newIndex <= player.playlist!.audios.length) {
      player.playlist!.audios
          .insert(newIndex, player.playlist!.audios.removeAt(oldIndex));
      notifyListeners();
    }
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    player.dispose();
    super.dispose();
  }

  void close() {
    dispose();
  }

  Audio find(List<Audio> source, String fromPath) {
    final list = source.isNotEmpty ? source : audios;
    if (list.isEmpty) {
      return Audio.network('');
    }
    return list.firstWhere(
      (element) => element.path == fromPath,
      orElse: () => list.first,
    );
  }

  Audio findByname(List<Audio> source, String fromPath) {
    final list = source.isNotEmpty ? source : audios;
    if (list.isEmpty) {
      return Audio.network('');
    }
    return list.firstWhere(
      (element) => element.metas.title == fromPath,
      orElse: () => list.first,
    );
  }

  List<Audio> convertToAudio(List<SongModel> songs) {
    return [
      ...songs.map((audio) {
        final track = (audio.trackid != null && audio.trackid!.isNotEmpty)
            ? audio.trackid!
            : (audio.songid ?? '');
        final cover = (audio.coverImageUrl != null &&
                audio.coverImageUrl!.isNotEmpty)
            ? audio.coverImageUrl!
            : 'https://images.unsplash.com/photo-1611339555312-e607c8352fd7?ixlib=rb-1.2.1&auto=format&fit=crop&w=774&q=80';
        return Audio.network(
          track,
          metas: Metas(
            id: audio.songid ?? '',
            title: audio.songname ?? 'Unknown',
            artist: audio.name ?? '',
            album: audio.userid ?? '',
            image: MetasImage.network(cover),
          ),
        );
      }).toList()
    ];
  }
}
