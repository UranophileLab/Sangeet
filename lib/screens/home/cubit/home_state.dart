part of 'home_cubit.dart';

class HomeState {
  final LoadPage status;
  final List<HomeSection> sections;
  final List<User> users;
  final List<SongModel> songs;
  HomeState({
    required this.status,
    required this.sections,
    required this.users,
    required this.songs,
  });
  factory HomeState.initial() {
    return HomeState(
      sections: [],
      songs: [],
      status: LoadPage.initial,
      users: [],
    );
  }

  HomeState copyWith({
    LoadPage? status,
    List<HomeSection>? sections,
    List<User>? users,
    List<SongModel>? songs,
  }) {
    return HomeState(
      status: status ?? this.status,
      sections: sections ?? this.sections,
      users: users ?? this.users,
      songs: songs ?? this.songs,
    );
  }
}
