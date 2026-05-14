import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/load_logs_feed_usecase.dart';
import 'logs_state.dart';

class LogsCubit extends Cubit<LogsState> {
  LogsCubit(this._loadLogsFeedUseCase) : super(const LogsState());

  final LoadLogsFeedUseCase _loadLogsFeedUseCase;

  Future<void> initialize() async {
    emit(state.copyWith(isLoading: true));
    final feed = await _loadLogsFeedUseCase();
    emit(
      state.copyWith(
        logs: feed.logs,
        notifications: feed.notifications,
        isLoading: false,
      ),
    );
  }

  Future<void> refresh() async {
    final feed = await _loadLogsFeedUseCase();
    emit(
      state.copyWith(
        logs: feed.logs,
        notifications: feed.notifications,
      ),
    );
  }
}
