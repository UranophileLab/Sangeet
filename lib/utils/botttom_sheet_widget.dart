import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../controllers/main_controller.dart';
import '../methods/snackbar.dart';
import '../models/song_model.dart';
import '../screens/add_to_playlist/add_to_playlist.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'like_button/like_button.dart';
import 'loading.dart';

class BottomSheetWidget extends StatelessWidget {
  final MainController con;
  final bool? isNext;
  final SongModel song;
  const BottomSheetWidget({
    Key? key,
    required this.con,
    this.isNext,
    required this.song,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final devicePexelRatio = MediaQuery.of(context).devicePixelRatio;

    final cover = (song.coverImageUrl != null && song.coverImageUrl!.isNotEmpty)
        ? song.coverImageUrl!
        : 'https://images.unsplash.com/photo-1611339555312-e607c8352fd7?ixlib=rb-1.2.1&auto=format&fit=crop&w=774&q=80';
    final songName = song.songname ?? 'Unknown';
    final artistName = song.name ?? '';
    final songId = song.songid ?? '';
    final trackId = song.trackid ?? '';
    final userId = song.userid ?? '';

    return Container(
      color: Colors.black,
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * .05,
              ),
          SizedBox(
            width: MediaQuery.of(context).size.width * .4,
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: CachedNetworkImage(
                    imageUrl: cover,
                    memCacheHeight: (300 * devicePexelRatio).round(),
                    memCacheWidth: (300 * devicePexelRatio).round(),
                    maxHeightDiskCache: (300 * devicePexelRatio).round(),
                    maxWidthDiskCache: (300 * devicePexelRatio).round(),
                    progressIndicatorBuilder: (context, url, l) =>
                        const LoadingImage(),
                    fit: BoxFit.cover,
                  ),
                ),
                Container(
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                  ),
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 10,
                      ),
                      Icon(
                        Icons.music_note,
                        color: Colors.white,
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Text("Listen on Sangeet",
                          style: TextStyle(color: Colors.white)),
                    ],
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            songName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 5),
          Text(
            artistName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  color: Colors.grey,
                ),
          ),
          const SizedBox(height: 20),
          LikeButton(
            id: songId,
            isIcon: true,
            cover: cover,
            fullname: artistName,
            name: songName,
            track: trackId,
            username: userId,
          ),
          if (isNext == null)
            ListTile(
              onTap: () {
                final playlist = con.player.playlist;
                if (playlist != null) {
                  var title = con.player.getCurrentAudioTitle;
                  Audio currentSong = con.findByname(playlist.audios, title);
                  int currentIndex = playlist.audios.indexOf(currentSong);
                  final targetIndex = currentIndex >= 0 ? currentIndex + 1 : 0;
                  playlist.insert(targetIndex, con.convertToAudio([song])[0]);
                  context.showSnackBar(message: "Added to Queue");
                }
                Navigator.pop(context);
              },
              minLeadingWidth: 30,
              contentPadding: const EdgeInsets.symmetric(horizontal: 30),
              leading: const Icon(
                CupertinoIcons.play_arrow,
                color: Colors.grey,
              ),
              title: Text(
                "Play Next",
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium!
                    .copyWith(fontSize: 20, color: Colors.white),
              ),
            ),
          ListTile(
            onTap: () {
              final playlist = con.player.playlist;
              if (playlist != null) {
                playlist.add(con.convertToAudio([song])[0]);
                context.showSnackBar(message: "Added to Queue");
              }
              Navigator.pop(context);
            },
            minLeadingWidth: 30,
            contentPadding: const EdgeInsets.symmetric(horizontal: 30),
            leading: const Icon(
              Icons.playlist_add,
              color: Colors.grey,
            ),
            title: Text(
              "Add To queue",
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium!
                  .copyWith(fontSize: 20, color: Colors.white),
            ),
          ),
          ListTile(
            onTap: () {
              Navigator.push(context,
                  CupertinoPageRoute(builder: (BuildContext context) {
                return AddToPlaylist(
                  id: songId,
                  cover: cover,
                  fullname: artistName,
                  name: songName,
                  track: trackId,
                  username: userId,
                );
              }));
            },
            minLeadingWidth: 30,
            contentPadding: const EdgeInsets.symmetric(horizontal: 30),
            leading: const Icon(
              CupertinoIcons.music_albums,
              color: Colors.grey,
            ),
            title: Text(
              "Add to Playlist",
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium!
                  .copyWith(fontSize: 20, color: Colors.white),
            ),
          ),
          ListTile(
            onTap: () {
              if (trackId.isNotEmpty) {
                launchUrlString(trackId);
              }
            },
            minLeadingWidth: 30,
            contentPadding: const EdgeInsets.symmetric(horizontal: 30),
            leading: const Icon(
              Icons.download,
              color: Colors.grey,
            ),
            title: Text(
              "Download",
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium!
                  .copyWith(fontSize: 20, color: Colors.white),
            ),
          ),
          const SizedBox(
            height: 30,
          ),
        ],
      ),
    ),
    ),
    );
  }
}
