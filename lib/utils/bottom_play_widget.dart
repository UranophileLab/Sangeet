import 'dart:ui';

import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../controllers/main_controller.dart';

import 'loading.dart';

class PlayWidget extends StatelessWidget {
  final MainController con;
  final void Function()? onTap;
  const PlayWidget({
    Key? key,
    required this.con,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final devicePexelRatio = MediaQuery.of(context).devicePixelRatio;

    return con.player.builderCurrent(builder: (context, playing) {
      if (playing.audio.assetAudioPath.isEmpty) {
        return const SizedBox.shrink();
      }
      final myAudio = con.find(con.audios, playing.audio.assetAudioPath);
      final cover = (myAudio.metas.image != null && myAudio.metas.image!.path.isNotEmpty)
          ? myAudio.metas.image!.path
          : 'https://images.unsplash.com/photo-1611339555312-e607c8352fd7?ixlib=rb-1.2.1&auto=format&fit=crop&w=774&q=80';
      final title = myAudio.metas.title ?? 'Unknown';
      final artist = myAudio.metas.artist ?? '';

      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.black12,
              width: 0.5,
            ),
            borderRadius: BorderRadius.circular(6.0),
            boxShadow: kElevationToShadow[9],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: cover,
                    memCacheHeight: (70 * devicePexelRatio).round(),
                    memCacheWidth: (70 * devicePexelRatio).round(),
                    maxHeightDiskCache: (70 * devicePexelRatio).round(),
                    maxWidthDiskCache: (70 * devicePexelRatio).round(),
                    progressIndicatorBuilder: (context, url, l) =>
                        const LoadingImage(),
                    fit: BoxFit.cover,
                  ),
                ),
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 4.0, horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: CachedNetworkImage(
                                  imageUrl: cover,
                                  width: 40,
                                  height: 40,
                                  memCacheHeight:
                                      (70 * devicePexelRatio).round(),
                                  memCacheWidth:
                                      (70 * devicePexelRatio).round(),
                                  maxHeightDiskCache:
                                      (70 * devicePexelRatio).round(),
                                  maxWidthDiskCache:
                                      (70 * devicePexelRatio).round(),
                                  progressIndicatorBuilder: (context, url, l) =>
                                      const LoadingImage(),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Flexible(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge!
                                            .copyWith(
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge!
                                            .copyWith(
                                              color: Colors.grey,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        PlayerBuilder.isPlaying(
                            player: con.player,
                            builder: (context, isPlaying) {
                              return IconButton(
                                padding: const EdgeInsets.all(0),
                                onPressed: () {
                                  con.player.playOrPause();
                                },
                                icon: Icon(
                                  isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Colors.white,
                                  size: 36,
                                ),
                              );
                            })
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
