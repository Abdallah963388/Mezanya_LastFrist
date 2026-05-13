import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app_state/domain/repositories/app_repository.dart';
import 'logs_state.dart';

class LogsCubit extends Cubit<LogsState> {
  LogsCubit(this._repository) : super(const LogsState());

  final AppRepository _repository;

  Future<void> initialize() async {
    emit(state.copyWith(isLoading: true));
    final appState = await _repository.loadState();
    emit(
      state.copyWith(
        logs: appState.logs,
        notifications: appState.notifications,
        isLoading: false,
      ),
    );
  }

  Future<void> refresh() async {
    final appState = await _repository.loadState();
    emit(
      state.copyWith(
        logs: appState.logs,
        notifications: appState.notifications,
      ),
    );
  }
}
