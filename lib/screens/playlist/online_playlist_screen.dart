import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../api/client.dart';
import '../../api/dto.dart';
import '../../api/sunoh_api.dart';
import '../../controllers/main_controller.dart';
import '../../models/song_model.dart';
import '../../utils/botttom_sheet_widget.dart';
import '../../utils/loading.dart';

class OnlinePlaylistScreen extends StatefulWidget {
  final MainController con;
  final String id;
  final String? type;
  final String title;
  final String coverImage;
  final String? provider;

  const OnlinePlaylistScreen({
    Key? key,
    required this.con,
    required this.id,
    this.type,
    required this.title,
    required this.coverImage,
    this.provider,
  }) : super(key: key);

  @override
  State<OnlinePlaylistScreen> createState() => _OnlinePlaylistScreenState();
}

class _OnlinePlaylistScreenState extends State<OnlinePlaylistScreen> {
  final _api = SunohApi(buildSunohDio());
  bool _isLoading = true;
  String? _errorMessage;
  List<SongModel> _songs = [];
  String _displayTitle = '';
  String _displaySubtitle = '';
  String _displayCover = '';

  @override
  void initState() {
    super.initState();
    _displayTitle = widget.title;
    _displayCover = widget.coverImage;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final isAlbum = widget.type?.toLowerCase() == 'album';

    try {
      if (isAlbum) {
        await _tryLoadAlbum();
      } else {
        await _tryLoadPlaylist();
      }
    } catch (_) {
      try {
        if (isAlbum) {
          await _tryLoadPlaylist();
        } else {
          await _tryLoadAlbum();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = "Failed to load ${isAlbum ? 'album' : 'playlist'} details.";
          });
        }
      }
    }
  }

  Future<void> _tryLoadPlaylist() async {
    final detail = await _api.fetchPlaylist(widget.id, provider: widget.provider);
    if (!mounted) return;

    final cover = detail.artwork ?? widget.coverImage;
    final mappedSongs = detail.songs
        .map((item) => SongModel(
              songid: item.id,
              songname: item.title,
              userid: item.source ?? widget.provider ?? 'saavn',
              trackid: item.mediaUrls.isNotEmpty ? item.mediaUrls.last.link : item.id,
              duration: item.duration,
              coverImageUrl: item.artwork ?? cover,
              name: item.displaySubtitle ?? item.subtitle ?? '',
              type: 'song',
            ))
        .toList();

    setState(() {
      _displayTitle = detail.title.isNotEmpty ? detail.title : widget.title;
      _displaySubtitle = detail.subtitle ?? "${mappedSongs.length} Tracks";
      _displayCover = (cover.isNotEmpty) ? cover : widget.coverImage;
      _songs = mappedSongs;
      _isLoading = false;
    });
  }

  Future<void> _tryLoadAlbum() async {
    final detail = await _api.fetchAlbum(widget.id, provider: widget.provider);
    if (!mounted) return;

    final cover = detail.artwork ?? widget.coverImage;
    final mappedSongs = detail.songs
        .map((item) => SongModel(
              songid: item.id,
              songname: item.title,
              userid: item.source ?? widget.provider ?? 'saavn',
              trackid: item.mediaUrls.isNotEmpty ? item.mediaUrls.last.link : item.id,
              duration: item.duration,
              coverImageUrl: item.artwork ?? cover,
              name: item.displaySubtitle ?? detail.metaLine,
              type: 'song',
            ))
        .toList();

    setState(() {
      _displayTitle = detail.title.isNotEmpty ? detail.title : widget.title;
      _displaySubtitle = detail.metaLine.isNotEmpty
          ? detail.metaLine
          : (detail.subtitle ?? "${mappedSongs.length} Tracks");
      _displayCover = (cover.isNotEmpty) ? cover : widget.coverImage;
      _songs = mappedSongs;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final width = MediaQuery.of(context).size.width;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(_displayTitle, style: const TextStyle(color: Colors.white)),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null || _songs.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(_displayTitle, style: const TextStyle(color: Colors.white)),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _errorMessage ?? "No tracks available in this playlist.",
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
              )
            ],
          ),
        ),
      );
    }

    final coverUrl = (_displayCover.isNotEmpty)
        ? _displayCover
        : 'https://images.unsplash.com/photo-1611339555312-e607c8352fd7?ixlib=rb-1.2.1&auto=format&fit=crop&w=774&q=80';

    return Scaffold(
      body: AnimatedBuilder(
        animation: widget.con,
        builder: (context, child) {
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 220,
                backgroundColor: Colors.black,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  collapseMode: CollapseMode.pin,
                  background: Stack(
                    children: [
                      CachedNetworkImage(
                        imageUrl: coverUrl,
                        height: 220,
                        width: width,
                        memCacheHeight: (220 * devicePixelRatio).round(),
                        memCacheWidth: (width * devicePixelRatio).round(),
                        fit: BoxFit.cover,
                      ),
                      BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
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
                          height: 220,
                          width: width,
                        ),
                      ),
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: CachedNetworkImage(
                                imageUrl: coverUrl,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _displayTitle,
                                    maxLines: 2,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (_displaySubtitle.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      _displaySubtitle,
                                      maxLines: 1,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ]
                                ],
                              ),
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${_songs.length} Tracks",
                        style: const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightGreenAccent.shade700,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () {
                          widget.con.playSong(widget.con.convertToAudio(_songs), 0);
                        },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text(
                          "Play All",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final song = _songs[i];
                    final isPlaying = widget.con.player.getCurrentAudioTitle == song.songname;

                    return ListTile(
                      onTap: () {
                        widget.con.playSong(widget.con.convertToAudio(_songs), i);
                      },
                      leading: Text(
                        "${i + 1}",
                        style: TextStyle(
                          color: isPlaying ? Colors.lightGreenAccent.shade700 : Colors.white70,
                          fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                          fontSize: 16,
                        ),
                      ),
                      title: Text(
                        song.songname ?? 'Unknown',
                        maxLines: 1,
                        style: TextStyle(
                          color: isPlaying ? Colors.lightGreenAccent.shade700 : Colors.white,
                          fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      subtitle: Text(
                        song.name ?? '',
                        maxLines: 1,
                        style: const TextStyle(
                          color: Colors.grey,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onPressed: () {
                          showModalBottomSheet(
                            useRootNavigator: true,
                            isScrollControlled: true,
                            elevation: 100,
                            backgroundColor: Colors.black38,
                            context: context,
                            builder: (context) {
                              return BottomSheetWidget(con: widget.con, song: song);
                            },
                          );
                        },
                      ),
                    );
                  },
                  childCount: _songs.length,
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 150),
              )
            ],
          );
        },
      ),
    );
  }
}
