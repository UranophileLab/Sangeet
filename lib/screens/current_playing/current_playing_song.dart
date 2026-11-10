import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:line_icons/line_icons.dart';
import 'package:sangeet/controllers/main_controller.dart';
import 'package:sangeet/models/song_model.dart';
import 'package:sangeet/utils/botttom_sheet_widget.dart';
import 'package:sangeet/utils/like_button/like_button.dart';
import 'package:sangeet/utils/loading.dart';
import 'package:sangeet/utils/play_list.dart';
import 'package:sangeet/utils/player/playing_controls.dart';
import 'package:sangeet/utils/player/position_seek_widget.dart';
import 'package:url_launcher/url_launcher_string.dart';

class CurrentPlayingSong extends StatelessWidget {
  final MainController con;
  const CurrentPlayingSong({
    Key? key,
    required this.con,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final devicePexelRatio = MediaQuery.of(context).devicePixelRatio;

    return Container(
        child: con.player.builderCurrent(builder: (context, playing) {
      final myAudio = con.find(con.audios, playing.audio.assetAudioPath);
      final title = myAudio.metas.title ?? 'Unknown';
      final artist = myAudio.metas.artist ?? '';
      final album = myAudio.metas.album ?? '';
      final id = myAudio.metas.id ?? '';
      final cover = (myAudio.metas.image != null && myAudio.metas.image!.path.isNotEmpty)
          ? myAudio.metas.image!.path
          : 'https://images.unsplash.com/photo-1611339555312-e607c8352fd7?ixlib=rb-1.2.1&auto=format&fit=crop&w=774&q=80';

        return Container(
          color: Colors.black,
          child: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Column(
                  children: [
                    const SizedBox(
                      height: 30,
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 16.0, horizontal: 12),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.arrow_back_ios,
                                color: Colors.white,
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: Column(
                                  children: [
                                    const Text(
                                      "NOW PLAYING",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 4,
                                    ),
                                    Text(
                                      artist,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                showModalBottomSheet(
                                    useRootNavigator: true,
                                    isScrollControlled: true,
                                    elevation: 100,
                                    backgroundColor: Colors.black38,
                                    context: context,
                                    builder: (context) {
                                      return BottomSheetWidget(
                                          con: con,
                                          isNext: true,
                                          song: SongModel(
                                            songid: id,
                                            songname: title,
                                            userid: album,
                                            trackid: myAudio.path,
                                            duration: '',
                                            coverImageUrl: cover,
                                            name: artist,
                                          ));
                                    });
                              },
                              icon: const Icon(
                                Icons.more_vert,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 26.0),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: CachedNetworkImage(
                        imageUrl: cover,
                        memCacheHeight: (200 * devicePexelRatio).round(),
                        memCacheWidth: (200 * devicePexelRatio).round(),
                        maxHeightDiskCache: (200 * devicePexelRatio).round(),
                        maxWidthDiskCache: (200 * devicePexelRatio).round(),
                        progressIndicatorBuilder: (context, url, l) =>
                            const LoadingImage(
                          icon: Icon(
                            LineIcons.compactDisc,
                            size: 120,
                          ),
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24.0),
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  style: Theme.of(context).textTheme.headlineMedium,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24.0),
                                child: Text(
                                  artist,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge!
                                      .copyWith(color: Colors.grey),
                                ),
                              ),
                            ],
                          ),
                        ),
                        LikeButton(
                          name: title,
                          fullname: artist,
                          username: album,
                          id: id,
                          track: myAudio.path,
                          isIcon: false,
                          cover: myAudio.metas.image!.path,
                        ),
                        const SizedBox(width: 24)
                      ],
                    ),
                    Column(children: <Widget>[
                      con.player.builderRealtimePlayingInfos(
                          builder: (context, RealtimePlayingInfos? infos) {
                        if (infos == null) {
                          return const SizedBox();
                        }
                        return PositionSeekWidget(
                          currentPosition: infos.currentPosition,
                          duration: infos.duration,
                          seekTo: (to) {
                            con.seek(to);
                          },
                        );
                      }),
                      con.player.builderLoopMode(
                        builder: (context, loopMode) {
                          return PlayerBuilder.isPlaying(
                              player: con.player,
                              builder: (context, isPlaying) {
                                return PlayingControls(
                                  loopMode: loopMode,
                                  isPlaying: isPlaying,
                                  con: con,
                                  isPlaylist: true,
                                  onStop: () {
                                    con.player.stop();
                                  },
                                  toggleLoop: () {
                                    con.player.toggleLoop();
                                  },
                                  onPlay: () {
                                    con.player.playOrPause();
                                  },
                                  onNext: () {
                                    con.playNext();
                                  },
                                  onPrevious: () {
                                    con.playPrevious();
                                  },
                                );
                              });
                        },
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 26.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            InkWell(
                              onTap: () {
                                launchUrlString(myAudio.path);
                              },
                              child: const Icon(
                                Icons.download_sharp,
                                color: Colors.grey,
                                size: 18,
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (context) => PlayListWidget(
                                      audios: con.player.playlist!.audios,
                                      con: con,
                                    ),
                                  ),
                                );
                              },
                              child: const Icon(
                                CupertinoIcons.music_note_list,
                                color: Colors.grey,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                    ]),
                  ],
                ),
                const SizedBox(height: 5),
              ],
            ),
          ),
        ),
      ),
    );
    }));
  }
}
