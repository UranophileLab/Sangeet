import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import '../../controllers/main_controller.dart';
import '../../methods/snackbar.dart';
import '../../models/song_model.dart';
import '../../utils/botttom_sheet_widget.dart';
import '../../utils/loading.dart';

class PlaylistSongs extends StatelessWidget {
  final MainController con;
  final String name;
  final String coverImage;
  const PlaylistSongs({
    Key? key,
    required this.con,
    required this.name,
    required this.coverImage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final devicePexelRatio = MediaQuery.of(context).devicePixelRatio;
    return Scaffold(
        body: FutureBuilder<Box<dynamic>>(
            future: Hive.openBox(name),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      pinned: true,
                      expandedHeight: 200,
                      backgroundColor: Colors.black,
                      flexibleSpace: FlexibleSpaceBar(
                        centerTitle: true,
                        collapseMode: CollapseMode.pin,
                        background: ClipRRect(
                          child: Stack(
                            children: [
                              CachedNetworkImage(
                                imageUrl: coverImage,
                                height: 200,
                                memCacheHeight: (200 *
                                        MediaQuery.of(context).devicePixelRatio)
                                    .round(),
                                memCacheWidth: (MediaQuery.of(context)
                                            .size
                                            .width *
                                        MediaQuery.of(context).devicePixelRatio)
                                    .round(),
                                width: MediaQuery.of(context).size.width,
                                fit: BoxFit.cover,
                              ),
                              BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.center,
                                      colors: [
                                        Colors.black,
                                        Colors.black.withValues(alpha: 0.5),
                                      ],
                                    ),
                                  ),
                                  height: 250,
                                  width: MediaQuery.of(context).size.width,
                                ),
                              )
                            ],
                          ),
                        ),
                        title: Text(
                          name,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: ValueListenableBuilder<Box>(
                        valueListenable: Hive.box(name).listenable(),
                        builder: (context, box, child) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: Text(
                              "${box.length} Songs",
                              style: const TextStyle(color: Colors.grey, fontSize: 14.0),
                            ),
                          );
                        },
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: ValueListenableBuilder<Box>(
                          valueListenable: Hive.box(name).listenable(),
                          builder: (context, box, child) {
                            if (box.isEmpty) {
                              return const SizedBox(
                                height: 300,
                                child: Center(
                                  child: Text(
                                    "You don't have any songs in this playlist.",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              );
                            }
                            final playlistList = box.values.toList();
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

                                return Dismissible(
                                  key: Key('${songName}_$i'),
                                  onDismissed: (direction) {
                                    box.deleteAt(i);
                                    if (context.mounted) {
                                      context.showSnackBar(
                                          message: "Removed from Playlist.");
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
                                      con.playSong(
                                          con.converLocalSongToAudio(playlistList), i);
                                    },
                                    leading: ClipRRect(
                                      borderRadius: BorderRadius.circular(5),
                                      child: CachedNetworkImage(
                                          imageUrl: cover,
                                          width: 50,
                                          height: 50,
                                          memCacheHeight:
                                              (70 * devicePexelRatio).round(),
                                          memCacheWidth:
                                              (70 * devicePexelRatio).round(),
                                          maxHeightDiskCache:
                                              (70 * devicePexelRatio).round(),
                                          maxWidthDiskCache:
                                              (70 * devicePexelRatio).round(),
                                          placeholder: (context, u) =>
                                              const LoadingImage(),
                                          fit: BoxFit.cover),
                                    ),
                                    title: Text(
                                      songName,
                                      maxLines: 1,
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                    subtitle: Text(
                                      fullName,
                                      style:
                                          const TextStyle(color: Colors.grey),
                                    ),
                                    trailing: IconButton(
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
                                    ),
                                  ),
                                );
                              },
                              itemCount: box.length,
                            );
                          }),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 150),
                    )
                  ],
                );
              } else {
                return const Center(child: CircularProgressIndicator());
              }
            }));
  }
}
