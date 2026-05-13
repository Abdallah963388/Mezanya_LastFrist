import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app_state/domain/repositories/app_repository.dart';
import 'spaces_state.dart';

class SpacesCubit extends Cubit<SpacesState> {
  SpacesCubit(this._repository) : super(const SpacesState());

  final AppRepository _repository;

  Future<void> initialize() async {
    emit(state.copyWith(isLoading: true));
    final appState = await _repository.loadState();
    emit(
      state.copyWith(
        savingsSpaces: appState.budgetSetup.linkedWallets,
        allocationSpaces: appState.budgetSetup.allocations,
        isLoading: false,
      ),
    );
  }

  Future<void> refresh() async {
    final appState = await _repository.loadState();
    emit(
      state.copyWith(
        savingsSpaces: appState.budgetSetup.linkedWallets,
        allocationSpaces: appState.budgetSetup.allocations,
      ),
    );
  }
}
