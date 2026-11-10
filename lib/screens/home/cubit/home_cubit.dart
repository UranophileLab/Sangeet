import 'package:bloc/bloc.dart';
import '../../../api/dto.dart';
import '../../../models/loading_enum.dart';
import '../../../models/song_model.dart';
import '../../../repositories/get_home_page.dart';

import '../../../models/user.dart';

part 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  final repo = GetHomePage();
  HomeCubit() : super(HomeState.initial());

  void getUsers() async {
    try {
      emit(state.copyWith(status: LoadPage.loading));

      final result = await repo.fetchAllHomeData();

      emit(state.copyWith(
        sections: result.sections,
        users: result.users,
        songs: result.songs,
        status: LoadPage.loaded,
      ));
    } catch (e) {
      print('[HomeCubit] getUsers error: $e');
      emit(state.copyWith(status: LoadPage.error));
    }
  }
}
