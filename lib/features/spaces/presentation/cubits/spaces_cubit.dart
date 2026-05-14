import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../budget/domain/usecases/load_budget_setup_usecase.dart';
import 'spaces_state.dart';

class SpacesCubit extends Cubit<SpacesState> {
  SpacesCubit(this._loadBudgetSetupUseCase) : super(const SpacesState());

  final LoadBudgetSetupUseCase _loadBudgetSetupUseCase;

  Future<void> initialize() async {
    emit(state.copyWith(isLoading: true));
    final budgetSetup = await _loadBudgetSetupUseCase();
    emit(
      state.copyWith(
        savingsSpaces: budgetSetup.linkedWallets,
        allocationSpaces: budgetSetup.allocations,
        isLoading: false,
      ),
    );
  }

  Future<void> refresh() async {
    final budgetSetup = await _loadBudgetSetupUseCase();
    emit(
      state.copyWith(
        savingsSpaces: budgetSetup.linkedWallets,
        allocationSpaces: budgetSetup.allocations,
      ),
    );
  }
}
