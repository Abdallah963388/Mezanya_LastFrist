import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../categories/domain/entities/category_entity.dart';
import '../../domain/entities/budget_setup_entity.dart';
import '../../domain/repositories/budget_repository.dart';
import '../../domain/usecases/update_budget_setup_usecase.dart';
import 'budget_state.dart';

class BudgetCubit extends Cubit<BudgetState> {
  BudgetCubit(
    BudgetRepository repository, {
    UpdateBudgetSetupUseCase? updateBudgetSetupUseCase,
  })  : _repository = repository,
        _updateBudgetSetupUseCase =
            updateBudgetSetupUseCase ?? UpdateBudgetSetupUseCase(repository),
        super(BudgetState());

  final BudgetRepository _repository;
  final UpdateBudgetSetupUseCase _updateBudgetSetupUseCase;

  Future<void> initialize() async {
    emit(state.copyWith(isLoading: true));
    final budgetSetup = await _repository.loadBudget();
    emit(state.copyWith(budgetSetup: budgetSetup, isLoading: false));
  }

  Future<void> refresh() async {
    final budgetSetup = await _repository.loadBudget();
    emit(state.copyWith(budgetSetup: budgetSetup));
  }

  Future<void> updateBudgetSetup(BudgetSetupEntity setup) async {
    final budgetSetup = await _updateBudgetSetupUseCase(setup);
    emit(state.copyWith(budgetSetup: budgetSetup));
  }

  Future<void> addLinkedWallet(LinkedWalletEntity linkedWallet) async {
    await updateBudgetSetup(
      state.budgetSetup.copyWith(
        linkedWallets: [...state.budgetSetup.linkedWallets, linkedWallet],
      ),
    );
  }

  Future<void> updateLinkedWallet(LinkedWalletEntity linkedWallet) async {
    await updateBudgetSetup(
      state.budgetSetup.copyWith(
        linkedWallets: state.budgetSetup.linkedWallets
            .map((item) => item.id == linkedWallet.id ? linkedWallet : item)
            .toList(),
      ),
    );
  }

  Future<void> deleteLinkedWallet(String id) async {
    await updateBudgetSetup(
      state.budgetSetup.copyWith(
        linkedWallets: state.budgetSetup.linkedWallets
            .where((wallet) => wallet.id != id)
            .toList(),
      ),
    );
  }

  Future<void> updateAllocationCategories({
    required String allocationId,
    required List<CategoryEntity> categories,
  }) async {
    final allocations = state.budgetSetup.allocations
        .map((item) => item.id == allocationId
            ? item.copyWith(categories: categories)
            : item)
        .toList();

    await updateBudgetSetup(
      state.budgetSetup.copyWith(allocations: allocations),
    );
  }

  Future<void> updateLinkedWalletCategories({
    required String linkedWalletId,
    required List<CategoryEntity> categories,
  }) async {
    final linkedWallets = state.budgetSetup.linkedWallets
        .map((item) => item.id == linkedWalletId
            ? item.copyWith(categories: categories)
            : item)
        .toList();

    await updateBudgetSetup(
      state.budgetSetup.copyWith(linkedWallets: linkedWallets),
    );
  }
}
