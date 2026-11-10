import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:line_icons/line_icons.dart';
import '../../methods/get_time_ago.dart';
import '../../methods/snackbar.dart';
import '../../utils/loading.dart';

class AddToPlaylist extends StatefulWidget {
  final String name;
  final String fullname;
  final String username;
  final String cover;
  final String track;
  final String id;

  const AddToPlaylist({
    Key? key,
    required this.name,
    required this.fullname,
    required this.username,
    required this.cover,
    required this.track,
    required this.id,
  }) : super(key: key);

  @override
  State<AddToPlaylist> createState() => _AddToPlaylistState();
}

class _AddToPlaylistState extends State<AddToPlaylist> {
  late final TextEditingController _con;

  @override
  void initState() {
    super.initState();
    _con = TextEditingController();
  }

  @override
  void dispose() {
    _con.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Add to Playlist",
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        backgroundColor: Colors.black,
      ),
      body: ListView(
        children: [
          const SizedBox(
            height: 20,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: MaterialButton(
                  color: Colors.lightGreenAccent[700],
                  minWidth: MediaQuery.of(context).size.width * .7,
                  onPressed: () {
                    showDialog(
                        context: context,
                        builder: (BuildContext dialogContext) {
                          return AlertDialog(
                            backgroundColor: Colors.grey.shade900,
                            title: const Text(
                              "Give your collection a name.",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            content: TextField(
                              controller: _con,
                              cursorColor: Colors.lightGreen,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 24),
                              autofocus: true,
                              decoration: const InputDecoration(
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Colors.lightGreen, width: 2),
                                ),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text(
                                  "CANCEL",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 15),
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  if (_con.text.isNotEmpty) {
                                    final playlistName = _con.text.trim();
                                    if (await Hive.boxExists(playlistName)) {
                                      if (!context.mounted) return;
                                      context.showErrorSnackBar(
                                          message: "Playlist already exists");
                                      return;
                                    }
                                    var box = Hive.box('playlists');
                                    box.add({
                                      "name": playlistName,
                                      "coverImage": widget.cover,
                                      "created": DateTime.now().toString(),
                                    });
                                    await Hive.openBox(playlistName);
                                    if (!Hive.isBoxOpen(playlistName)) return;
                                    var playlistBox = Hive.box(playlistName);

                                    playlistBox.put(widget.name, {
                                      "songname": widget.name,
                                      "fullname": widget.fullname,
                                      "username": widget.username,
                                      "cover": widget.cover,
                                      "track": widget.track,
                                      "id": widget.id,
                                    });

                                    if (!context.mounted) return;
                                    context.showSnackBar(
                                        message: "Song added to playlist.");

                                    Navigator.pop(dialogContext); // pop dialog
                                    if (context.mounted) {
                                      Navigator.of(context).pop(); // pop AddToPlaylist screen
                                    }
                                  } else {
                                    context.showErrorSnackBar(
                                        message: "Please enter a name");
                                  }
                                },
                                child: Text(
                                  "CREATE AND ADD",
                                  style: TextStyle(
                                      color: Colors.lightGreen[700],
                                      fontSize: 15),
                                ),
                              )
                            ],
                          );
                        });
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      "Create a new Playlist",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (Hive.box('playlists').length != 0)
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16),
              child: Text(
                "Your playlists",
                style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                      fontSize: 18,
                    ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: Hive.box('playlists').length,
                itemBuilder: (context, i) {
                  final raw = Hive.box('playlists').getAt(i);
                  final playlists = raw is Map ? raw : {};
                  final playlistName = playlists['name']?.toString() ?? 'Unnamed';
                  final coverUrl = (playlists['coverImage'] != null &&
                          playlists['coverImage'].toString().isNotEmpty)
                      ? playlists['coverImage'].toString()
                      : 'https://images.unsplash.com/photo-1611339555312-e607c8352fd7?ixlib=rb-1.2.1&auto=format&fit=crop&w=774&q=80';
                  final createdStr = playlists['created']?.toString() ?? '';

                  return ListTile(
                    contentPadding: const EdgeInsets.all(6),
                    onTap: () async {
                      if (playlistName.isEmpty) return;
                      await Hive.openBox(playlistName);
                      if (!Hive.isBoxOpen(playlistName)) return;
                      var playlistBox = Hive.box(playlistName);

                      playlistBox.put(widget.name, {
                        "songname": widget.name,
                        "fullname": widget.fullname,
                        "username": widget.username,
                        "cover": widget.cover,
                        "track": widget.track,
                        "id": widget.id,
                      });
                      if (!context.mounted) return;
                      context.showSnackBar(message: "Song added to playlist.");
                      Navigator.pop(context);
                    },
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: CachedNetworkImage(
                          imageUrl: coverUrl,
                          width: 50,
                          height: 50,
                          maxHeightDiskCache: 80,
                          maxWidthDiskCache: 80,
                          memCacheHeight:
                              (80 * MediaQuery.of(context).devicePixelRatio)
                                  .round(),
                          memCacheWidth:
                              (80 * MediaQuery.of(context).devicePixelRatio)
                                  .round(),
                          placeholder: (context, u) => const LoadingImage(
                                icon: Icon(LineIcons.user),
                              ),
                          fit: BoxFit.cover),
                    ),
                    title: Text(
                      playlistName,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      "Created By you " +
                          "".displayTimeAgoFromTimestamp(createdStr),
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                }),
          )
        ],
      ),
    );
  }
}
