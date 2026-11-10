import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../controllers/main_controller.dart';
import '../../methods/list_extensions.dart';
import '../../models/loading_enum.dart';
import '../../models/song_model.dart';
import '../../models/user.dart';
import '../../utils/horizontal_songs_list.dart';
import '../../utils/recent_users.dart';
import 'cubit/home_cubit.dart';

class HomeScreen extends StatelessWidget {
  final MainController con;
  const HomeScreen({
    Key? key,
    required this.con,
  }) : super(key: key);

  Widget _buildHomeContent(BuildContext context, HomeState state) {
    final children = <Widget>[];

    if (state.users.isNotEmpty) {
      children.add(
        RecentUsers(
          con: con,
          users: state.users.safeSublist(0, 6),
        ),
      );
      children.add(const SizedBox(height: 12));
    }

    if (state.sections.isNotEmpty) {
      for (final section in state.sections) {
        if (section.items.isEmpty) continue;

        final isArtistRow = section.items.every((it) =>
            it.type == 'artist' ||
            it.type == 'channel' ||
            it.type == 'radio_station' ||
            it.type == 'radio');

        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Text(
              section.heading,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
        );

        if (isArtistRow) {
          final users = section.items
              .map((item) => User(
                    avatar: item.artwork ?? '',
                    username: item.id,
                    name: item.title,
                  ))
              .toList();
          children.add(HorizontalArtistList(con: con, users: users));
        } else {
          final songs = section.items
              .map((item) => SongModel(
                    songid: item.id,
                    songname: item.title,
                    userid: item.source ?? 'saavn',
                    trackid: item.mediaUrls.isNotEmpty
                        ? item.mediaUrls.last.link
                        : item.id,
                    duration: item.duration,
                    coverImageUrl: item.artwork,
                    name: item.displaySubtitle ?? item.subtitle ?? '',
                    type: item.type,
                  ))
              .toList();
          children.add(HorizontalSongList(con: con, songs: songs));
        }

        children.add(const SizedBox(height: 12));
      }
    } else {
      if (state.songs.isNotEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Text(
              "Popular Hits",
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
        );
        children.add(
          HorizontalSongList(
            con: con,
            songs: state.songs.safeSublist(0, 10),
          ),
        );
        children.add(const SizedBox(height: 12));
      }

      if (state.users.length > 6) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Text(
              "Best Picks For You",
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
        );
        children.add(
          HorizontalArtistList(
            con: con,
            users: state.users.safeSublist(6, 16),
          ),
        );
        children.add(const SizedBox(height: 12));
      }

      if (state.songs.length > 10) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Text(
              "New Releases",
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
        );
        children.add(
          HorizontalSongList(
            con: con,
            songs: state.songs.safeSublist(10, 20),
          ),
        );
        children.add(const SizedBox(height: 12));
      }

      if (state.users.length > 16) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Text(
              "You might also like",
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
        );
        children.add(
          HorizontalArtistList(
            con: con,
            users: state.users.safeSublist(16),
          ),
        );
        children.add(const SizedBox(height: 12));
      }
    }

    return ListView(children: children);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => HomeCubit()..getUsers(),
      child: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          if (state.status == LoadPage.loading) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          if (state.status == LoadPage.loaded) {
            return Scaffold(
              body: _buildHomeContent(context, state),
            );
          }
          if (state.status == LoadPage.error) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Unable to load home content",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        BlocProvider.of<HomeCubit>(context).getUsers();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text("Retry"),
                    )
                  ],
                ),
              ),
            );
          }

          return Container();
        },
      ),
    );
  }
}
