import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app_state/domain/repositories/app_repository.dart';
import 'goals_state.dart';

class GoalsCubit extends Cubit<GoalsState> {
  GoalsCubit(this._repository) : super(const GoalsState());

  final AppRepository _repository;

  Future<void> initialize() async {
    emit(state.copyWith(isLoading: true));
    final appState = await _repository.loadState();
    emit(state.copyWith(goals: appState.goals, isLoading: false));
  }

  Future<void> refresh() async {
    final appState = await _repository.loadState();
    emit(state.copyWith(goals: appState.goals));
  }
}
