import 'package:flutter/foundation.dart';

import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/domain/repositories/app_repository.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../domain/entities/budget_setup_entity.dart';
import '../../domain/usecases/update_budget_setup_usecase.dart';

class BudgetController extends ChangeNotifier {
  BudgetController(
    AppRepository repository, {
    UpdateBudgetSetupUseCase? updateBudgetSetupUseCase,
  })  : _repository = repository,
        _updateBudgetSetupUseCase =
            updateBudgetSetupUseCase ?? UpdateBudgetSetupUseCase(repository);

  final AppRepository _repository;
  final UpdateBudgetSetupUseCase _updateBudgetSetupUseCase;

  AppStateEntity _state = AppStateEntity.initial();

  AppStateEntity get state => _state;
  BudgetSetupEntity get budgetSetup => _state.budgetSetup;

  Future<void> initialize() async {
    _state = await _repository.loadState();
    notifyListeners();
  }

  Future<void> refresh() async {
    _state = await _repository.loadState();
    notifyListeners();
  }

  Future<void> updateBudgetSetup(BudgetSetupEntity setup) async {
    _state = await _updateBudgetSetupUseCase(setup);
    notifyListeners();
  }

  Future<void> addLinkedWallet(LinkedWalletEntity linkedWallet) async {
    await updateBudgetSetup(
      budgetSetup.copyWith(
        linkedWallets: [...budgetSetup.linkedWallets, linkedWallet],
      ),
    );
  }

  Future<void> updateLinkedWallet(LinkedWalletEntity linkedWallet) async {
    await updateBudgetSetup(
      budgetSetup.copyWith(
        linkedWallets: budgetSetup.linkedWallets
            .map((item) => item.id == linkedWallet.id ? linkedWallet : item)
            .toList(),
      ),
    );
  }

  Future<void> deleteLinkedWallet(String id) async {
    await updateBudgetSetup(
      budgetSetup.copyWith(
        linkedWallets: budgetSetup.linkedWallets
            .where((wallet) => wallet.id != id)
            .toList(),
      ),
    );
  }

  Future<void> updateAllocationCategories({
    required String allocationId,
    required List<CategoryEntity> categories,
  }) async {
    final allocations = budgetSetup.allocations
        .map((item) => item.id == allocationId
            ? item.copyWith(categories: categories)
            : item)
        .toList();

    await updateBudgetSetup(
      budgetSetup.copyWith(allocations: allocations),
    );
  }

  Future<void> updateLinkedWalletCategories({
    required String linkedWalletId,
    required List<CategoryEntity> categories,
  }) async {
    final linkedWallets = budgetSetup.linkedWallets
        .map((item) => item.id == linkedWalletId
            ? item.copyWith(categories: categories)
            : item)
        .toList();

    await updateBudgetSetup(
      budgetSetup.copyWith(linkedWallets: linkedWallets),
    );
  }
}
