import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../controllers/main_controller.dart';
import '../methods/snackbar.dart';
import '../models/song_model.dart';
import '../screens/artist_profile/artist_profile.dart';
import '../screens/playlist/online_playlist_screen.dart';
import 'loading.dart';

import 'botttom_sheet_widget.dart';

class RecentSearch extends StatelessWidget {
  final MainController con;

  const RecentSearch({
    Key? key,
    required this.con,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        if (Hive.box('Recentsearch').length != 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Text(
              'Recent Searches'.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),
        ValueListenableBuilder<Box>(
            valueListenable: Hive.box('Recentsearch').listenable(),
            builder: (context, box, child) {
              if (box.isEmpty) {
                return const SizedBox(
                  height: 300,
                  child: Center(
                    child: Text(
                      "Keep Searching..",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              }
              final searchItems = box.values.toList();
              final songDataList = searchItems
                  .where((item) => item is Map && item['type'] == 'SONG')
                  .toList();

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, i) {
                  final info = box.getAt(i) as Map? ?? {};
                  final songName = info['songname']?.toString() ?? 'Unknown';
                  final fullName = info['fullname']?.toString() ?? '';
                  final cover = (info['cover'] != null && info['cover'].toString().isNotEmpty)
                      ? info['cover'].toString()
                      : 'https://images.unsplash.com/photo-1611339555312-e607c8352fd7?ixlib=rb-1.2.1&auto=format&fit=crop&w=774&q=80';
                  final type = info['type']?.toString() ?? 'SONG';

                  return Dismissible(
                    key: Key('${songName}_$i'),
                    onDismissed: (direction) {
                      box.deleteAt(i);
                      if (context.mounted) {
                        context.showSnackBar(
                            message: "Removed from Recent Searchlist.");
                      }
                    },
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      child: const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Icon(
                          CupertinoIcons.delete,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    child: ListTile(
                      onTap: () {
                        FocusScope.of(context).unfocus();
                        final upperType = type.toUpperCase();
                        if (upperType == 'PLAYLIST' || upperType == 'ALBUM') {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (context) => OnlinePlaylistScreen(
                                con: con,
                                id: info['id']?.toString() ?? '',
                                type: type.toLowerCase(),
                                title: songName,
                                coverImage: cover,
                                provider: info['username']?.toString(),
                              ),
                            ),
                          );
                        } else if (upperType == 'ARTIST') {
                          Navigator.push(
                              context,
                              CupertinoPageRoute(
                                  builder: (context) => ArtistProfile(
                                        username: fullName,
                                        con: con,
                                      )));
                        } else {
                          final songIndex = songDataList.indexOf(info);
                          final validIndex = songIndex >= 0 ? songIndex : 0;
                          con.playSong(con.converLocalSongToAudio(songDataList), validIndex);
                        }
                      },
                      leading: ClipRRect(
                        borderRadius: type == 'SONG'
                            ? BorderRadius.circular(5)
                            : BorderRadius.circular(50),
                        child: CachedNetworkImage(
                            imageUrl: cover,
                            width: 50,
                            height: 50,
                            memCacheHeight:
                                (50 * MediaQuery.of(context).devicePixelRatio)
                                    .round(),
                            memCacheWidth:
                                (50 * MediaQuery.of(context).devicePixelRatio)
                                    .round(),
                            placeholder: (context, u) => const LoadingImage(),
                            fit: BoxFit.cover),
                      ),
                      title: Text(
                        songName,
                        maxLines: 1,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        fullName,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      trailing: type == 'SONG'
                          ? IconButton(
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
                                          song: SongModel(
                                            songid: info['id']?.toString() ?? '',
                                            songname: songName,
                                            userid: info['username']?.toString() ?? '',
                                            trackid: info['track']?.toString() ?? '',
                                            duration: '',
                                            coverImageUrl: cover,
                                            name: fullName,
                                          ));
                                    });
                              },
                              icon: const Icon(
                                Icons.more_vert,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.play_circle_outline,
                              color: Colors.transparent,
                            ),
                    ),
                  );
                },
                itemCount: box.length,
              );
            }),
      ],
    );
  }
}
