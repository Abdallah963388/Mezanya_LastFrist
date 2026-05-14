import 'package:flutter/foundation.dart';

import '../../../categories/domain/entities/category_entity.dart';
import '../../domain/entities/budget_setup_entity.dart';
import '../../domain/repositories/budget_repository.dart';
import '../../domain/usecases/load_budget_setup_usecase.dart';
import '../../domain/usecases/update_budget_setup_usecase.dart';

class BudgetController extends ChangeNotifier {
  BudgetController(
    BudgetRepository repository, {
    UpdateBudgetSetupUseCase? updateBudgetSetupUseCase,
    LoadBudgetSetupUseCase? loadBudgetSetupUseCase,
  })  : _loadBudgetSetupUseCase =
            loadBudgetSetupUseCase ?? LoadBudgetSetupUseCase(repository),
        _updateBudgetSetupUseCase = updateBudgetSetupUseCase ??
            UpdateBudgetSetupUseCase(repository);

  final LoadBudgetSetupUseCase _loadBudgetSetupUseCase;
  final UpdateBudgetSetupUseCase _updateBudgetSetupUseCase;

  BudgetSetupEntity _budgetSetup =
      BudgetSetupEntity.initial('wallet-cash-default');

  BudgetSetupEntity get budgetSetup => _budgetSetup;

  List<AllocationEntity> get allocations => budgetSetup.allocations;

  List<LinkedWalletEntity> get linkedWallets =>
      budgetSetup.linkedWallets;

  List<DebtEntity> get debts => budgetSetup.debts;

  List<IncomeSourceEntity> get incomeSources =>
      budgetSetup.incomeSources;

  double get totalIncome => budgetSetup.totalIncome;

  double get totalAllocated => budgetSetup.totalAllocated;

  double get unallocatedAmount => budgetSetup.unallocatedAmount;

  bool get hasAllocations => allocations.isNotEmpty;

  bool get hasLinkedWallets => linkedWallets.isNotEmpty;

  bool get hasDebts => debts.isNotEmpty;

  int get allocationCount => allocations.length;

  int get linkedWalletCount => linkedWallets.length;

  int get debtCount => debts.length;

  Future<void> initialize() async {
    _budgetSetup = await _loadBudgetSetupUseCase();
    notifyListeners();
  }

  Future<void> refresh() async {
    _budgetSetup = await _loadBudgetSetupUseCase();
    notifyListeners();
  }

  Future<void> updateBudgetSetup(BudgetSetupEntity setup) async {
    _budgetSetup = await _updateBudgetSetupUseCase(setup);
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
